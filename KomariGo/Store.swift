import Foundation
import SwiftUI

struct TrafficSummary {
    var up: Int64 = 0
    var down: Int64 = 0
    var nodes: Int = 0
    var approximate = false

    var total: Int64 { up + down }
}

struct Server: Codable, Identifiable, Equatable {
    var id: String
    var alias: String
    var host: String
    var user: String
    var token: String
}

@MainActor
final class Store: ObservableObject {
    @Published var servers: [Server] = []
    @Published var currentId: String?
    @Published var sessionValid: [String: Bool] = [:]
    @Published var themeMode: String = UserDefaults.standard.string(forKey: "komari.theme") ?? "system"
    @Published var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "komari.favs") ?? [])

    @Published var nodes: [Node] = []
    @Published var reports: [String: Report] = [:]
    @Published var online: Set<String> = []
    @Published var pings: [String: [PingStat]] = [:]
    @Published var pingSamples: [String: [Int: [Int]]] = [:]
    @Published var todayTraffic = TrafficSummary()
    @Published var loading = false
    @Published var error: String?
    @Published var isAdmin = false
    @Published var sessionNotice: String?
    @Published var connProblem = false

    private var api: KomariAPI?
    private var pollTask: Task<Void, Never>?
    private var fails = 0

    init() {
        loadServers()
        if let c = current, !c.token.isEmpty {
            api = KomariAPI(host: c.host, token: c.token)
        }
    }

    // MARK: 服务器

    var current: Server? {
        servers.first { $0.id == currentId }
    }

    var host: String { current?.host ?? "" }
    var username: String { current?.user ?? "" }
    var token: String? {
        guard let t = current?.token, !t.isEmpty else { return nil }
        return t
    }

    var currentAlias: String {
        let a = current?.alias.trimmingCharacters(in: .whitespaces) ?? ""
        return a.isEmpty ? "Komari" : a
    }

    var isLoggedIn: Bool { api != nil && token != nil }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func toggleFav(_ uuid: String) {
        if favorites.contains(uuid) { favorites.remove(uuid) } else { favorites.insert(uuid) }
        UserDefaults.standard.set(Array(favorites), forKey: "komari.favs")
    }

    func setTheme(_ mode: String) {
        themeMode = mode
        UserDefaults.standard.set(mode, forKey: "komari.theme")
    }

    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: "komari.servers"),
           let list = try? JSONDecoder().decode([Server].self, from: data) {
            servers = list
        } else {
            let h = UserDefaults.standard.string(forKey: "komari.host") ?? ""
            let u = UserDefaults.standard.string(forKey: "komari.user") ?? ""
            if !h.isEmpty, let t = UserDefaults.standard.string(forKey: "komari.token") {
                servers = [Server(id: UUID().uuidString, alias: h, host: h, user: u, token: t)]
                saveServers()
                ["komari.host", "komari.user", "komari.token"].forEach {
                    UserDefaults.standard.removeObject(forKey: $0)
                }
            }
        }
        let saved = UserDefaults.standard.string(forKey: "komari.current")
        currentId = servers.first(where: { $0.id == saved })?.id ?? servers.first?.id
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: "komari.servers")
        }
        UserDefaults.standard.set(currentId, forKey: "komari.current")
    }

    func checkSessions() async {
        var result: [String: Bool] = [:]
        for s in servers {
            guard !s.token.isEmpty, let client = KomariAPI(host: s.host, token: s.token) else {
                result[s.id] = false
                continue
            }
            do {
                let me = try await client.me()
                result[s.id] = (me.loggedIn == true)
            } catch {
                result[s.id] = false
            }
        }
        sessionValid = result
    }

    var sortedNodes: [Node] {
        nodes.sorted { a, b in
            let ao = online.contains(a.uuid), bo = online.contains(b.uuid)
            if ao != bo { return ao }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    // MARK: 登录

    func login(
        alias: String = "",
        host rawHost: String,
        username user: String,
        password: String,
        twoFA: String,
        serverID: String? = nil
    ) async -> Bool {
        loading = true
        error = nil
        defer { loading = false }

        guard let client = KomariAPI(host: rawHost) else {
            error = "面板地址格式不对"
            return false
        }
        do {
            let t = try await client.login(username: user, password: password, twoFA: twoFA)
            let trimmedHost = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = serverID ?? UUID().uuidString
            let srv = Server(
                id: id,
                alias: trimmedAlias.isEmpty ? trimmedHost : trimmedAlias,
                host: trimmedHost,
                user: user,
                token: t
            )
            if let idx = servers.firstIndex(where: { $0.id == id }) {
                servers[idx] = srv
            } else {
                servers.append(srv)
            }
            currentId = srv.id
            saveServers()

            api = client
            sessionValid[srv.id] = true
            sessionNotice = nil
            connProblem = false
            fails = 0

            resetData()
            await refresh()
            isAdmin = await client.probeAdmin()
            startPolling()
            return true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func switchTo(_ id: String) async {
        guard let srv = servers.first(where: { $0.id == id }) else { return }
        if id == currentId, api != nil { return }
        stopPolling()
        currentId = id
        saveServers()
        api = nil
        resetData()
        error = nil
        sessionNotice = nil
        connProblem = false
        fails = 0

        guard !srv.token.isEmpty, let client = KomariAPI(host: srv.host, token: srv.token) else {
            return
        }
        api = client
        await refresh()
        isAdmin = await client.probeAdmin()
        startPolling()
    }

    func deleteServer(_ id: String) async {
        servers.removeAll { $0.id == id }
        sessionValid[id] = nil
        if currentId == id {
            stopPolling()
            api = nil
            resetData()
            currentId = servers.first?.id
            saveServers()
            if let c = current, !c.token.isEmpty, let client = KomariAPI(host: c.host, token: c.token) {
                api = client
                await refresh()
                startPolling()
            }
        } else {
            saveServers()
        }
    }

    func logout() {
        stopPolling()
        api = nil
        resetData()
        isAdmin = false
        if let id = currentId, let idx = servers.firstIndex(where: { $0.id == id }) {
            servers[idx].token = ""
            sessionValid[id] = false
        }
        saveServers()
    }

    private func resetData() {
        nodes = []
        reports = [:]
        pings = [:]
        pingSamples = [:]
        online = []
        todayTraffic = TrafficSummary()
    }

    func validateSession() async {
        await checkSessions()
        guard let api else { return }
        do {
            let me = try await api.me()
            if me.loggedIn != true {
                sessionNotice = "登录已过期，请重新登录"
                logout()
            } else {
                isAdmin = await api.probeAdmin()
                startPolling()
            }
        } catch {
            // 网络问题不强制登出
        }
    }

    // MARK: 数据

    func refresh() async {
        guard let api else { return }
        loading = true
        defer { loading = false }
        do {
            nodes = try await api.nodes()
            error = nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if message.localizedCaseInsensitiveContains("unauthor") {
                sessionNotice = "登录已过期，请重新登录"
                logout()
            } else {
                self.error = message
            }
            return
        }
        await loadPings()
        syncTrafficBaseline()
    }

    var liveDown: Int64 {
        reports.values.reduce(0) { $0 + ($1.network?.down ?? 0) }
    }

    var liveUp: Int64 {
        reports.values.reduce(0) { $0 + ($1.network?.up ?? 0) }
    }

    /// 每台节点的实时上行速率（B/s），用于「实时上行占比」弹窗
    func liveUpOf(_ uuid: String) -> Int64 {
        reports[uuid]?.network?.up ?? 0
    }

    /// 每台节点的实时下行速率（B/s），用于「实时下行占比」弹窗
    func liveDownOf(_ uuid: String) -> Int64 {
        reports[uuid]?.network?.down ?? 0
    }

    /// 每台节点的今日流量（up + down），用于「今日流量占比」弹窗
    func todayTrafficOf(_ uuid: String) -> Int64 {
        let prefix = (currentId ?? "") + ":"
        let key = prefix + uuid
        guard let baseline = loadBaseline() else { return 0 }
        guard let report = reports[uuid] else { return 0 }
        let up = report.network?.totalUp ?? 0
        let down = report.network?.totalDown ?? 0
        let baseUp = baseline.up[key] ?? up
        let baseDown = baseline.down[key] ?? down
        return max(0, up - baseUp) + max(0, down - baseDown)
    }

    var onlineCount: Int { online.count }

    // MARK: 今日流量（本地基线法）

    private struct TrafficBaseline: Codable {
        var day: String
        var capturedAt: Date
        var up: [String: Int64]
        var down: [String: Int64]
    }

    private var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func loadBaseline() -> TrafficBaseline? {
        guard let data = UserDefaults.standard.data(forKey: "komari.traffic.baseline") else { return nil }
        return try? JSONDecoder().decode(TrafficBaseline.self, from: data)
    }

    private func saveBaseline(_ baseline: TrafficBaseline) {
        if let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: "komari.traffic.baseline")
        }
    }

    func syncTrafficBaseline() {
        guard !reports.isEmpty else { return }

        let today = dayKey
        var baseline = loadBaseline()
        if baseline == nil || baseline?.day != today {
            baseline = TrafficBaseline(day: today, capturedAt: Date(), up: [:], down: [:])
        }
        guard var base = baseline else { return }

        let prefix = (currentId ?? "") + ":"
        var changed = false
        for (uuid, report) in reports {
            let key = prefix + uuid
            if base.up[key] == nil {
                base.up[key] = report.network?.totalUp ?? 0
                base.down[key] = report.network?.totalDown ?? 0
                changed = true
            }
        }
        if changed { saveBaseline(base) }

        var summary = TrafficSummary()
        summary.nodes = nodes.count
        let midnight = Calendar.current.startOfDay(for: Date())
        summary.approximate = base.capturedAt.timeIntervalSince(midnight) > 600

        for (uuid, report) in reports {
            let key = prefix + uuid
            let up = report.network?.totalUp ?? 0
            let down = report.network?.totalDown ?? 0
            let baseUp = base.up[key] ?? up
            let baseDown = base.down[key] ?? down
            let dUp = up - baseUp
            let dDown = down - baseDown
            if dUp < 0 || dDown < 0 { summary.approximate = true }
            summary.up += max(0, dUp)
            summary.down += max(0, dDown)
        }

        todayTraffic = summary
    }

    private func loadPings() async {
        guard let api, !nodes.isEmpty else { return }
        let list = nodes
        var result: [String: [PingStat]] = [:]
        var sampleResult: [String: [Int: [Int]]] = [:]
        await withTaskGroup(of: (String, [PingStat], [Int: [Int]]).self) { group in
            for node in list {
                group.addTask {
                    let payload = (try? await api.ping(uuid: node.uuid))
                        ?? PingPayload(stats: [], samples: [:])
                    return (node.uuid, payload.stats, payload.samples)
                }
            }
            for await (uuid, stats, samples) in group {
                result[uuid] = stats
                sampleResult[uuid] = samples
            }
        }
        pings = result
        pingSamples = sampleResult
    }

    func pollOnce() async {
        guard let api else { return }
        do {
            let snap = try await api.realtimeOnce()
            reports = snap.data ?? [:]
            online = Set(snap.online ?? [])
            error = nil
            fails = 0
            connProblem = false
            syncTrafficBaseline()
        } catch {
            fails += 1
            if fails >= 3 { connProblem = true }
        }
    }

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollOnce()
                tick += 1
                if tick % 15 == 0 { await self.refresh() }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func records(for uuid: String, loadType: String, hours: Int) async -> [RecordPoint] {
        guard let api else { return [] }
        return (try? await api.records(uuid: uuid, loadType: loadType, hours: hours)) ?? []
    }

    // MARK: 管理

    func saveNode(uuid: String, fields: [String: Any], reloadAfter: Bool = true) async -> String? {
        guard let api else { return "未登录" }
        do {
            try await api.editClient(uuid: uuid, fields: fields)
            if reloadAfter { await refresh() }
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func runCommand(_ command: String, nodeUUID: String, twoFA: String) async -> (ExecResponse?, String?) {
        guard let api else { return (nil, "未登录") }
        do {
            let resp = try await api.exec(command: command, clients: [nodeUUID], twoFA: twoFA)
            return (resp, nil)
        } catch {
            return (nil, (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func taskResults(_ taskID: String) async -> [TaskResult] {
        guard let api else { return [] }
        return (try? await api.taskResults(taskID: taskID)) ?? []
    }

    func adminLogs() async -> [AdminLog] {
        guard let api else { return [] }
        return (try? await api.logs(limit: 80)) ?? []
    }
}
