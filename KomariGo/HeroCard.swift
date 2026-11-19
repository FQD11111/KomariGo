import SwiftUI

// MARK: - 首页四格数字卡（在线 / 下行 / 上行 / 今日流量）

/// 占比弹窗的类型
enum BreakKind: String, Identifiable {
    case today, down, up

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日流量占比"
        case .down: return "实时下行占比"
        case .up: return "实时上行占比"
        }
    }

    var emptyHint: String {
        switch self {
        case .today: return "今天还没有流量记录\n流量统计从当天首次打开 App 开始累加"
        case .down: return "当前没有下行流量\n所有服务器此刻都没有下行数据"
        case .up: return "当前没有上行流量\n所有服务器此刻都没有上行数据"
        }
    }

    var barColor: Color {
        switch self {
        case .up: return KMTheme.net
        default: return KMTheme.accent
        }
    }
}

/// B 版首页顶部四格数字卡
struct HeroCard: View {
    @EnvironmentObject var store: Store

    let onBreak: (BreakKind) -> Void

    private var onlineColor: Color {
        let total = store.nodes.count
        let on = store.online.count
        if total == 0 { return KMTheme.muted }
        if on == total { return KMTheme.ok }
        if on == 0 { return KMTheme.bad }
        return KMTheme.warn
    }

    var body: some View {
        HStack(spacing: 0) {
            HeroCell(
                label: "在线",
                value: "\(store.online.count)",
                suffix: "/\(store.nodes.count)",
                color: onlineColor,
                tap: false
            )
            HeroCell(
                label: "下行",
                value: Fmt.rate(store.liveDown).replacingOccurrences(of: " ", with: ""),
                suffix: "",
                color: KMTheme.accent,
                tap: true
            ) { onBreak(.down) }
            HeroCell(
                label: "上行",
                value: Fmt.rate(store.liveUp).replacingOccurrences(of: " ", with: ""),
                suffix: "",
                color: KMTheme.net,
                tap: true
            ) { onBreak(.up) }
            HeroCell(
                label: "今日流量",
                value: Fmt.bytes(store.todayTraffic.total).replacingOccurrences(of: " ", with: ""),
                suffix: "",
                color: KMTheme.text,
                tap: true
            ) { onBreak(.today) }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(KMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KMTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KMTheme.cardRadius, style: .continuous)
                .stroke(KMTheme.border.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: KMTheme.dyn(light: 0x14102040, dark: 0x00000000),
                radius: 12, x: 0, y: 6)
    }
}

/// 四格中的一格
struct HeroCell: View {
    let label: String
    let value: String
    let suffix: String
    let color: Color
    /// 是否可点（可点的格子标签下有虚线提示）
    let tap: Bool
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(KMTheme.muted)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) {
                    if tap {
                        Rectangle()
                            .fill(KMTheme.dim.opacity(0.55))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
                }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(KMTheme.dim)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if tap { action?() }
        }
    }
}

// MARK: - 各 VPS 占比明细弹窗

struct TrafficBreakdownSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let kind: BreakKind

    /// 弹窗里的一行数据
    struct Row: Identifiable {
        let node: Node
        let value: Int64
        var id: String { node.uuid }
    }

    private var rows: [Row] {
        store.nodes
            .map { node -> Row in
                let v: Int64
                switch kind {
                case .today: v = store.todayTrafficOf(node.uuid)
                case .down: v = store.liveDownOf(node.uuid)
                case .up: v = store.liveUpOf(node.uuid)
                }
                return Row(node: node, value: v)
            }
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }

    private var total: Int64 {
        let sum = rows.reduce(Int64(0)) { $0 + $1.value }
        if sum > 0 { return sum }
        switch kind {
        case .today: return store.todayTraffic.total
        case .down: return store.liveDown
        case .up: return store.liveUp
        }
    }

    private func valueText(_ v: Int64) -> String {
        switch kind {
        case .today: return Fmt.bytes(v).replacingOccurrences(of: " ", with: "")
        default: return Fmt.rate(v).replacingOccurrences(of: " ", with: "")
        }
    }

    private func totalText(_ v: Int64) -> String {
        switch kind {
        case .today: return Fmt.bytes(v).replacingOccurrences(of: " ", with: "")
        default: return Fmt.rate(v).replacingOccurrences(of: " ", with: "")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("合计 \(totalText(total)) · \(rows.count) 台服务器")
                        .font(.system(size: 11.5))
                        .foregroundStyle(KMTheme.muted)
                        .padding(.bottom, 12)

                    if rows.isEmpty {
                        Text(kind.emptyHint)
                            .font(.system(size: 12))
                            .foregroundStyle(KMTheme.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(rows) { row in
                            BreakRow(
                                node: row.node,
                                value: valueText(row.value),
                                percent: total > 0 ? Double(row.value) / Double(total) : 0,
                                color: kind.barColor
                            )
                            .padding(.bottom, 12)
                        }
                    }
                }
                .padding(16)
            }
            .background(KMBackground())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// 弹窗里的一行：旗帜 + 名称 + 数值 + 百分比 + 条形图
struct BreakRow: View {
    let node: Node
    let value: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let flag = flagEmoji(node.region).isEmpty ? flagEmoji(node.name) : flagEmoji(node.region)
                if !flag.isEmpty {
                    Text(flag).font(.system(size: 13))
                }
                Text(node.name)
                    .font(.system(size: 12.5))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KMTheme.muted)
                Text(String(format: "%.1f%%", percent * 100))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .frame(width: 46, alignment: .trailing)
            }
            MicroBar(ratio: percent, color: color, height: 5)
        }
    }
}
