import IdeaFermentationCore
import SwiftUI

enum PatternLayout {
    static let minimumInlineHeaderWidth: CGFloat = 460

    static func shouldStackDNAHeader(width: CGFloat) -> Bool {
        width < minimumInlineHeaderWidth
    }
}

struct PatternsPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var range: PatternTimeRange = .ninety
    @State private var displayMode: PatternDisplayMode = .map

    var body: some View {
        let analytics = PatternAnalytics(
            ideas: model.ideas,
            sources: model.sources,
            logs: model.logs,
            connections: model.connections,
            days: range.rawValue
        )

        PageScaffold(title: "Patterns", subtitle: "Recurring themes, loops, and connections across all your ideas and sources.", symbol: nil, accent: IFMTheme.green) {
            VStack(spacing: 14) {
                PortfolioIntelligenceCard(model: model)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        PatternRangeMenu(range: $range)
                        PatternExportButton(isEnabled: analytics.hasData) {
                            model.exportPatternReport(analytics.markdownReport())
                        }
                    }

                    HStack(spacing: 10) {
                        PatternRangeMenu(range: $range)
                        PatternExportButton(isEnabled: analytics.hasData) {
                            model.exportPatternReport(analytics.markdownReport())
                        }
                        Spacer(minLength: 0)
                    }
                }

                PatternDNACard(analytics: analytics, displayMode: $displayMode) {
                    model.startIdeaCapture()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .top)], spacing: 12) {
                    PatternRowsCard(title: "Rising Themes", subtitle: "Theme", rows: analytics.themes.prefix(5).map {
                        PatternAnalytics.Row(title: $0.name.capitalized, detail: "\($0.ideaCount) ideas, \($0.sourceCount) sources", value: PatternAnalytics.momentumText($0.momentum), score: min(1, max(0, $0.momentum)))
                    }, emptyText: "No rising themes yet.")
                    PatternRowsCard(title: "Overused Loops", subtitle: "Loop", rows: analytics.loops, emptyText: "No repeated loops yet.")
                    PatternRowsCard(title: "Unusual Combinations", subtitle: "Combination", rows: analytics.combinations, emptyText: "No unusual combinations yet.")
                    PatternRowsCard(title: "Blind Spots", subtitle: "Area", rows: analytics.blindSpots, emptyText: "No blind spots detected yet.")
                }

                PatternMomentumCard(analytics: analytics)
            }
        } rail: {
            PatternRail(analytics: analytics) {
                model.startIdeaCapture()
            }
        }
    }
}

private enum PatternTimeRange: Int, CaseIterable, Identifiable {
    case thirty = 30
    case ninety = 90
    case year = 365

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .thirty: "Last 30 Days"
        case .ninety: "Last 90 Days"
        case .year: "Last Year"
        }
    }
}

private enum PatternDisplayMode: String, CaseIterable, Identifiable {
    case map = "Map"
    case timeline = "Timeline"
    var id: String { rawValue }
}

private struct PatternRangeMenu: View {
    @Binding var range: PatternTimeRange

    var body: some View {
        Menu {
            ForEach(PatternTimeRange.allCases) { item in
                Button(item.title) { range = item }
            }
        } label: {
            Label(range.title, systemImage: "calendar")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
    }
}

private struct PatternExportButton: View {
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Export", systemImage: "square.and.arrow.down")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
    }
}

private struct PatternDNACard: View {
    var analytics: PatternAnalytics
    @Binding var displayMode: PatternDisplayMode
    var addIdea: () -> Void

