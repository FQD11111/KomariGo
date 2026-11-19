import Foundation

struct PingPayload {
    let stats: [PingStat]
    let samples: [Int: [Int]]
}

func withTimeout<T>(_ seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw APIError("请求超时")
        }
        guard let value = try await group.next() else { throw APIError("请求超时") }
        group.cancelAll()
        return value
    }
}

final class KomariAPI {
    let base: URL
    var token: String?
    private let session: URLSession

    init?(host: String, token: String? = nil) {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return nil }
        if !h.lowercased().hasPrefix("http://") && !h.lowercased().hasPrefix("https://") {
            h = "https://" + h
        }
        while h.hasSuffix("/") { h.removeLast() }
        guard let u = URL(string: h) else { return nil }
        base = u
        self.token = token
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        session = URLSession(configuration: cfg)
    }

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL? {
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        comps.path = comps.path + (path.hasPrefix("/") ? path : "/" + path)
        if !query.isEmpty { comps.queryItems = query }
        return comps.url
    }

    private func send<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        json: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let u = url(path, query: query) else { throw APIError("地址无效") }
        var req = URLRequest(url: u)
        req.httpMethod = method
        if let token { req.setValue("session_token=\(token)", forHTTPHeaderField: "Cookie") }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError("服务器无响应") }

        if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data),
           body.status == "error" {
            throw APIError(body.message ?? "请求失败 (HTTP \(http.statusCode))")
        }
        if http.statusCode >= 400 { throw APIError("HTTP \(http.statusCode)") }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError("数据解析失败")
        }
    }

    // MARK: 登录

    func login(username: String, password: String, twoFA: String?) async throws -> String {
        guard let u = url("/api/login") else { throw APIError("地址无效") }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["username": username, "password": password]
        if let twoFA, !twoFA.isEmpty { body["2fa_code"] = twoFA }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        let http = resp as? HTTPURLResponse

        if let env = try? JSONDecoder().decode(LoginEnvelope.self, from: data) {
            if env.status == "success",
               let t = env.data?.setCookie?.sessionToken, !t.isEmpty {
                token = t
                return t
            }
            if let m = env.message, !m.isEmpty { throw APIError(m) }
        }

        if let raw = http?.value(forHTTPHeaderField: "Set-Cookie"),
           let r = raw.range(of: "session_token=") {
            let tail = raw[r.upperBound...]
            let t = tail.split(separator: ";").first.map(String.init) ?? ""
            if !t.isEmpty {
                token = t
                return t
            }
        }

        throw APIError("登录失败 (HTTP \(http?.statusCode ?? 0))")
    }

    // MARK: 数据

    func me() async throws -> Me {
        try await send("/api/me")
    }

    func nodes() async throws -> [Node] {
        let env: Envelope<[Node]> = try await send("/api/nodes")
        return env.data ?? []
    }

    func records(uuid: String, loadType: String = "load", hours: Int = 24) async throws -> [RecordPoint] {
        let env: Envelope<RecordsData> = try await send(
            "/api/records/load",
            query: [
                URLQueryItem(name: "uuid", value: uuid),
                URLQueryItem(name: "load_type", value: loadType),
                URLQueryItem(name: "hours", value: String(hours)),
            ]
        )
        return env.data?.records ?? []
    }

    // MARK: 实时（WS 必须先发 "get"）

    func realtimeOnce(timeout: Double = 8) async throws -> RealtimeData {
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError("地址无效")
        }
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = comps.path + "/api/clients"
        guard let u = comps.url else { throw APIError("WS 地址无效") }

        var req = URLRequest(url: u)
        if let token { req.setValue("session_token=\(token)", forHTTPHeaderField: "Cookie") }
        req.setValue(base.absoluteString, forHTTPHeaderField: "Origin")

        let task = session.webSocketTask(with: req)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        try await task.send(.string("get"))
        let message = try await withTimeout(timeout) { try await task.receive() }

        let data: Data
        switch message {
        case .string(let s): data = Data(s.utf8)
        case .data(let d): data = d
        @unknown default: throw APIError("未知 WS 消息")
        }

        let env = try JSONDecoder().decode(RealtimeEnvelope.self, from: data)
        return env.data ?? RealtimeData()
    }

    // MARK: - 三网延迟

    func ping(uuid: String, hours: Int = 4) async throws -> PingPayload {
        let env: Envelope<PingResponse> = try await send(
            "/api/records/ping",
            query: [
                URLQueryItem(name: "uuid", value: uuid),
                URLQueryItem(name: "hours", value: String(hours)),
            ]
        )
        let tasks = env.data?.tasks ?? []
        var grouped: [Int: [(String, Int)]] = [:]
        for r in env.data?.records ?? [] {
            guard let taskID = r.taskId, let value = r.value else { continue }
            grouped[taskID, default: []].append((r.time ?? "", value))
        }
        var samples: [Int: [Int]] = [:]
        for (taskID, list) in grouped {
            samples[taskID] = list.sorted { $0.0 < $1.0 }.map { $0.1 }.suffix(48).map { $0 }
        }
        return PingPayload(stats: tasks, samples: samples)
    }

    // MARK: - 管理

    struct Empty: Decodable {}

    func editClient(uuid: String, fields: [String: Any]) async throws {
        var body = fields
        body["uuid"] = uuid
        let _: Envelope<Empty> = try await send(
            "/api/admin/client/\(uuid)/edit",
            method: "POST",
            json: body
        )
    }

    func exec(command: String, clients: [String], twoFA: String?) async throws -> ExecResponse {
        var headers: [String: String] = [:]
        if let twoFA, !twoFA.isEmpty { headers["X-2FA-Code"] = twoFA }
        let env: Envelope<ExecResponse> = try await send(
            "/api/admin/task/exec",
            method: "POST",
            json: ["command": command, "clients": clients],
            headers: headers
        )
        guard let data = env.data else { throw APIError(env.message ?? "创建任务失败") }
        return data
    }

    func taskResults(taskID: String) async throws -> [TaskResult] {
        let env: Envelope<[TaskResult]> = try await send("/api/admin/task/\(taskID)/result")
        return env.data ?? []
    }

    func logs(limit: Int = 50, page: Int = 1) async throws -> [AdminLog] {
        let env: Envelope<AdminLogs> = try await send(
            "/api/admin/logs",
            query: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "page", value: String(page)),
            ]
        )
        return env.data?.logs ?? []
    }

    func probeAdmin() async -> Bool {
        do {
            _ = try await logs(limit: 1)
            return true
        } catch {
            return false
        }
    }
}
