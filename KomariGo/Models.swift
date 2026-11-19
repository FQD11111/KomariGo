import Foundation

// MARK: - 通用信封

struct Envelope<T: Decodable>: Decodable {
    let status: String?
    let message: String?
    let data: T?
}

struct APIErrorBody: Decodable {
    let status: String?
    let message: String?
}

struct APIError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

// MARK: - 登录

struct LoginData: Decodable {
    let setCookie: SetCookie?
    enum CodingKeys: String, CodingKey { case setCookie = "set-cookie" }
}

struct SetCookie: Decodable {
    let sessionToken: String?
    enum CodingKeys: String, CodingKey { case sessionToken = "session_token" }
}

struct LoginEnvelope: Decodable {
    let status: String?
    let message: String?
    let data: LoginData?
}

struct Me: Decodable {
    let loggedIn: Bool?
    let username: String?
    let twoFAEnabled: Bool?
    enum CodingKeys: String, CodingKey {
        case loggedIn = "logged_in"
        case username
        case twoFAEnabled = "2fa_enabled"
    }
}

// MARK: - 节点

struct Node: Decodable, Identifiable {
    let uuid: String
    let name: String
    let cpuName: String?
    let cpuCores: Int?
    let os: String?
    let arch: String?
    let kernelVersion: String?
    let region: String?
    let virtualization: String?
    let memTotal: Int64?
    let diskTotal: Int64?
    let group: String?
    let tags: String?
    let hidden: Bool?
    let publicRemark: String?

    let price: Double?
    let billingCycle: Int?
    let currency: String?
    let expiredAt: String?
    let autoRenewal: Bool?

    let trafficLimit: Int64?
    let trafficLimitType: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, os, arch, region, virtualization, group, tags, hidden, price, currency
        case cpuName = "cpu_name"
        case cpuCores = "cpu_cores"
        case kernelVersion = "kernel_version"
        case memTotal = "mem_total"
        case diskTotal = "disk_total"
        case publicRemark = "public_remark"
        case billingCycle = "billing_cycle"
        case expiredAt = "expired_at"
        case autoRenewal = "auto_renewal"
        case trafficLimit = "traffic_limit"
        case trafficLimitType = "traffic_limit_type"
    }
}

// MARK: - 实时上报

struct Report: Decodable {
    struct CPU: Decodable { let usage: Double? }
    struct Mem: Decodable { let total: Int64?; let used: Int64? }
    struct Load: Decodable {
        let load1: Double?
        let load5: Double?
        let load15: Double?
    }
    struct Net: Decodable {
        let up: Int64?
        let down: Int64?
        let totalUp: Int64?
        let totalDown: Int64?
    }
    struct Conn: Decodable {
        let tcp: Int?
        let udp: Int?
    }

    let cpu: CPU?
    let ram: Mem?
    let disk: Mem?
    let swap: Mem?
    let load: Load?
    let network: Net?
    let connections: Conn?
    let uptime: Int64?
    let process: Int?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case cpu, ram, disk, swap, load, network, connections, uptime, process
        case updatedAt = "updated_at"
    }

    var trafficUsed: Int64? {
        if network?.totalUp == nil && network?.totalDown == nil { return nil }
        return (network?.totalUp ?? 0) + (network?.totalDown ?? 0)
    }
}

struct RealtimeData: Decodable {
    let online: [String]?
    let data: [String: Report]?

    init(online: [String]? = [], data: [String: Report]? = [:]) {
        self.online = online
        self.data = data
    }
}

typealias RealtimeEnvelope = Envelope<RealtimeData>

// MARK: - 历史记录

struct RecordPoint: Decodable, Identifiable {
    let time: String?
    let cpu: Double?
    let load: Double?
    let ram: Int64?
    let ramTotal: Int64?
    let ramPercent: Double?
    let netIn: Int64?
    let netOut: Int64?
    let netTotalUp: Int64?
    let netTotalDown: Int64?
    let diskPercent: Double?

    var id: String { time ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case time, cpu, load, ram
        case ramTotal = "ram_total"
        case ramPercent = "ram_percent"
        case netIn = "net_in"
        case netOut = "net_out"
        case netTotalUp = "net_total_up"
        case netTotalDown = "net_total_down"
        case diskPercent = "disk_percent"
    }
}

