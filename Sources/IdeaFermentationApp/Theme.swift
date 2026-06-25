import AppKit
import SwiftUI

// MARK: - Adaptive color resolution

/// Builds a SwiftUI `Color` that resolves to a different value in light vs dark
/// appearance. Wrapping an `NSColor(name:dynamicProvider:)` keeps the color
/// dynamic all the way through SwiftUI, so a single token re-resolves itself when
/// the system appearance flips — no environment threading and no per-view
/// branching required.
@inline(__always)
private func ifmAdaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let rgb = isDark ? dark : light
        return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    })
}

/// The semantic color palette. Light values are byte-identical to v1; dark values
/// are hand-tuned companions so the whole UI adapts to the system appearance
/// through these tokens alone.
enum IFMTheme {
    // Surfaces
    static let canvas = ifmAdaptive(light: (0.985, 0.987, 0.982), dark: (0.073, 0.082, 0.099))
    static let panel = ifmAdaptive(light: (1, 1, 1), dark: (0.118, 0.129, 0.152)).opacity(0.96)
    static let panelStrong = ifmAdaptive(light: (1, 1, 1), dark: (0.130, 0.142, 0.166))
    static let softPanel = ifmAdaptive(light: (0.965, 0.982, 0.973), dark: (0.110, 0.140, 0.128))

    // Lines
    static let border = ifmAdaptive(light: (0.875, 0.895, 0.888), dark: (0.270, 0.292, 0.330))
    static let hairline = ifmAdaptive(light: (0.925, 0.935, 0.930), dark: (0.205, 0.223, 0.255))

    // Text
    static let text = ifmAdaptive(light: (0.055, 0.078, 0.118), dark: (0.918, 0.936, 0.960))
    static let muted = ifmAdaptive(light: (0.405, 0.455, 0.535), dark: (0.620, 0.662, 0.730))

    // Accents — brightened slightly in dark so they keep their punch on a dark canvas.
    static let green = ifmAdaptive(light: (0.02, 0.62, 0.39), dark: (0.22, 0.82, 0.56))
    static let blue = ifmAdaptive(light: (0.12, 0.46, 0.86), dark: (0.38, 0.63, 0.99))
    static let orange = ifmAdaptive(light: (0.95, 0.52, 0.04), dark: (0.99, 0.64, 0.22))
    static let red = ifmAdaptive(light: (0.96, 0.24, 0.22), dark: (0.99, 0.44, 0.42))
    static let purple = ifmAdaptive(light: (0.50, 0.28, 0.82), dark: (0.69, 0.51, 0.97))
    static let slate = ifmAdaptive(light: (0.39, 0.45, 0.53), dark: (0.605, 0.665, 0.745))
    static let gray = ifmAdaptive(light: (0.46, 0.50, 0.57), dark: (0.620, 0.660, 0.725))

    /// A neutral overlay tint for hover backgrounds, progress tracks, empty dots,
    /// and faint section fills. Black in light mode, white in dark mode — so every
    /// `.opacity(...)` applied to it reads as a *subtle* lift in either appearance
    /// instead of the glaring white slab a literal `Color.black.opacity` becomes on
    /// a dark surface.
    static let scrim = ifmAdaptive(light: (0, 0, 0), dark: (1, 1, 1))

    /// Foreground for content sitting on a saturated accent fill (e.g. the selected
    /// segment of a switch). Near-white in both appearances.
    static let onAccent = Color.white

    /// All semantic tokens, used by guardrail tests to assert every token resolves
    /// in both appearances. Keyed by name for readable failures.
    static let allTokens: [(name: String, color: Color)] = [
        ("canvas", canvas), ("panel", panel), ("panelStrong", panelStrong), ("softPanel", softPanel),
        ("border", border), ("hairline", hairline), ("text", text), ("muted", muted),
        ("green", green), ("blue", blue), ("orange", orange), ("red", red),
        ("purple", purple), ("slate", slate), ("gray", gray), ("scrim", scrim), ("onAccent", onAccent)
    ]
}

// MARK: - Metric tokens

/// Corner-radius scale. `md` carries the value (8) that was hardcoded ~45× across
/// the views, so adopting it is visually identical while making the radius a single
/// source of truth.
enum IFMRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let pill: CGFloat = 999
}

/// Spacing scale, matching the paddings already chosen ad-hoc throughout the app.
enum IFMSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 14
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

/// Motion tokens. Centralizing them means a single place honors Reduce Motion and
/// keeps timing consistent across animated values (rings, bars, metrics).
enum IFMMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let standard = Animation.easeInOut(duration: 0.28)
    static let gentle = Animation.easeInOut(duration: 0.45)
    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.82)
}

// MARK: - Typography ramp

