import SwiftUI

enum IFMTheme {
    static let canvas = Color(red: 0.985, green: 0.987, blue: 0.982)
    static let panel = Color.white.opacity(0.96)
    static let panelStrong = Color.white
    static let softPanel = Color(red: 0.965, green: 0.982, blue: 0.973)
    static let border = Color(red: 0.875, green: 0.895, blue: 0.888)
    static let hairline = Color(red: 0.925, green: 0.935, blue: 0.930)
    static let text = Color(red: 0.055, green: 0.078, blue: 0.118)
    static let muted = Color(red: 0.405, green: 0.455, blue: 0.535)
    static let green = Color(red: 0.02, green: 0.62, blue: 0.39)
    static let blue = Color(red: 0.12, green: 0.46, blue: 0.86)
    static let orange = Color(red: 0.95, green: 0.52, blue: 0.04)
    static let red = Color(red: 0.96, green: 0.24, blue: 0.22)
    static let purple = Color(red: 0.50, green: 0.28, blue: 0.82)
    static let slate = Color(red: 0.39, green: 0.45, blue: 0.53)
    static let gray = Color(red: 0.46, green: 0.50, blue: 0.57)
}

struct IFMCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(IFMTheme.panelStrong)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(IFMTheme.border.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.030), radius: 16, y: 7)
    }
}

struct Pill: View {
    var text: String
    var color: Color = IFMTheme.green

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minHeight: 21)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(color.opacity(0.16), lineWidth: 1) }
    }
}

struct SymbolBadge: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.18), lineWidth: 1) }
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

struct MiniProgress: View {
    var value: Double
    var color: Color = IFMTheme.green

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.075))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 6)
    }
}

struct Sparkline: View {
    var color: Color
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard let first = values.first else { return }
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = max(0.01, maxValue - minValue)
                func point(_ index: Int, _ value: Double) -> CGPoint {
                    CGPoint(
                        x: proxy.size.width * CGFloat(index) / CGFloat(max(1, values.count - 1)),
                        y: proxy.size.height - proxy.size.height * CGFloat((value - minValue) / range)
                    )
                }
                path.move(to: point(0, first))
                for (index, value) in values.enumerated().dropFirst() {
                    path.addLine(to: point(index, value))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 28)
    }
}