struct RecordsData: Decodable {
    let count: Int?
    let loadType: String?
    let records: [RecordPoint]?

    enum CodingKeys: String, CodingKey {
        case count, records
        case loadType = "load_type"
    }
}

// MARK: - 三网延迟

struct PingStat: Decodable, Identifiable {
    let id: Int
    let name: String
    let type: String?
    let interval: Int?
    let loss: Double?
    let min: Int?
    let max: Int?
    let avg: Double?
    let total: Int?
}

struct PingRecord: Decodable {
    let taskId: Int?
    let time: String?
    let value: Int?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case time
        case value
    }
}

struct PingResponse: Decodable {
    let count: Int?
    let tasks: [PingStat]?
    let records: [PingRecord]?
}

// MARK: - 管理

struct AdminLog: Decodable, Identifiable {
    let rawID: Int?
    let ip: String?
    let message: String?
    let msgType: String?
    let time: String?

    var id: String { "\(rawID ?? 0)-\(time ?? "")" }

    enum CodingKeys: String, CodingKey {
        case ip, message, time
        case rawID = "id"
        case msgType = "msg_type"
    }
}

struct AdminLogs: Decodable {
    let logs: [AdminLog]?
    let total: Int?
}

struct ExecResponse: Decodable {
    let taskID: String?
    let clients: [String]?
    let queuedClients: [String]?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case clients
        case queuedClients = "queued_clients"
    }
}

struct TaskResult: Decodable, Identifiable {
    let taskID: String?
    let client: String?
    let result: String?
    let exitCode: Int?
    let finishedAt: String?

    var id: String { "\(taskID ?? "")-\(client ?? "")" }

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case client, result
        case exitCode = "exit_code"
        case finishedAt = "finished_at"
    }
}

// MARK: - 格式化

enum Fmt {
    static func bytes(_ v: Int64?) -> String {
        guard let v else { return "—" }
        let d = Double(v)
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var x = d
        var i = 0
        while x >= 1024 && i < units.count - 1 { x /= 1024; i += 1 }
        return String(format: x >= 100 ? "%.0f %@" : "%.1f %@", x, units[i])
    }

    static func rate(_ v: Int64?) -> String {
        guard let v else { return "—" }
        return bytes(v) + "/s"
    }

    static func percent(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f%%", v)
    }

    static func uptime(_ seconds: Int64?) -> String {
        guard let s = seconds, s > 0 else { return "—" }
        let d = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        if d > 0 { return "\(d) 天" }
        if h > 0 { return "\(h) 小时" }
        return "\(m) 分"
    }

    static func money(_ v: Double?) -> String {
        guard let v else { return "—" }
        if abs(v.rounded() - v) < 0.005 { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    static func cycle(_ days: Int?) -> String {
        guard let d = days, d > 0 else { return "" }
        switch d {
        case 1...31: return "/月"
        case 32...100: return "/季"
        case 101...200: return "/半年"
        default: return "/年"
        }
    }

    static func priceText(_ node: Node) -> String? {
        guard let p = node.price, p > 0 else { return nil }
        return "\(node.currency ?? "$")\(money(p))\(cycle(node.billingCycle))"
    }

    static func dateOnly(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = f.date(from: iso)
        if date == nil {
            f.formatOptions = [.withInternetDateTime]
            date = f.date(from: iso)
        }
        guard let date else { return nil }
        let out = DateFormatter()
        out.dateFormat = "yyyy-MM-dd"
        return out.string(from: date)
    }

    static func daysUntil(_ iso: String?) -> Int? {
        guard let text = dateOnly(iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: text) else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day
    }

    static func expiryLabel(_ iso: String?) -> String? {
        guard let days = daysUntil(iso) else {
            return dateOnly(iso).map { "到期 \($0)" }
        }
        if days < 0 { return "已过期 \(abs(days)) 天" }
        if days == 0 { return "今天到期" }
        if days <= 45 { return "\(days) 天后到期" }
        return dateOnly(iso).map { "到期 \($0)" } ?? "\(days) 天后到期"
    }

    static func trafficText(used: Int64?, limit: Int64?) -> String {
        let u = bytes(used ?? 0)
        guard let l = limit, l > 0 else { return "\(u) / ∞" }
        return "\(u) / \(bytes(l))"
    }
}
