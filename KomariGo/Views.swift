import SwiftUI
import UIKit

@main
struct KomariGoApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack {
            KMBackground()
            Group {
                if store.isLoggedIn {
                    NodeListView()
                } else {
                    LoginView()
                }
            }
        }
        .preferredColorScheme(store.colorScheme)
        .task {
            await store.validateSession()
        }
    }
}

// MARK: - 登录

struct LoginView: View {
    @EnvironmentObject var store: Store
    var editing: Server? = nil
    var onCancel: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    @State private var alias: String
    @State private var host: String
    @State private var user: String
    @State private var password = ""
    @State private var twoFA = ""

    init(editing: Server? = nil, onCancel: (() -> Void)? = nil, onDone: (() -> Void)? = nil) {
        self.editing = editing
        self.onCancel = onCancel
        self.onDone = onDone
        _alias = State(initialValue: editing?.alias ?? "")
        _host = State(initialValue: editing?.host ?? "")
        _user = State(initialValue: editing?.user ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let onCancel {
                    Button {
                        onCancel()
                    } label: {
                        Text("‹ 返回")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(KMTheme.accent)
                    }
                    .padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel(text: "KOMARI", size: 10, weight: .bold, color: KMTheme.accent)
                    Text(editing == nil && !store.servers.isEmpty ? "添加服务器" : "Telemetry Console")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(KMTheme.text)
                    Text("连接你的 Komari 面板")
                        .font(.system(size: 12))
                        .foregroundStyle(KMTheme.muted)
                }
                .padding(.top, 40)

                KMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        field("ALIAS", text: $alias, placeholder: "可选，例如 香港 / 洛杉矶", keyboard: .default)
                        KMHairline(opacity: 0.6)
                        field("PANEL URL", text: $host, placeholder: "https://monitor.example.com", keyboard: .URL)
                        KMHairline(opacity: 0.6)
                        field("USERNAME", text: $user, placeholder: "admin", keyboard: .default)
                        KMHairline(opacity: 0.6)
                        secureField("PASSWORD", text: $password)
                        KMHairline(opacity: 0.6)
                        field("2FA CODE", text: $twoFA, placeholder: "可选", keyboard: .numberPad)
                    }
                }

                if let error = store.error {
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(KMTheme.bad)
                }

