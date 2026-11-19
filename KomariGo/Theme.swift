import SwiftUI
import UIKit

// MARK: - 设计令牌（Deep Navy Console）

/// 地区名 → 两位国家码。键统一小写。
private let regionNameMap: [String: String] = [
    "中国": "CN", "中国大陆": "CN", "china": "CN", "cn": "CN", "中华人民共和国": "CN",
    "香港": "HK", "hong kong": "HK", "hongkong": "HK",
    "台湾": "TW", "taiwan": "TW",
    "澳门": "MO", "macao": "MO", "macau": "MO",
    "日本": "JP", "japan": "JP", "东京": "JP", "大阪": "JP",
    "韩国": "KR", "south korea": "KR", "korea": "KR", "首尔": "KR", "seoul": "KR",
    "新加坡": "SG", "singapore": "SG",
    "美国": "US", "united states": "US", "usa": "US", "america": "US",
    "洛杉矶": "US", "圣何塞": "US", "西雅图": "US", "纽约": "US", "达拉斯": "US",
    "阿什本": "US", "硅谷": "US", "芝加哥": "US", "迈阿密": "US",
    "加拿大": "CA", "canada": "CA", "多伦多": "CA", "蒙特利尔": "CA",
    "德国": "DE", "germany": "DE", "法兰克福": "DE", "纽伦堡": "DE", "柏林": "DE",
    "英国": "GB", "united kingdom": "GB", "uk": "GB", "england": "GB", "伦敦": "GB",
    "法国": "FR", "france": "FR", "巴黎": "FR", "马赛": "FR", "paris": "FR", "marseille": "FR",
    "荷兰": "NL", "netherlands": "NL", "阿姆斯特丹": "NL",
    "俄罗斯": "RU", "russia": "RU", "莫斯科": "RU",
    "澳大利亚": "AU", "australia": "AU", "悉尼": "AU",
    "印度": "IN", "india": "IN", "孟买": "IN",
    "印度尼西亚": "ID", "indonesia": "ID", "雅加达": "ID",
    "马来西亚": "MY", "malaysia": "MY", "吉隆坡": "MY",
    "泰国": "TH", "thailand": "TH", "曼谷": "TH",
    "越南": "VN", "vietnam": "VN",
    "菲律宾": "PH", "philippines": "PH",
    "土耳其": "TR", "turkey": "TR",
    "阿联酋": "AE", "uae": "AE", "迪拜": "AE",
    "以色列": "IL", "israel": "IL",
    "巴西": "BR", "brazil": "BR", "圣保罗": "BR",
    "阿根廷": "AR", "argentina": "AR",
    "智利": "CL", "chile": "CL",
    "墨西哥": "MX", "mexico": "MX",
    "南非": "ZA", "south africa": "ZA",
    "埃及": "EG", "egypt": "EG",
    "瑞士": "CH", "switzerland": "CH", "苏黎世": "CH",
    "瑞典": "SE", "sweden": "SE",
    "挪威": "NO", "norway": "NO",
    "丹麦": "DK", "denmark": "DK",
    "芬兰": "FI", "finland": "FI",
    "波兰": "PL", "poland": "PL", "华沙": "PL",
    "捷克": "CZ", "czechia": "CZ", "czech": "CZ", "布拉格": "CZ",
    "奥地利": "AT", "austria": "AT", "维也纳": "AT",
    "比利时": "BE", "belgium": "BE",
    "爱尔兰": "IE", "ireland": "IE", "都柏林": "IE",
    "葡萄牙": "PT", "portugal": "PT",
    "西班牙": "ES", "spain": "ES", "马德里": "ES",
    "意大利": "IT", "italy": "IT", "米兰": "IT",
    "罗马尼亚": "RO", "romania": "RO",
    "保加利亚": "BG", "bulgaria": "BG",
    "乌克兰": "UA", "ukraine": "UA",
    "匈牙利": "HU", "hungary": "HU",
    "立陶宛": "LT", "lithuania": "LT",
    "拉脱维亚": "LV", "latvia": "LV",
    "爱沙尼亚": "EE", "estonia": "EE",
    "哈萨克斯坦": "KZ", "kazakhstan": "KZ",
    "沙特": "SA", "saudi arabia": "SA",
    "卡塔尔": "QA", "qatar": "QA",
    "新西兰": "NZ", "new zealand": "NZ",
    "巴基斯坦": "PK", "pakistan": "PK",
    "孟加拉": "BD", "bangladesh": "BD",
    "斯里兰卡": "LK", "sri lanka": "LK",
    "蒙古": "MN", "mongolia": "MN",
    "柬埔寨": "KH", "cambodia": "KH",
    "缅甸": "MM", "myanmar": "MM",
    "尼泊尔": "NP", "nepal": "NP",
    "哥伦比亚": "CO", "colombia": "CO",
    "秘鲁": "PE", "peru": "PE",
    "委内瑞拉": "VE", "venezuela": "VE"
]