    var body: some View {
        IFMCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                header

                if analytics.themes.isEmpty {
                    PatternInlineEmptyState(title: "No pattern map yet", message: "Add ideas or sources, then run a local fermentation pass. This map stays empty until there is real material to compare.", action: addIdea)
                        .frame(minHeight: 300)
                } else if displayMode == .map {
                    PatternClusterMap(themes: Array(analytics.themes.prefix(7)))
                        .frame(minHeight: 300)
                } else {
                    PatternTimelineList(themes: Array(analytics.themes.prefix(6)))
                        .frame(minHeight: 300)
                }
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                headerText
                    .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
                PatternModeSwitch(selection: $displayMode)
            }
            .frame(minWidth: PatternLayout.minimumInlineHeaderWidth, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                headerText
                PatternModeSwitch(selection: $displayMode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recurring Idea DNA")
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text("Semantic clusters from your real ideas and sources.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .lineLimit(2)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PatternModeSwitch: View {
    @Binding var selection: PatternDisplayMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PatternDisplayMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 78, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode ? IFMTheme.onAccent : IFMTheme.text)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selection == mode ? IFMTheme.green : Color.clear)
                }
                .accessibilityLabel(mode.rawValue)
                .accessibilityValue(selection == mode ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(3)
        .background(IFMTheme.scrim.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(IFMTheme.border.opacity(0.65), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern view")
    }
}

private struct PatternClusterMap: View {
    var themes: [PatternAnalytics.Theme]

    var body: some View {
        GeometryReader { proxy in
            let showLegend = proxy.size.width >= 720
            let center = CGPoint(x: proxy.size.width * (showLegend ? 0.46 : 0.50), y: proxy.size.height * 0.52)
            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    Ellipse()
                        .stroke(IFMTheme.border.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        .frame(width: CGFloat(ring) * proxy.size.width * 0.22, height: CGFloat(ring) * proxy.size.height * 0.18)
                        .position(center)
                }

                ForEach(Array(themes.enumerated()), id: \.element.id) { index, theme in
                    let position = point(index: index, total: themes.count, size: proxy.size)
                    Path { path in
                        path.move(to: center)
                        path.addQuadCurve(to: position, control: CGPoint(x: (center.x + position.x) / 2, y: min(center.y, position.y) - 34))
                    }
                    .stroke(color(index).opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                SymbolBadge(symbol: "point.3.connected.trianglepath.dotted", color: IFMTheme.green, size: 64)
                    .position(center)

                ForEach(Array(themes.enumerated()), id: \.element.id) { index, theme in
                    let position = point(index: index, total: themes.count, size: proxy.size)
                    HStack(spacing: 8) {
                        SymbolBadge(symbol: symbol(index), color: color(index), size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.name.capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(color(index))
                                .lineLimit(1)
                            Text("\(theme.count) signals")
                                .font(.caption2)
                                .foregroundStyle(IFMTheme.muted)
                        }
                    }
                    .frame(width: proxy.size.width < 640 ? 132 : 156, alignment: .leading)
                    .padding(8)
                    .background(IFMTheme.panelStrong.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.85)) }
                    .position(position)
                }

                if showLegend {
                    PatternMapLegend(themes: themes)
                        .frame(width: 180)
                        .position(x: proxy.size.width - 100, y: proxy.size.height * 0.50)
                }
            }
        }
    }

    private func point(index: Int, total: Int, size: CGSize) -> CGPoint {
        let angle = (Double(index) / Double(max(1, total)) * Double.pi * 2) - Double.pi / 2
        let rx = size.width * (size.width >= 720 ? 0.28 : 0.34)
        let ry = size.height * 0.30
        let centerX = size.width * (size.width >= 720 ? 0.46 : 0.50)
        return CGPoint(x: centerX + cos(angle) * rx, y: size.height * 0.52 + sin(angle) * ry)
    }
}

private struct PatternInlineEmptyState: View {
    var title: String
    var message: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.grid.3x3")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(IFMTheme.green)
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Text(message)
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button("Add Idea", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(IFMTheme.softPanel)
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.8)) }
    }
}

private struct PatternMapLegend: View {
    var themes: [PatternAnalytics.Theme]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Cluster Strength").font(.caption.bold())
            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < min(6, themes.count) ? IFMTheme.green : IFMTheme.border)
                        .frame(width: 9, height: 9)
                }
            }
            Text("Ideas in cluster").font(.caption2).foregroundStyle(IFMTheme.muted)
            HStack(spacing: 8) {
                ForEach([1, 2, 3, 4], id: \.self) { size in
                    Circle()
                        .fill(IFMTheme.slate.opacity(0.18))
                        .frame(width: CGFloat(10 + size * 4), height: CGFloat(10 + size * 4))
                }
            }
        }
        .padding(10)
        .background(IFMTheme.panelStrong.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.85)) }
    }
}