                Button {
                    Task {
                        let ok = await store.login(
                            alias: alias, host: host, username: user,
                            password: password, twoFA: twoFA, serverID: editing?.id
                        )
                        if ok { onDone?() }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if store.loading {
                            ProgressView().tint(.white)
                        } else {
                            Text("CONNECT")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .background(KMTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(host.isEmpty || user.isEmpty || password.isEmpty || store.loading)
                .opacity(host.isEmpty || user.isEmpty || password.isEmpty ? 0.5 : 1)

                Text("数据直连面板，不经过第三方")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(KMTheme.dim)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            MonoLabel(text: label, size: 9, weight: .semibold)
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(KMTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
        }
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            MonoLabel(text: label, size: 9, weight: .semibold)
            SecureField("••••••••", text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(KMTheme.text)
        }
    }
}

// MARK: - 节点列表

struct NodeListView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var showSettings = false
    @State private var showServers = false
    @State private var searching = false
    @State private var filter = "all"
    @State private var breakKind: BreakKind?
    @FocusState private var searchFocused: Bool

    private var filtered: [Node] {
        store.sortedNodes.filter { n in
            let match = query.isEmpty
                || n.name.localizedCaseInsensitiveContains(query)
                || (n.os ?? "").localizedCaseInsensitiveContains(query)
                || (n.region ?? "").localizedCaseInsensitiveContains(query)
                || (n.group ?? "").localizedCaseInsensitiveContains(query)
            let inFilter: Bool
            switch filter {
            case "fav": inFilter = store.favorites.contains(n.uuid)
            case "online": inFilter = store.online.contains(n.uuid)
            case "offline": inFilter = !store.online.contains(n.uuid)
            default: inFilter = true
            }
            return match && inFilter
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if searching {
                    SearchRow(text: $query, focused: $searchFocused) {
                        searching = false
                        query = ""
                        searchFocused = false
                    }
                    .padding(.bottom, 8)
                } else {
                    VStack(spacing: 11) {
                        HeroCard { kind in breakKind = kind }
                        filterPills
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                List {
                    ForEach(filtered) { node in
                        NavigationLink {
                            NodeDetailView(node: node)
                        } label: {
                            NodeCard(node: node)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .refreshable {
                    await store.refresh()
                    await store.pollOnce()
                    store.syncTrafficBaseline()
                }
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showServers) { ServerListSheet() }
            .sheet(item: $breakKind) { kind in
                TrafficBreakdownSheet(kind: kind)
                    .environmentObject(store)
            }
            .overlay {
                if store.loading && store.nodes.isEmpty {
                    ProgressView().tint(KMTheme.accent)
                } else if store.nodes.isEmpty {
                    EmptyHint(title: "NO NODES", subtitle: store.error ?? "面板里还没有客户端上报")
                }
            }
            .task {
                if store.nodes.isEmpty { await store.refresh() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [KMTheme.accent, KMTheme.net],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("K")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            Button {
                showServers = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("Komari")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(KMTheme.text)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(KMTheme.muted)
                    }
                    Text(store.currentAlias)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(KMTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { showServers = true } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 17))
                    .foregroundStyle(KMTheme.muted)
            }
            .buttonStyle(.plain)

            Button {
                searching = true
                searchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17))
                    .foregroundStyle(KMTheme.muted)
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17))
                    .foregroundStyle(KMTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var filterPills: some View {
        let items: [(String, String)] = [
            ("all", "全部节点"),
            ("fav", "★ 收藏 \(store.favorites.count)"),
            ("online", "在线 \(store.online.count)"),
            ("offline", "离线 \(max(0, store.nodes.count - store.online.count))")
        ]
        return HStack(spacing: 7) {
            ForEach(items, id: \.0) { item in
                Button { filter = item.0 } label: {
                    Text(item.1)
                        .font(.system(size: 12, weight: filter == item.0 ? .semibold : .regular))
                        .foregroundStyle(filter == item.0 ? KMTheme.accent : KMTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(filter == item.0 ? KMTheme.accent.opacity(0.13) : KMTheme.card)
                        .overlay(
                            Capsule().stroke(filter == item.0 ? KMTheme.accent.opacity(0.3) : KMTheme.border.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SummaryCellView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(KMTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(KMTheme.dim)
            }
            Text(value)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(KMTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KMTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KMTheme.border.opacity(0.55), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct EmptyHint: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 26))
                .foregroundStyle(KMTheme.dim)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(KMTheme.muted)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(KMTheme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - 顶部状态带（B 方案）

struct TelemetryStrip: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            KMHairline(opacity: 0.45)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(store.onlineCount == store.nodes.count && store.nodes.count > 0
                              ? KMTheme.ok
                              : (store.onlineCount == 0 ? KMTheme.bad : KMTheme.warn))
                        .frame(width: 5, height: 5)
                    MonoLabel(text: "\(store.onlineCount)/\(store.nodes.count)", size: 9,
                              weight: .bold, color: KMTheme.muted)
                }
                Text("↓" + Fmt.rate(store.liveDown))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("↑" + Fmt.rate(store.liveUp))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                MonoLabel(text: "TODAY", size: 8.5, weight: .semibold)
                Text(Fmt.bytes(store.todayTraffic.total))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            KMHairline(opacity: 0.45)
        }
    }
}

struct SearchRow: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KMTheme.muted)
                TextField("搜索名称 / 系统 / 地区", text: $text)
                    .font(.system(size: 13))
                    .foregroundStyle(KMTheme.text)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(KMTheme.inner)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(KMTheme.accent.opacity(0.35), lineWidth: 1)
            )

            Button("取消") {
                onCancel()
            }
            .font(.system(size: 13))
            .foregroundStyle(KMTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

// MARK: - 节点卡片

struct NodeCard: View {
    @EnvironmentObject var store: Store
    let node: Node

    private var report: Report? { store.reports[node.uuid] }
    private var isOnline: Bool { store.online.contains(node.uuid) }
    private var fav: Bool { store.favorites.contains(node.uuid) }

    private var memPercent: Double {
        guard let r = report?.ram, let total = r.total, total > 0, let used = r.used else { return 0 }
        return Double(used) / Double(total) * 100
    }

    private var diskPercent: Double {
        guard let d = report?.disk, let total = d.total, total > 0, let used = d.used else { return 0 }
        return Double(used) / Double(total) * 100
    }

    private var limit: Int64? {
        guard let l = node.trafficLimit, l > 0 else { return nil }
        return l
    }

    private var trafficPercent: Double {
        guard let l = limit, let used = report?.trafficUsed else { return 0 }
        return Double(used) / Double(l) * 100
    }

    private var trafficValue: String {
        guard limit != nil else { return "∞" }
        return String(format: "%.0f%%", trafficPercent)
    }

    private var daysText: String {
        guard let d = Fmt.daysUntil(node.expiredAt) else { return "—" }
        if d < 0 { return "已过期" }
        if d == 0 { return "今天到期" }
        return "剩余 \(d) 天"
    }

    private var remainingValue: String {
        guard let price = node.price, price > 0, let d = Fmt.daysUntil(node.expiredAt) else { return "—" }
        let cycleDays = Double(node.billingCycle ?? 365)
        let days = Double(max(d, 0))
        let value = price * days / max(cycleDays, 1)
        return "\(node.currency ?? "$")\(Fmt.money(value))"
    }

    /// 规格摘要：`2核 · 4GB · KVM`
    private var specText: String? {
        var parts: [String] = []
        if let cores = node.cpuCores, cores > 0 { parts.append("\(cores)核") }
        if let mem = node.memTotal, mem > 0 {
            parts.append(Fmt.bytes(mem).replacingOccurrences(of: " ", with: ""))
        }
        if let virt = node.virtualization, !virt.isEmpty { parts.append(virt) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: isOnline ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isOnline ? KMTheme.ok : KMTheme.bad)
                    Text(node.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KMTheme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !flagEmoji(node.region).isEmpty {
                        Text(flagEmoji(node.region))
                            .font(.system(size: 15))
                    }
                    Button {
                        store.toggleFav(node.uuid)
                    } label: {
                        Image(systemName: fav ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(fav ? KMTheme.warn : KMTheme.dim)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    TagText(text: isOnline ? "在线 \(Fmt.uptime(report?.uptime))" : "离线")
                    if let spec = specText {
                        TagText(text: spec)
                    }
                    if let price = Fmt.priceText(node) {
                        TagText(text: price)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    MetricCell(
                        label: "处理器", value: Fmt.percent(report?.cpu?.usage),
                        sub: String(format: "%.2f, %.2f, %.2f",
                                    report?.load?.load1 ?? 0, report?.load?.load5 ?? 0, report?.load?.load15 ?? 0),
                        ratio: (report?.cpu?.usage ?? 0) / 100,
                        color: KMTheme.cpu, icon: "cpu"
                    )
                    MetricCell(
                        label: "内存", value: Fmt.percent(memPercent),
                        sub: "\(Fmt.bytes(report?.ram?.used)) / \(Fmt.bytes(report?.ram?.total))",
                        ratio: memPercent / 100,
                        color: KMTheme.mem, icon: "memorychip"
                    )
                }
                HStack(alignment: .top, spacing: 16) {
                    MetricCell(
                        label: "硬盘", value: Fmt.percent(diskPercent),
                        sub: "\(Fmt.bytes(report?.disk?.used)) / \(Fmt.bytes(report?.disk?.total))",
                        ratio: diskPercent / 100,
                        color: diskPercent >= 75 ? KMTheme.disk : KMTheme.accent, icon: "internaldrive"
                    )
                    MetricCell(
                        label: "流量", value: trafficValue,
                        sub: "\(Fmt.bytes(report?.trafficUsed)) / \(limit != nil ? Fmt.bytes(limit) : "不限")",
                        ratio: trafficPercent / 100,
                        color: KMTheme.net, icon: "arrow.up.arrow.down",
                        showBar: limit != nil
                    )
                }

                VStack(spacing: 5) {
                    KMHairline(opacity: 0.4)
                    HStack(spacing: 12) {
                        FooterPair(symbol: "↑", value: Fmt.rate(report?.network?.up))
                        FooterPair(symbol: "⇧", value: Fmt.bytes(report?.network?.totalUp))
                        Spacer(minLength: 4)
                        Text(daysText)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(KMTheme.muted)
                    }
                    HStack(spacing: 12) {
                        FooterPair(symbol: "↓", value: Fmt.rate(report?.network?.down))
                        FooterPair(symbol: "⇩", value: Fmt.bytes(report?.network?.totalDown))
                        Spacer(minLength: 4)
                        Text(remainingValue)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(KMTheme.muted)
                    }
                }

                if let stats = store.pings[node.uuid], !stats.isEmpty {
                    CarrierChips(stats: stats)
                    if let rate = LineRate.of(stats) {
                        LineRateBadge(rate: rate)
                            .padding(.top, 9)
                    }
                }
            }
        }
    }
}

struct TagText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(KMTheme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(KMTheme.inner)
            .clipShape(Capsule())
    }
}

struct FooterPair: View {
    let symbol: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(symbol == "↑" || symbol == "↓" ? KMTheme.ok : KMTheme.muted)
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(KMTheme.text)
        }
    }
}

// MARK: - 节点详情

struct NodeDetailView: View {
    @EnvironmentObject var store: Store
    let node: Node

    @State private var loadType = "cpu"
    @State private var hours = 24
    @State private var points: [RecordPoint] = []
    @State private var loading = false
    @State private var showAdmin = false

    private var report: Report? { store.reports[node.uuid] }
    private var isOnline: Bool { store.online.contains(node.uuid) }

    private var memPercent: Double {
        guard let r = report?.ram, let total = r.total, total > 0, let used = r.used else { return 0 }
        return Double(used) / Double(total) * 100
    }

    private var diskPercent: Double {
        guard let d = report?.disk, let total = d.total, total > 0, let used = d.used else { return 0 }
        return Double(used) / Double(total) * 100
    }

    private var limit: Int64? {
        guard let l = node.trafficLimit, l > 0 else { return nil }
        return l
    }

    private var trafficPercent: Double {
        guard let l = limit, let used = report?.trafficUsed else { return 0 }
        return Double(used) / Double(l) * 100
    }

    private var chartColor: Color {
        switch loadType {
        case "load": return KMTheme.net
        case "ram": return KMTheme.mem
        default: return KMTheme.cpu
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                metricGrid

                if let stats = store.pings[node.uuid], !stats.isEmpty {
                    KMCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                MonoLabel(text: "三网延迟", size: 9, weight: .semibold)
                                Spacer()
                                MonoLabel(text: "\(stats.count) CARRIERS", size: 8.5, color: KMTheme.dim)
                            }
                            PingTable(stats: stats, samples: store.pingSamples[node.uuid] ?? [:])
                        }
                    }
                }

                chartCard
                infoCard
            }
            .padding(16)
        }
        .background(Color.clear)
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdmin = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(KMTheme.muted)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdmin) {
            AdminSheet(node: node)
        }
        .task { await loadRecords() }
        .onChange(of: loadType) { _ in Task { await loadRecords() } }
        .onChange(of: hours) { _ in Task { await loadRecords() } }
    }

    private var header: some View {
        KMCard(padding: 15) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isOnline ? KMTheme.ok : KMTheme.bad)
                        .frame(width: 6, height: 6)
                    MonoLabel(text: isOnline ? "ONLINE" : "OFFLINE", size: 9, weight: .bold,
                              color: isOnline ? KMTheme.ok : KMTheme.bad)
                    Spacer()
                    MonoLabel(text: node.uuid.prefix(8).uppercased(), size: 8.5, color: KMTheme.dim)
                }

                Text(node.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(KMTheme.text)

                MonoLabel(text: "\(node.region ?? "") · \(node.os ?? "—") · \(node.virtualization ?? "") · \(node.cpuCores ?? 0)C",
                          size: 9.5, color: KMTheme.muted)

                KMHairline(opacity: 0.4)

                HStack {
                    MonoLabel(text: Fmt.priceText(node) ?? "—", size: 10, weight: .medium, color: KMTheme.text)
                    Spacer()
                    if let expiry = Fmt.expiryLabel(node.expiredAt) {
                        MonoLabel(text: expiry, size: 9,
                                  color: (Fmt.daysUntil(node.expiredAt) ?? 99) <= 7 ? KMTheme.bad : KMTheme.dim)
                    }
                }
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            DetailTile(label: "CPU", value: Fmt.percent(report?.cpu?.usage),
                       sub: node.cpuName ?? "", ratio: (report?.cpu?.usage ?? 0) / 100,
                       color: KMTheme.level(report?.cpu?.usage ?? 0, base: KMTheme.cpu))
            DetailTile(label: "MEM", value: Fmt.percent(memPercent),
                       sub: "\(Fmt.bytes(report?.ram?.used)) / \(Fmt.bytes(report?.ram?.total ?? node.memTotal))",
                       ratio: memPercent / 100, color: KMTheme.level(memPercent, base: KMTheme.mem))
            DetailTile(label: "DISK", value: Fmt.percent(diskPercent),
                       sub: "\(Fmt.bytes(report?.disk?.used)) / \(Fmt.bytes(report?.disk?.total ?? node.diskTotal))",
                       ratio: diskPercent / 100, color: KMTheme.level(diskPercent, base: KMTheme.disk))
            DetailTile(label: "LOAD", value: String(format: "%.2f", report?.load?.load1 ?? 0),
                       sub: String(format: "%.2f / %.2f", report?.load?.load5 ?? 0, report?.load?.load15 ?? 0),
                       ratio: min((report?.load?.load1 ?? 0) / max(Double(node.cpuCores ?? 1), 1), 1),
                       color: KMTheme.net)
            DetailTile(label: "NET ↓", value: Fmt.rate(report?.network?.down),
                       sub: "↑ \(Fmt.rate(report?.network?.up))",
                       ratio: 0, color: KMTheme.cpu, showBar: false)
            DetailTile(label: "TRAFFIC", value: limit == nil ? "∞" : String(format: "%.0f%%", trafficPercent),
                       sub: Fmt.trafficText(used: report?.trafficUsed, limit: node.trafficLimit),
                       ratio: trafficPercent / 100, color: KMTheme.level(trafficPercent, base: KMTheme.net),
                       showBar: limit != nil)
        }
    }