/// 按长度倒序排列的映射，保证「ukraine」先于「uk」、「洛杉矶」先于短词命中
private let regionNameMapByLength: [RegionEntry] = {
    regionNameMap.map { (k, v) in RegionEntry(key: k.lowercased(), code: v) }
        .sorted { $0.key.count > $1.key.count }
}()

/// 地区名条目
private struct RegionEntry {
    let key: String
    let code: String
}

private func flagOfCode(_ code: String) -> String {
    // 只接受 ASCII 字母：Swift 的 isLetter 对汉字也返回 true，会算出越界码位
    let chars = Array(code)
    guard chars.count == 2,
          chars.allSatisfy({ $0.isASCII && $0.isLetter }),
          let f = UnicodeScalar(Int(chars[0].asciiValue ?? 65) - 65 + 0x1F1E6),
          let l = UnicodeScalar(Int(chars[1].asciiValue ?? 65) - 65 + 0x1F1E6)
    else { return "" }
    return String(Character(f)) + String(Character(l))
}

/// 从地区名/节点名推断国旗 emoji。
///
/// 优先级：两位国家码 → 名称精确匹配 → 名称全串包含匹配（长词优先）。
/// 与 Android 版 `flagOf()` 行为一致。
func flagEmoji(_ region: String?) -> String {
    let raw = (region ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty { return "" }

    // 1) 已经是两位国家码
    if raw.count == 2, raw.allSatisfy({ $0.isASCII && $0.isLetter }) {
        return flagOfCode(raw)
    }

    // 2) 可能是 "US - Los Angeles" / "美国-洛杉矶" 这类，先取前段
    let separators = CharacterSet(charactersIn: "-—·,， _")
    let head = raw.components(separatedBy: separators)
        .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
        .trimmingCharacters(in: .whitespaces) ?? ""
    if head.count == 2, head.allSatisfy({ $0.isASCII && $0.isLetter }) {
        return flagOfCode(head)
    }

    let key = head.lowercased()
    if let code = regionNameMap[key] ?? regionNameMap[raw.lowercased()] {
        return flagOfCode(code)
    }

    // 3) 名称里带地名的情况，如「CC洛杉矶1000M 3T」「NC纽伦堡1000M 无限」
    let lower = raw.lowercased()
    for entry in regionNameMapByLength where entry.key.count >= 2 && lower.contains(entry.key) {
        return flagOfCode(entry.code)
    }
    return ""
}

enum KMTheme {
    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // 背景与容器
    static let bgTop = dyn(light: 0xF4F7FB, dark: 0x0A0E17)
    static let bgBottom = dyn(light: 0xE9EFF7, dark: 0x0D1522)
    static let card = dyn(light: 0xFFFFFF, dark: 0x141A26)
    static let inner = dyn(light: 0xEEF3F9, dark: 0x1A2230)
    static let border = dyn(light: 0xD8E1EE, dark: 0x20304A)
    static let track = dyn(light: 0xE1E8F2, dark: 0x243247)

    // 文字
    static let text = dyn(light: 0x0E1622, dark: 0xE6EDF3)
    static let muted = dyn(light: 0x5B6B80, dark: 0x8B96A8)
    static let dim = dyn(light: 0x8494A8, dark: 0x5F6B7D)

    // 指标分类色
    static let cpu = dyn(light: 0x0E8C82, dark: 0x2BB3A8)
    static let mem = dyn(light: 0x1F8B45, dark: 0x46B96B)
    static let disk = dyn(light: 0xA66B00, dark: 0xD29922)
    static let net = dyn(light: 0x6D5BD0, dark: 0x8B7CF6)

    // 状态色
    static let ok = dyn(light: 0x1A7F37, dark: 0x3FB950)
    static let warn = dyn(light: 0xB26A00, dark: 0xD29922)
    static let bad = dyn(light: 0xD1242C, dark: 0xF85149)
    static let accent = dyn(light: 0x0B66C3, dark: 0x58A6FF)
    static let pink = dyn(light: 0xC2417E, dark: 0xDB6AA8)

    // 状态胶囊底色
    static let okBg = dyn(light: 0xE7F6EC, dark: 0x12291A)
    static let badBg = dyn(light: 0xFDECEC, dark: 0x2A1618)

    static let cardRadius: CGFloat = 18
    static let innerRadius: CGFloat = 12

    /// 分类色 + 阈值：75% 起警告，90% 起危险
    static func level(_ percent: Double, base: Color) -> Color {
        if percent >= 90 { return bad }
        if percent >= 75 { return warn }
        return base
    }

    /// 延迟/丢包：丢包>5% 或 >200ms 红；有丢包或 >100ms 琥珀
    static func latency(ms: Int?, loss: Double?) -> Color {
        let l = loss ?? 0
        if l > 5 { return bad }
        if let ms, ms > 200 { return bad }
        if l > 0 { return warn }
        if let ms, ms > 100 { return warn }
        return text
    }

    static func lossColor(_ loss: Double) -> Color {
        if loss > 5 { return bad }
        if loss > 0 { return warn }
        return text
    }

    static func carrierColor(_ name: String) -> Color {
        if name.contains("电信") { return accent }
        if name.contains("联通") { return pink }
        if name.contains("移动") { return ok }
        return muted
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1
        )
    }
}