private struct PatternTimelineList: View {
    var themes: [PatternAnalytics.Theme]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(themes.enumerated()), id: \.element.id) { index, theme in
                HStack(spacing: 12) {
                    SymbolBadge(symbol: symbol(index), color: color(index), size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(theme.name.capitalized).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(PatternAnalytics.momentumText(theme.momentum))
                                .font(.caption.bold())
                                .foregroundStyle(theme.momentum >= 0 ? IFMTheme.green : IFMTheme.red)
                        }
                        Sparkline(color: color(index), values: theme.trend)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PatternRowsCard: View {
    var title: String
    var subtitle: String
    var rows: [PatternAnalytics.Row]
    var emptyText: String

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundStyle(IFMTheme.muted)
                        .font(.caption)
                }
                HStack {
                    Text(subtitle)
                        .lineLimit(1)
                    Spacer()
                    Text("Signal")
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(IFMTheme.muted)

                if rows.isEmpty {
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .center)
                } else {
                    ForEach(rows.prefix(5)) { row in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text(row.detail)
                                    .font(.caption2)
                                    .foregroundStyle(IFMTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(row.value)
                                .font(.caption.bold())
                                .foregroundStyle(row.score > 0.75 ? IFMTheme.green : row.score > 0.45 ? IFMTheme.orange : IFMTheme.slate)
                        }
                        Divider().opacity(0.45)
                    }
                }
            }
            .frame(minHeight: 190, alignment: .top)
        }
    }
}