    private var chartCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MonoLabel(text: "HISTORY", size: 9, weight: .semibold)
                    Spacer()
                    MonoLabel(text: "\(loadType.uppercased()) · \(hours)H", size: 8.5, color: KMTheme.dim)
                }

                Picker("维度", selection: $loadType) {
                    Text("CPU").tag("cpu")
                    Text("LOAD").tag("load")
                    Text("MEM").tag("ram")
                }
                .pickerStyle(.segmented)

                Picker("范围", selection: $hours) {
                    Text("6H").tag(6)
                    Text("24H").tag(24)
                    Text("7D").tag(168)
                }
                .pickerStyle(.segmented)

                if loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 110).tint(KMTheme.accent)
                } else if points.isEmpty {
                    Text("NO DATA")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(KMTheme.dim)
                        .frame(maxWidth: .infinity, minHeight: 110)
                } else {
                    SparkArea(values: chartValues, color: chartColor).frame(height: 110)
                    HStack {
                        MonoLabel(text: String(format: "MIN %.1f", chartValues.min() ?? 0), size: 8.5, color: KMTheme.dim)
                        Spacer()
                        MonoLabel(text: String(format: "MAX %.1f", chartValues.max() ?? 0), size: 8.5, color: KMTheme.dim)
                        Spacer()
                        MonoLabel(text: "\(chartValues.count) PTS", size: 8.5, color: KMTheme.dim)
                    }
                }
            }
        }
    }

    private var chartValues: [Double] {
        points.map { p in
            switch loadType {
            case "load": return p.load ?? 0
            case "ram":
                if let pct = p.ramPercent { return pct }
                if let used = p.ram, let total = p.ramTotal, total > 0 { return Double(used) / Double(total) * 100 }
                return 0
            default: return p.cpu ?? 0
            }
        }
    }

    private var infoCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "SPECS", size: 9, weight: .semibold)

                infoRow("OS", node.os ?? "—")
                infoRow("ARCH", node.arch ?? "—")
                infoRow("VIRT", node.virtualization ?? "—")
                infoRow("CORES", "\(node.cpuCores ?? 0)")
                infoRow("MEM", Fmt.bytes(node.memTotal))
                infoRow("DISK", Fmt.bytes(node.diskTotal))
                infoRow("TRAFFIC", Fmt.trafficText(used: report?.trafficUsed, limit: node.trafficLimit))
                if let g = node.group, !g.isEmpty { infoRow("GROUP", g) }
            }
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MonoLabel(text: k, size: 9, weight: .semibold, color: KMTheme.dim)
            Spacer()
            Text(v)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(KMTheme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func loadRecords() async {
        loading = true
        points = await store.records(for: node.uuid, loadType: loadType, hours: hours)
        loading = false
    }
}

