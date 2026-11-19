import SwiftUI

// MARK: - 三网延迟胶囊（固定三栏：电信 / 联通 / 移动）

struct CarrierChips: View {
    let stats: [PingStat]

    /// 固定三栏：电信 / 联通 / 移动，缺失的用 nil 占位
    private var slots: [Slot] {
        LineRate.threeCarriers(stats).enumerated().map { idx, pair in
            Slot(id: idx, carrier: pair.0, ping: pair.1)
        }
    }

    struct Slot: Identifiable {
        let id: Int
        let carrier: String
        let ping: PingStat?
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(slots) { slot in
                if let p = slot.ping {
                    Chip(ping: p)
                } else {
                    EmptyChip(carrier: slot.carrier)
                }
            }
        }
    }
}

/// 有数据的运营商胶囊
private struct Chip: View {
    let ping: PingStat

    private var ms: Int? {
        guard let avg = ping.avg, avg > 0 else { return nil }
        return Int(avg.rounded())
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(LineRate.carrierName(ping.name))
                .font(.system(size: 9))
                .foregroundStyle(KMTheme.dim)
                .lineLimit(1)
            HStack(spacing: 2) {
                if let ms {
                    Text("\(ms)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(KMTheme.latency(ms: ms, loss: ping.loss))
                    Text("ms")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(KMTheme.dim)
                } else {
                    Text("—")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(KMTheme.dim)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(KMTheme.inner)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// 缺测运营商的占位胶囊
private struct EmptyChip: View {
    let carrier: String

    var body: some View {
        VStack(spacing: 2) {
            Text(carrier)
                .font(.system(size: 9))
                .foregroundStyle(KMTheme.dim.opacity(0.7))
                .lineLimit(1)
            Text("—")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KMTheme.dim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(KMTheme.inner.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - 线路评级徽章

struct LineRateBadge: View {
    let rate: LineRate.Result

    private var detail: String {
        var s = "三网均值 \(rate.meanMs)ms"
        if rate.lossPct > 0 {
            s += " · 丢包 \(trimZero(rate.lossPct))%"
        }
        if rate.covered < 3 {
            s += " · 仅\(rate.covered)网"
        }
        return s
    }

    var body: some View {
        HStack(spacing: 7) {
            Text("线路评级")
                .font(.system(size: 9.5))
                .foregroundStyle(KMTheme.dim)
            HStack(spacing: 5) {
                Circle()
                    .fill(rate.color)
                    .frame(width: 6, height: 6)
                Text("\(rate.name) \(rate.score)")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(rate.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(rate.bg)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Spacer(minLength: 6)
            Text(detail)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(KMTheme.dim)
                .lineLimit(1)
        }
    }
}

/// 去掉小数末尾多余的 0（1.6 → 1.6，1.0 → 1）
private func trimZero(_ v: Double) -> String {
    if v == v.rounded() && !v.isInfinite { return String(Int(v)) }
    return String(format: "%.1f", v)
}