private struct PatternMomentumCard: View {
    var analytics: PatternAnalytics

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Theme Momentum Timeline")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("Top themes across the selected time range.")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Pill(text: "Weekly", color: IFMTheme.slate)
                }

                if analytics.themes.isEmpty {
                    Text("Momentum appears after themes repeat across your ideas or sources.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                } else {
                    PatternMultiLineChart(themes: Array(analytics.themes.prefix(5)))
                        .frame(height: 150)
                    HStack(spacing: 12) {
                        ForEach(Array(analytics.themes.prefix(5).enumerated()), id: \.element.id) { index, theme in
                            HStack(spacing: 5) {
                                Circle().fill(color(index)).frame(width: 7, height: 7)
                                Text(theme.name.capitalized).font(.caption2).foregroundStyle(IFMTheme.muted).lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PatternMultiLineChart: View {
    var themes: [PatternAnalytics.Theme]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                VStack {
                    Divider().opacity(0.35)
                    Spacer()
                    Divider().opacity(0.35)
                    Spacer()
                    Divider().opacity(0.35)
                }
                ForEach(Array(themes.enumerated()), id: \.element.id) { index, theme in
                    trendPath(values: theme.trend, size: proxy.size)
                        .stroke(color(index), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func trendPath(values: [Double], size: CGSize) -> Path {
        Path { path in
            guard let first = values.first else { return }
            let maxValue = max(1, values.max() ?? 1)
            func point(_ index: Int, _ value: Double) -> CGPoint {
                CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(max(1, values.count - 1)),
                    y: size.height - size.height * CGFloat(value / maxValue)
                )
            }
            path.move(to: point(0, first))
            for (index, value) in values.enumerated().dropFirst() {
                path.addLine(to: point(index, value))
            }
        }
    }
}

private struct PatternRail: View {
    var analytics: PatternAnalytics
    var addIdea: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PatternAlertsCard(analytics: analytics, addIdea: addIdea)
            PatternFingerprintCard(fingerprint: analytics.fingerprint)
            PatternStatsCard(analytics: analytics)
        }
    }
}

private struct PatternAlertsCard: View {
    var analytics: PatternAnalytics
    var addIdea: () -> Void

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Pattern Alerts", systemImage: "bell")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Pill(text: "\(analytics.alerts.count)", color: IFMTheme.slate)
                }
                if analytics.alerts.isEmpty {
                    Text("No alerts yet. Add more material or run fermentation to surface real changes.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Button("Add Idea", action: addIdea)
                        .buttonStyle(.bordered)
                } else {
                    ForEach(Array(analytics.alerts.enumerated()), id: \.element.id) { index, alert in
                        HStack(alignment: .top, spacing: 10) {
                            SymbolBadge(symbol: symbol(index), color: color(index), size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(alert.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(2)
                                Text(alert.detail)
                                    .font(.caption2)
                                    .foregroundStyle(IFMTheme.muted)
                                    .lineLimit(2)
                            }
                        }
                        Divider().opacity(0.45)
                    }
                }
            }
        }
    }
}

private struct PatternFingerprintCard: View {
    var fingerprint: PatternAnalytics.Fingerprint

    var body: some View {
        IFMCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Your Creative Fingerprint")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(IFMTheme.muted)
                }
                PatternRadarChart(values: [
                    fingerprint.integration,
                    fingerprint.originality,
                    fingerprint.technicalLean,
                    fingerprint.executionBias,
                    fingerprint.humanImpact,
                    fingerprint.curiosity
                ])
                .frame(height: 172)
                Text("This reflects only local app data.")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }
}

private struct PatternRadarChart: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.38
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    polygon(values: Array(repeating: Double(ring) / 4, count: values.count), center: center, radius: radius)
                        .stroke(IFMTheme.border.opacity(0.8), lineWidth: 1)
                }
                ForEach(0..<values.count, id: \.self) { index in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(index: index, value: 1, center: center, radius: radius))
                    }
                    .stroke(IFMTheme.border.opacity(0.75), lineWidth: 1)
                }
                polygon(values: values, center: center, radius: radius)
                    .fill(IFMTheme.green.opacity(0.16))
                polygon(values: values, center: center, radius: radius)
                    .stroke(IFMTheme.green, lineWidth: 2)
            }
        }
    }

    private func polygon(values: [Double], center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            path.move(to: point(index: 0, value: values[0], center: center, radius: radius))
            for index in values.indices.dropFirst() {
                path.addLine(to: point(index: index, value: values[index], center: center, radius: radius))
            }
            path.closeSubpath()
        }
    }

    private func point(index: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (Double(index) / Double(max(1, values.count)) * Double.pi * 2) - Double.pi / 2
        return CGPoint(x: center.x + cos(angle) * radius * value, y: center.y + sin(angle) * radius * value)
    }
}