struct DetailTile: View {
    let label: String
    let value: String
    let sub: String
    let ratio: Double
    let color: Color
    var showBar: Bool = true

    var body: some View {
        KMCard(padding: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 5, height: 5)
                    MonoLabel(text: label, size: 8.5, weight: .semibold)
                }
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KMTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                MonoLabel(text: sub, size: 8.5, color: KMTheme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if showBar {
                    MicroBar(ratio: ratio, color: color).padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - 管理

struct AdminSheet: View {
    let node: Node
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("编辑").tag(0)
                    Text("命令").tag(1)
                    Text("日志").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(16)

                if tab == 0 {
                    NodeEditView(node: node)
                } else if tab == 1 {
                    CommandView(node: node)
                } else {
                    LogsView()
                }
            }
            .background(KMBackground())
            .navigationTitle("管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct NodeEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let node: Node

    @State private var name: String
    @State private var group: String
    @State private var price: String
    @State private var currency: String
    @State private var cycle: Int
    @State private var trafficGB: String
    @State private var hidden: Bool
    @State private var hasExpiry: Bool
    @State private var expiry: Date
    @State private var saving = false
    @State private var message: String?

    init(node: Node) {
        self.node = node
        _name = State(initialValue: node.name)
        _group = State(initialValue: node.group ?? "")
        _price = State(initialValue: node.price.map { Fmt.money($0) } ?? "")
        _currency = State(initialValue: node.currency ?? "$")
        _cycle = State(initialValue: node.billingCycle ?? 30)
        _trafficGB = State(initialValue: {
            guard let t = node.trafficLimit, t > 0 else { return "" }
            return String(format: "%.0f", Double(t) / 1073741824)
        }())
        _hidden = State(initialValue: node.hidden ?? false)
        let date = Fmt.dateOnly(node.expiredAt).flatMap { text -> Date? in
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.date(from: text)
        }
        _hasExpiry = State(initialValue: date != nil)
        _expiry = State(initialValue: date ?? Date())
    }

    var body: some View {
        Form {
            Section("基础") {
                TextField("名称", text: $name)
                TextField("分组", text: $group)
                Toggle("隐藏节点", isOn: $hidden)
            }
            Section("计费") {
                HStack {
                    TextField("价格", text: $price).keyboardType(.decimalPad)
                    TextField("货币", text: $currency).frame(width: 60)
                }
                Picker("周期", selection: $cycle) {
                    Text("月付").tag(30)
                    Text("季付").tag(90)
                    Text("半年").tag(180)
                    Text("年付").tag(365)
                }
                Toggle("设置到期时间", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("到期", selection: $expiry, displayedComponents: .date)
                }
            }
            Section("流量") {
                TextField("流量上限（GB，0 为不限）", text: $trafficGB)
                    .keyboardType(.numberPad)
            }
            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(KMTheme.bad) }
            }
            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if saving {
                            ProgressView()
                        } else {
                            Text("保存").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(saving)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func save() async {
        saving = true
        message = nil
        defer { saving = false }

        var fields: [String: Any] = [
            "name": name,
            "group": group,
            "price": Double(price) ?? 0,
            "currency": currency.isEmpty ? "$" : currency,
            "billing_cycle": cycle,
            "hidden": hidden,
        ]

        let gb = Double(trafficGB) ?? 0
        fields["traffic_limit"] = Int64(gb * 1073741824)

        if hasExpiry {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            fields["expired_at"] = f.string(from: expiry)
        } else {
            fields["expired_at"] = NSNull()
        }

        if let err = await store.saveNode(uuid: node.uuid, fields: fields) {
            message = err
        } else {
            dismiss()
        }
    }
}

struct CommandView: View {
    @EnvironmentObject var store: Store
    let node: Node

    @State private var command = "uptime"
    @State private var twoFA = ""
    @State private var running = false
    @State private var output: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section("在 \(node.name) 上执行") {
                TextField("命令", text: $command, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3...5)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("2FA 验证码（如面板开启）", text: $twoFA)
                    .keyboardType(.numberPad)
            }

            Section {
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        Spacer()
                        if running {
                            ProgressView()
                        } else {
                            Text("执行").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(running || command.isEmpty)
            }

            if let error {
                Section { Text(error).font(.footnote).foregroundStyle(KMTheme.bad) }
            }
            if let output {
                Section("输出") {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func run() async {
        running = true
        error = nil
        output = nil
        defer { running = false }

        let (resp, err) = await store.runCommand(command, nodeUUID: node.uuid, twoFA: twoFA)
        if let err {
            error = err
            return
        }
        guard let taskID = resp?.taskID else {
            error = "未拿到 task id"
            return
        }

        for _ in 0..<8 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let results = await store.taskResults(taskID)
            if let r = results.first(where: { $0.client == node.uuid }) ?? results.first {
                output = (r.result ?? "") + (r.exitCode.map { "\n\nexit \($0)" } ?? "")
                if r.finishedAt != nil { break }
            }
        }
        if output == nil {
            output = "任务已下发，暂无输出（agent 可能离线或仍在执行）"
        }
    }
}

struct LogsView: View {
    @EnvironmentObject var store: Store
    @State private var logs: [AdminLog] = []
    @State private var loading = false

    var body: some View {
        List {
            ForEach(logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.message ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(KMTheme.text)
                    HStack(spacing: 8) {
                        MonoLabel(text: shortTime(log.time), size: 8.5, color: KMTheme.dim)
                        MonoLabel(text: (log.msgType ?? "").uppercased(), size: 8.5,
                                  color: color(log.msgType))
                        MonoLabel(text: log.ip ?? "", size: 8.5, color: KMTheme.dim)
                    }
                }
                .listRowBackground(KMTheme.card)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay { if loading && logs.isEmpty { ProgressView().tint(KMTheme.accent) } }
        .task {
            loading = true
            logs = await store.adminLogs()
            loading = false
        }
    }

    private func color(_ type: String?) -> Color {
        switch type {
        case "warn": return KMTheme.warn
        case "error": return KMTheme.bad
        default: return KMTheme.muted
        }
    }

    private func shortTime(_ iso: String?) -> String {
        guard let iso else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = f.date(from: iso)
        if date == nil {
            f.formatOptions = [.withInternetDateTime]
            date = f.date(from: iso)
        }
        guard let date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MM-dd HH:mm"
        return out.string(from: date)
    }
}

// MARK: - 设置

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("当前面板") {
                    LabeledContent("地址", value: store.host)
                    LabeledContent("账号", value: store.username)
                    LabeledContent("权限", value: store.isAdmin ? "管理员" : "普通用户")
                }
                Section("外观") {
                    Picker("主题", selection: Binding(
                        get: { store.themeMode },
                        set: { store.setTheme($0) }
                    )) {
                        Text("跟随系统").tag("system")
                        Text("深色").tag("dark")
                        Text("浅色").tag("light")
                    }
                    .pickerStyle(.segmented)
                }
                Section("汇总统计") {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                        spacing: 9
                    ) {
                        ForEach(summaryCards) { card in
                            SummaryCellView(title: card.title, value: card.value, icon: card.icon)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Button("退出登录", role: .destructive) {
                        store.logout()
                        dismiss()
                    }
                }
                Section {
                    Text("数据直连你自己的 Komari 面板，不经过任何第三方服务器。")
                        .font(.footnote)
                        .foregroundStyle(KMTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 全局汇总卡片
    private struct SummaryCard: Identifiable {
        let title: String
        let value: String
        let icon: String
        var id: String { title }
    }

    /// 全局汇总：内存 / 硬盘 / 剩余价值 / 累计流量 / 实时速率
    private var summaryCards: [SummaryCard] {
        let reps = Array(store.reports.values)
        let memUsed = reps.compactMap { $0.ram?.used }.reduce(0, +)
        let memTotal = reps.compactMap { $0.ram?.total }.reduce(0, +)
        let diskUsed = reps.compactMap { $0.disk?.used }.reduce(0, +)
        let diskTotal = reps.compactMap { $0.disk?.total }.reduce(0, +)
        let traffic = reps.compactMap { r in
            (r.network?.totalUp ?? 0) + (r.network?.totalDown ?? 0)
        }.reduce(0, +)
        let value = store.nodes.reduce(0.0) { sum, n in
            guard let price = n.price, price > 0, let d = Fmt.daysUntil(n.expiredAt) else { return sum }
            let cycle = Double(n.billingCycle ?? 365)
            return sum + price * Double(max(d, 0)) / max(cycle, 1)
        }
        let currency = store.nodes.first(where: { ($0.price ?? 0) > 0 })?.currency ?? "¥"
        let noSpace = { (s: String) in s.replacingOccurrences(of: " ", with: "") }

        return [
            SummaryCard(title: "内存用量", value: "\(noSpace(Fmt.bytes(memUsed))) / \(noSpace(Fmt.bytes(memTotal)))", icon: "memorychip"),
            SummaryCard(title: "硬盘用量", value: "\(noSpace(Fmt.bytes(diskUsed))) / \(noSpace(Fmt.bytes(diskTotal)))", icon: "internaldrive"),
            SummaryCard(title: "剩余价值", value: "\(currency)\(Fmt.money(value))", icon: "yensign.circle"),
            SummaryCard(title: "累计流量", value: Fmt.bytes(traffic), icon: "arrow.up.arrow.down"),
            SummaryCard(title: "实时上行", value: Fmt.rate(store.liveUp), icon: "arrow.up"),
            SummaryCard(title: "实时下行", value: Fmt.rate(store.liveDown), icon: "arrow.down")
        ]
    }
}


// MARK: - 服务器列表

struct ServerListSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showLogin = false
    @State private var editing: Server?

    var body: some View {
        NavigationStack {
            List {
                Section("服务器") {
                    ForEach(store.servers) { s in
                        Button {
                            Task {
                                await store.switchTo(s.id)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(color(s))
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.alias)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(KMTheme.text)
                                        .lineLimit(1)
                                    Text(s.host)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(KMTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 6)
                                Text(statusText(s))
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(color(s))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await store.deleteServer(s.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                editing = s
                                showLogin = true
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(KMTheme.accent)
                        }
                    }
                }
                Section {
                    Button {
                        editing = nil
                        showLogin = true
                    } label: {
                        Label("添加服务器", systemImage: "plus")
                            .foregroundStyle(KMTheme.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KMTheme.bgTop)
            .navigationTitle("服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView(editing: editing, onCancel: { showLogin = false }, onDone: {
                    showLogin = false
                    dismiss()
                })
                .environmentObject(store)
            }
        }
    }

    private func color(_ s: Server) -> Color {
        guard let valid = store.sessionValid[s.id] else { return KMTheme.dim }
        return valid ? KMTheme.ok : KMTheme.bad
    }

    private func statusText(_ s: Server) -> String {
        guard let valid = store.sessionValid[s.id] else { return "未检测" }
        return valid ? "会话有效" : "会话已失效"
    }
}
