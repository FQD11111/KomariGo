import SwiftUI

/// 三网线路评级
///
/// 综合三网（电信 / 联通 / 移动）的平均延迟与丢包率，输出 0–100 分与六档评价。
/// 基准分由平均延迟映射，丢包按比例扣分（上限 25 分）。
/// 与 Android 版 `LineRate.kt` 算法保持完全一致。
enum LineRate {

    // 档位定义：最低分 → 名称
    private static let levels: [(min: Int, name: String)] = [
        (92, "丝滑"),
        (80, "优秀"),
        (68, "良好"),
        (54, "一般"),
        (38, "拥塞"),
        (-1, "劣化")
    ]

    /// 平均延迟 → 基准分
    private static func baseScore(_ ms: Double) -> Int {
        switch ms {
        case ...20: return 98
        case ...30: return 95
        case ...45: return 90
        case ...65: return 83
        case ...90: return 78
        case ...120: return 70
        case ...160: return 60
        case ...220: return 50
        case ...300: return 40
        case ...450: return 28
        default: return 12
        }
    }

    static func levelName(_ score: Int) -> String {
        levels.first { score >= $0.min }?.name ?? "劣化"
    }

    /// 档位主色
    static func levelColor(_ name: String) -> Color {
        switch name {
        case "丝滑": return KMTheme.ok
        case "优秀": return KMTheme.accent
        case "良好": return KMTheme.cpu
        case "一般": return KMTheme.warn
        case "拥塞": return KMTheme.dyn(light: 0xC2410C, dark: 0xE8703A)
        default: return KMTheme.bad
        }
    }

    /// 档位底色
    static func levelBg(_ name: String) -> Color {
        switch name {
        case "丝滑": return KMTheme.okBg
        case "优秀": return KMTheme.dyn(light: 0xE7F1FC, dark: 0x12233A)
        case "良好": return KMTheme.dyn(light: 0xE4F5F3, dark: 0x10292A)
        case "一般": return KMTheme.dyn(light: 0xFBF2DF, dark: 0x2B2411)
        case "拥塞": return KMTheme.dyn(light: 0xFCEEE4, dark: 0x2E1A10)
        default: return KMTheme.badBg
        }
    }

    /// 计算某台节点的三网评级；无有效数据时返回 nil
    static func of(_ stats: [PingStat]) -> Result? {
        guard !stats.isEmpty else { return nil }
        // 归并到固定三栏，只取有有效延迟的
        let valid = threeCarriers(stats).compactMap { $0.ping }.filter { ($0.avg ?? 0) > 0 }
        guard !valid.isEmpty else { return nil }

        let mean = valid.reduce(0.0) { $0 + ($1.avg ?? 0) } / Double(valid.count)
        let loss = valid.reduce(0.0) { $0 + ($1.loss ?? 0) } / Double(valid.count)
        let penalty = min(25.0, loss * 3.0)
        let score = max(0, min(100, Int(baseScore(mean) - penalty)))
        let name = levelName(score)

        return Result(
            score: score,
            name: name,
            meanMs: Int(mean.rounded()),
            lossPct: loss,
            covered: valid.count,
            color: levelColor(name),
            bg: levelBg(name)
        )
    }

    /// 三栏中的一个运营商
    struct CarrierSlot {
        let carrier: String
        let ping: PingStat?
    }

    /// 把面板里的探测任务按运营商归并成固定三栏（电信 / 联通 / 移动）
    /// 同一运营商有多条任务时取延迟最低的那条（超时视为无穷大），缺失的返回 nil
    static func threeCarriers(_ stats: [PingStat]) -> [CarrierSlot] {
        let order = ["电信", "联通", "移动"]
        let by = Dictionary(grouping: stats) { carrierName($0.name) }
        return order.map { carrier in
            let best = by[carrier]?.min { a, b in
                let av = a.avg ?? .greatestFiniteMagnitude
                let bv = b.avg ?? .greatestFiniteMagnitude
                if av <= 0 { return false }
                if bv <= 0 { return true }
                return av < bv
            }
            return CarrierSlot(carrier: carrier, ping: best)
        }
    }

    static func carrierName(_ name: String) -> String {
        if name.contains("电信") { return "电信" }
        if name.contains("联通") { return "联通" }
        if name.contains("移动") { return "移动" }
        return "其他"
    }

    struct Result {
        let score: Int
        let name: String
        let meanMs: Int
        let lossPct: Double
        let covered: Int
        let color: Color
        let bg: Color
    }
}