private struct PatternStatsCard: View {
    var analytics: PatternAnalytics

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pattern Stats").font(.system(size: 15, weight: .bold))
                    Spacer()
                    Pill(text: "Live", color: IFMTheme.green)
                }
                HStack(spacing: 0) {
                    stat("Patterns", "\(analytics.patternCount)")
                    Divider()
                    stat("Links", "\(analytics.connectionCount)")
                    Divider()
                    stat("Cross", String(format: "%.1f", analytics.averageCrossPollination))
                    Divider()
                    stat("Signal", "\(Int(analytics.signalStrength))%")
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(IFMTheme.text)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(IFMTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Portfolio Intelligence (cross-idea reasoning)

struct PortfolioIntelligenceCard: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        IFMCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let report = model.portfolioReport, !report.isEmpty {
                    content(report)
                } else {
                    emptyState
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            SymbolBadge(symbol: "brain.head.profile", color: IFMTheme.purple, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Portfolio Intelligence")
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("Reasoning across every idea at once — not one by one.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
                    .lineLimit(2)
            }
            .frame(minWidth: 180, alignment: .leading)
            Spacer(minLength: 8)
            Button {
                model.runPortfolioReasoning()
            } label: {
                HStack(spacing: 6) {
                    if model.isRunningJob {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(model.isRunningJob ? "Thinking…" : (model.portfolioReport == nil ? "Synthesize" : "Re-synthesize"))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .frame(height: 30)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunningJob || model.ideas.isEmpty)
            .help("Reason across all ideas to find merges, tensions, blind spots, and what to build next.")
            .accessibilityLabel("Synthesize portfolio")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(IFMTheme.purple)
            Text(model.ideas.isEmpty ? "Capture a few ideas first" : "No synthesis yet")
                .font(.system(size: 15, weight: .semibold))
            Text(model.ideas.isEmpty
                 ? "The reasoning pass needs a handful of ideas before it can find merges, tensions, blind spots, and what to build next."
                 : "Run a synthesis to see how your ideas connect, contradict, and combine — and the single one to build next.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func content(_ report: PortfolioReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Pill(text: report.source, color: report.source.hasPrefix("cloud") ? IFMTheme.green : IFMTheme.slate)
                Text("Synthesized \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                if model.portfolioReportIsStale {
                    Label("Portfolio changed — re-synthesize", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(IFMTheme.orange)
                        .lineLimit(1)
                }
                Spacer()
            }

            if !report.summary.isEmpty {
                Text(report.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(IFMTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(IFMTheme.softPanel)
                    .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
            }

            if let buildNext = report.buildNext {
                PortfolioBuildNextHero(insight: buildNext, model: model)
            }

            let supporting = report.supportingInsights
            if !supporting.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(supporting) { insight in
                        PortfolioInsightCard(insight: insight, model: model)
                    }
                }
            }
        }
    }
}

private struct PortfolioBuildNextHero: View {
    var insight: PortfolioInsight
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill").foregroundStyle(IFMTheme.green)
                Text("BUILD NEXT")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(IFMTheme.green)
                Spacer()
            }
            Text(insight.headline)
                .font(.system(size: 16, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.reasoning)
                .font(.system(size: 13))
                .foregroundStyle(IFMTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            PortfolioInsightChips(insight: insight, model: model)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IFMTheme.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous).stroke(IFMTheme.green.opacity(0.30)) }
    }
}

private struct PortfolioInsightCard: View {
    var insight: PortfolioInsight
    @ObservedObject var model: ShellViewModel

    var body: some View {
        let accent = insightColor(insight.kind)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: insight.kind.symbol).font(.caption).foregroundStyle(accent)
                Text(insight.kind.title.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(insight.headline)
                .font(.system(size: 13, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.reasoning)
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            PortfolioInsightChips(insight: insight, model: model)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(IFMTheme.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous).stroke(IFMTheme.border.opacity(0.8)) }
    }
}

private struct PortfolioInsightChips: View {
    var insight: PortfolioInsight
    @ObservedObject var model: ShellViewModel

    var body: some View {
        if !insight.relatedIdeaTitles.isEmpty {
            let openable = Set(model.ideas.map { $0.title.lowercased() })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(insight.relatedIdeaTitles.prefix(4), id: \.self) { title in
                        let canOpen = openable.contains(title.lowercased())
                        Button {
                            if canOpen { model.focusIdea(titled: title) }
                        } label: {
                            HStack(spacing: 4) {
                                if canOpen {
                                    Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
                                }
                                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(IFMTheme.canvas)
                            .clipShape(Capsule())
                            .overlay { Capsule().stroke(IFMTheme.border.opacity(0.7)) }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canOpen)
                        .help(canOpen ? "Open \(title)" : title)
                    }
                }
                .padding(.top, 1)
            }
        }
    }
}

private func insightColor(_ kind: PortfolioInsightKind) -> Color {
    switch kind {
    case .buildNext: IFMTheme.green
    case .gap: IFMTheme.orange
    case .contradiction: IFMTheme.red
    case .merge: IFMTheme.purple
    case .theme: IFMTheme.blue
    }
}

private func color(_ index: Int) -> Color {
    [IFMTheme.purple, IFMTheme.green, IFMTheme.orange, IFMTheme.blue, IFMTheme.red, IFMTheme.slate][index % 6]
}

private func symbol(_ index: Int) -> String {
    ["brain", "sparkles", "tuningfork", "laptopcomputer", "waveform", "lock"][index % 6]
}