// MARK: - 基础组件

struct KMBackground: View {
    var body: some View {
        LinearGradient(
            colors: [KMTheme.bgTop, KMTheme.bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct KMHairline: View {
    var opacity: Double = 1
    var body: some View {
        Rectangle()
            .fill(KMTheme.border.opacity(opacity))
            .frame(height: 1)
    }
}

struct KMCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: KMTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KMTheme.cardRadius, style: .continuous)
                    .stroke(KMTheme.border, lineWidth: 1)
            )
    }
}

struct MicroBar: View {
    let ratio: Double
    let color: Color
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(KMTheme.track)
                if ratio > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(ratio, 0), 1))))
                }
            }
        }
        .frame(height: height)
    }
}

struct MonoLabel: View {
    let text: String
    var size: CGFloat = 10
    var weight: Font.Weight = .regular
    var color: Color = KMTheme.muted

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(color)
    }
}

struct StatusPill: View {
    let online: Int
    let total: Int

    private var color: Color {
        if total == 0 { return KMTheme.muted }
        if online == total { return KMTheme.ok }
        return online == 0 ? KMTheme.bad : KMTheme.warn
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(online)/\(total) ONLINE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(KMTheme.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(KMTheme.accent.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(KMTheme.accent.opacity(0.14), lineWidth: 1))
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    var sub: String? = nil
    let ratio: Double
    var color: Color = KMTheme.cpu
    var icon: String = "cpu"
    var showBar: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(KMTheme.muted)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if showBar {
                GradBar(ratio: ratio, base: color)
            } else {
                Color.clear.frame(height: 6)
            }
            if let sub {
                Text(sub)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(KMTheme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GradBar: View {
    let ratio: Double
    let base: Color

    var body: some View {
        GeometryReader { geo in
            let pct = min(max(ratio, 0), 1)
            let color: Color = pct >= 0.9 ? KMTheme.bad : (pct >= 0.75 ? KMTheme.warn : base)
            ZStack(alignment: .leading) {
                Capsule().fill(KMTheme.track)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.42), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * pct))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - 三网表格

struct PingTable: View {
    let stats: [PingStat]
    var samples: [Int: [Int]] = [:]

    private var ordered: [PingStat] {
        Array(stats.sorted { rank($0.name) < rank($1.name) }.prefix(3))
    }

    private func rank(_ name: String) -> Int {
        if name.contains("联通") { return 0 }
        if name.contains("电信") { return 1 }
        if name.contains("移动") { return 2 }
        return 3
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column("延迟", loss: false)
            column("丢包", loss: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KMTheme.inner)
        .clipShape(RoundedRectangle(cornerRadius: KMTheme.innerRadius, style: .continuous))
    }

    private func column(_ title: String, loss: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KMTheme.text)
                Spacer(minLength: 0)
                MonoLabel(text: "三网", size: 8, weight: .semibold, color: KMTheme.dim)
            }
            if ordered.isEmpty {
                MonoLabel(text: "—", size: 10, color: KMTheme.dim)
            } else {
                ForEach(ordered) { s in
                    row(s, loss: loss)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ s: PingStat, loss: Bool) -> some View {
        let ms = s.avg.map { Int($0.rounded()) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(KMTheme.carrierColor(s.name))
                    .frame(width: 5, height: 5)
                Text(s.name)
                    .font(.system(size: 10))
                    .foregroundStyle(KMTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if loss {
                    Text(s.loss.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KMTheme.lossColor(s.loss ?? 0))
                    MonoLabel(text: "%", size: 8.5, color: KMTheme.muted)
                } else {
                    Text(ms.map { "\($0)" } ?? "—")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KMTheme.latency(ms: ms, loss: s.loss))
                    if ms != nil {
                        MonoLabel(text: "ms", size: 8.5, color: KMTheme.muted)
                    }
                }
            }
            SegBar(colors: loss ? lossSegments(s) : latencySegments(s))
        }
        .padding(.bottom, 1)
    }

    private func latencySegments(_ s: PingStat) -> [Color] {
        let n = 16
        let series = samples[s.id] ?? []
        if series.isEmpty {
            guard let avg = s.avg, avg > 0 else {
                return Array(repeating: KMTheme.track, count: n)
            }
            let filled = Int(Double(n) * (1 - min(max(avg / 400.0, 0), 1)))
            let count = min(max(filled, 3), n)
            let color = KMTheme.latency(ms: Int(avg.rounded()), loss: s.loss)
            return (0..<n).map { $0 < count ? color : KMTheme.track }
        }
        return (0..<n).map { i in
            let from = i * series.count / n
            let to = min((i + 1) * series.count / n, series.count)
            guard from < to else { return KMTheme.track }
            let slice = series[from..<to]
            let avg = Double(slice.reduce(0, +)) / Double(slice.count)
            return avg <= 0 ? KMTheme.track : KMTheme.latency(ms: Int(avg.rounded()), loss: nil)
        }
    }

    private func lossSegments(_ s: PingStat) -> [Color] {
        let n = 16
        let loss = s.loss ?? 0
        let filled = loss <= 0 ? 3 : max(1, Int(min(loss / 20.0, 1) * Double(n)))
        let color = KMTheme.lossColor(loss)
        return (0..<n).map { $0 < filled ? color : KMTheme.track }
    }
}

struct SegBar: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
    }
}

// MARK: - 历史曲线

struct SparkArea: View {
    let values: [Double]
    var color: Color = KMTheme.cpu

    private var maxValue: Double { max(values.max() ?? 1, 1) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(values.count, 2)

            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(KMTheme.border).frame(height: 1)
                }

                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count - 1)
                        let y = h - h * CGFloat(min(max(v / maxValue, 0), 1))
                        if i == 0 { p.addLine(to: CGPoint(x: 0, y: y)) }
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.40), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { p in
                    guard !values.isEmpty else { return }
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count - 1)
                        let y = h - h * CGFloat(min(max(v / maxValue, 0), 1))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