/// A small semantic type ramp folding the most-repeated `.system(size:weight:)`
/// pairings into named styles. Values match what the views already use.
extension Font {
    static let ifmDisplay = Font.system(size: 26, weight: .bold)
    static let ifmTitle = Font.system(size: 20, weight: .bold)
    static let ifmSectionTitle = Font.system(size: 18, weight: .semibold)
    static let ifmCardTitle = Font.system(size: 15, weight: .semibold)
    static let ifmRowTitle = Font.system(size: 13, weight: .semibold)
    static let ifmBody = Font.system(size: 13)
    static let ifmMetric = Font.system(size: 28, weight: .bold)
}

// MARK: - Elevation

extension View {
    /// The standard resting card shadow (was an inline `radius: 16, y: 7`).
    func ifmCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.030), radius: 16, y: 7)
    }

    /// A lighter shadow for tappable tiles (was an inline `radius: 8, y: 3`).
    func ifmTileShadow() -> some View {
        shadow(color: Color.black.opacity(0.018), radius: 8, y: 3)
    }

    /// The clip + hairline-stroke "container" idiom repeated across list and card
    /// edges, folded into one modifier on the radius token.
    func ifmContainer(radius: CGFloat = IFMRadius.md, stroke: Color = IFMTheme.border) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke) }
    }
}

// MARK: - Interaction

/// A subtle hover lift for `.plain` buttons and tappable tiles. macOS users expect
/// interactive surfaces to react to the pointer; v1 surfaces were inert.
struct IFMHoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = IFMRadius.md
    var restingOpacity: Double = 0
    var hoverOpacity: Double = 0.06
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(IFMTheme.scrim.opacity(hovering ? hoverOpacity : restingOpacity))
            )
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : IFMMotion.quick, value: hovering)
    }
}

/// A button style that gives a gentle press-down and hover feedback while leaving
/// layout untouched — safe to apply to any existing `.plain`-styled button.
struct IFMPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : IFMMotion.quick, value: configuration.isPressed)
    }
}

extension View {
    func ifmHover(cornerRadius: CGFloat = IFMRadius.md, restingOpacity: Double = 0, hoverOpacity: Double = 0.06) -> some View {
        modifier(IFMHoverHighlight(cornerRadius: cornerRadius, restingOpacity: restingOpacity, hoverOpacity: hoverOpacity))
    }
}

// MARK: - Display helpers

/// Human-friendly casing for a learned/derived theme term. Terms are stored
/// lowercased for matching, so this is display-only: it upper-cases known acronyms
/// (NFT, HR, AI…), fixes a few mixed-case product names (iOS, macOS, GitHub), and
/// title-cases everything else — so "nft projects" reads "NFT Projects", not
/// "Nft Projects".
func ifmDisplayTerm(_ term: String) -> String {
    let acronyms: Set<String> = [
        "ai", "api", "ui", "ux", "ml", "llm", "gpt", "nft", "hr", "crm", "saas",
        "sdk", "css", "html", "sql", "kpi", "roi", "mvp", "b2b", "b2c", "ar", "vr",
        "ocr", "pdf", "url", "rss", "cli", "gui", "iot", "qr", "ip", "os"
    ]
    let mixed: [String: String] = [
        "ios": "iOS", "macos": "macOS", "tvos": "tvOS", "watchos": "watchOS",
        "github": "GitHub", "openai": "OpenAI", "tiktok": "TikTok", "youtube": "YouTube",
        "iphone": "iPhone", "ipad": "iPad", "javascript": "JavaScript"
    ]
    return term.split(separator: " ").map { raw -> String in
        let word = String(raw)
        let lower = word.lowercased()
        if let m = mixed[lower] { return m }
        if acronyms.contains(lower) { return word.uppercased() }
        return word.prefix(1).uppercased() + word.dropFirst()
    }.joined(separator: " ")
}

// MARK: - Core components

struct IFMCard<Content: View>: View {
    var padding: CGFloat = IFMSpacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(IFMTheme.panelStrong)
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous)
                    .stroke(IFMTheme.border.opacity(0.72), lineWidth: 1)
            }
            .ifmCardShadow()
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
            RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(color.opacity(0.18), lineWidth: 1) }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(IFMTheme.scrim.opacity(0.075))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.82), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : IFMMotion.standard, value: value)
    }
}

struct Sparkline: View {
    var color: Color
    var values: [Double]
    /// A faint gradient area under the line. On by default — a tasteful v2 lift that
    /// applies everywhere sparklines are used.
    var filled: Bool = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if filled, values.count > 1 {
                    areaPath(in: proxy.size)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.22), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                }
                linePath(in: proxy.size)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 28)
    }

    private func point(_ index: Int, _ value: Double, _ size: CGSize) -> CGPoint {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(0.01, maxValue - minValue)
        return CGPoint(
            x: size.width * CGFloat(index) / CGFloat(max(1, values.count - 1)),
            y: size.height - size.height * CGFloat((value - minValue) / range)
        )
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard let first = values.first else { return }
            path.move(to: point(0, first, size))
            for (index, value) in values.enumerated().dropFirst() {
                path.addLine(to: point(index, value, size))
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard let first = values.first else { return }
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: point(0, first, size))
            for (index, value) in values.enumerated().dropFirst() {
                path.addLine(to: point(index, value, size))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}
