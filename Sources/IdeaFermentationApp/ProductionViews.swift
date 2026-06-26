import AppKit
import IdeaFermentationCore
import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateCard: View {
    var title: String
    var message: String
    var symbol: String
    var actionTitle: String?
    var accent: Color = IFMTheme.green
    var action: (() -> Void)?

    var body: some View {
        IFMCard(padding: 24) {
            VStack(spacing: 10) {
                SymbolBadge(symbol: symbol, color: accent, size: 54)
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(IFMTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190)
            .padding(.vertical, 4)
            .background(IFMTheme.softPanel.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(accent.opacity(0.13)) }
        }
    }
}

struct IdeaCaptureSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Idea").font(.system(size: 24, weight: .bold))
            TextField("Title", text: $model.ideaDraft.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Idea title")
            TextEditor(text: $model.ideaDraft.body)
                .frame(minHeight: 160)
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                .accessibilityLabel("Idea body")
            TextField("Tags, comma separated", text: $model.ideaDraft.tags)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Idea tags")
            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Idea") { model.saveIdeaDraft() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.ideaDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.ideaDraft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}

struct SourceCaptureSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Source").font(.system(size: 24, weight: .bold))
            Picker("Type", selection: $model.sourceDraft.type) {
                ForEach(SourceType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            TextField("Title", text: $model.sourceDraft.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Source title")
            TextField("URL (optional)", text: $model.sourceDraft.url)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Source URL")
            TextEditor(text: $model.sourceDraft.body)
                .frame(minHeight: 140)
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                .accessibilityLabel("Source text")
            Toggle("Never send this source to cloud models", isOn: $model.sourceDraft.neverSendToCloud)
            HStack {
                Button("Import File…") { chooseSourceFile(model: model) }
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Source") { model.saveSourceDraft() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.sourceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.sourceDraft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.sourceDraft.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}

struct ProviderKeysSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider Keys").font(.system(size: 24, weight: .bold))
            Text("Keys are stored in macOS Keychain. Blank fields leave existing keys unchanged.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
            SecureField("Gemini API key", text: $model.keyDraft.gemini)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Gemini API key")
            SecureField("Z.ai API key", text: $model.keyDraft.zai)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Z.ai API key")
            SecureField("Kimi or Moonshot API key", text: $model.keyDraft.kimi)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Kimi API key")
            SecureField("OpenAI API key", text: $model.keyDraft.openAI)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI API key")
            SecureField("Claude or Anthropic API key", text: $model.keyDraft.anthropic)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Claude API key")
            SecureField("Firecrawl API key", text: $model.keyDraft.firecrawl)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Firecrawl API key")
            SecureField("OpenAI-compatible fallback key", text: $model.keyDraft.openAICompatible)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI-compatible fallback API key")
            Divider()
            TextField("Fallback provider label", text: $model.keyDraft.fallbackLabel)
                .textFieldStyle(.roundedBorder)
            TextField("Fallback base URL", text: $model.keyDraft.fallbackBaseURL)
                .textFieldStyle(.roundedBorder)
            TextField("Fallback model name", text: $model.keyDraft.fallbackModel)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Input $ / 1M tokens", text: $model.keyDraft.fallbackInputCost)
                    .textFieldStyle(.roundedBorder)
                TextField("Output $ / 1M tokens", text: $model.keyDraft.fallbackOutputCost)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Keys") { model.saveKeys() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 560)
    }
}

struct BuildOutcomeSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Record Build Outcome").font(.system(size: 24, weight: .bold))
            Text("What happened when you took “\(model.outcomeDraft.ideaTitle)” to build? Acting on an idea is the strongest signal your taste model learns from — much stronger than marking it ready.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Outcome", selection: $model.outcomeDraft.result) {
                ForEach(BuildResult.allCases, id: \.self) { result in
                    Text(result.title).tag(result)
                }
            }
            .pickerStyle(.radioGroup)
            .accessibilityLabel("Build outcome")

            Text("What you learned (optional)").font(.caption).foregroundStyle(IFMTheme.muted)
            TextEditor(text: $model.outcomeDraft.note)
                .frame(minHeight: 110)
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                .accessibilityLabel("What you learned")

            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Record Outcome") { model.saveBuildOutcomeDraft() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

struct SettingsPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingReset = false

    var body: some View {
        PageScaffold(title: "Settings", subtitle: "Provider keys, local data, and app controls.", symbol: "gearshape", accent: IFMTheme.slate) {
            VStack(alignment: .leading, spacing: 16) {
                IFMCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("API Keys").font(.headline)
                        keyRow("Gemini", hasKey: model.hasKey(.gemini))
                        keyRow("Z.ai / GLM", hasKey: model.hasKey(.zai))
                        keyRow("Kimi / Moonshot", hasKey: model.hasKey(.kimi))
                        keyRow("OpenAI", hasKey: model.hasKey(.openAI))
                        keyRow("Claude / Anthropic", hasKey: model.hasKey(.anthropic))
                        keyRow("Firecrawl web search", hasKey: model.hasKey(.firecrawl))
                        keyRow("OpenAI-compatible fallback", hasKey: model.hasKey(.openAICompatible))
                        Text("Fallback: \(model.providerSettings.fallbackProviderLabel) / \(model.providerSettings.fallbackModelName)")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                        Button("Manage Keys") { model.prepareKeyDraft() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if let server = model.captureServer {
                    BrowserConnectorCard(server: server, model: model)
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local Data").font(.headline)
                        Text(model.store.databaseURL.path)
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        HStack {
                            Button("Reveal Database") {
                                NSWorkspace.shared.activateFileViewerSelecting([model.store.databaseURL])
                            }
                            Button("Reset All Data", role: .destructive) { confirmingReset = true }
                        }
                    }
                }
            }
        } rail: {
            PrivacySummaryRail(model: model)
        }
        .confirmationDialog(
            "Reset all local Idea Fermentation Machine data?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset All Data", role: .destructive) { model.resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes local ideas, sources, jobs, logs, patterns, and settings from this app database. API keys in Keychain are not deleted.")
        }
    }

    private func keyRow(_ title: String, hasKey: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(hasKey ? "Configured" : "Missing", systemImage: hasKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(hasKey ? IFMTheme.green : IFMTheme.red)
        }
        .font(.system(size: 14))
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background((hasKey ? IFMTheme.green : IFMTheme.red).opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
    }
}

struct BrowserConnectorCard: View {
    @ObservedObject var server: CaptureServer
    @ObservedObject var model: ShellViewModel
    @State private var revealToken = false

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Browser Connector", systemImage: "link.badge.plus").font(.headline)
                    Spacer()
                    Label(statusText, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(server.isRunning ? IFMTheme.green : IFMTheme.gray)
                }
                Text("Save any page from Chrome straight into Sources — auto-categorized, tagged, and linked to related ideas. Pair the extension once with the token below.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)

                Toggle("Enable connector", isOn: Binding(
                    get: { model.captureServerEnabled },
                    set: { model.setCaptureServerEnabled($0) }
                ))
                .font(.system(size: 13))

                infoRow("Address", server.isRunning ? "127.0.0.1:\(server.activePort)" : "Not running")

                HStack(spacing: 8) {
                    Text("Token").foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Text(revealToken ? server.token : Self.masked(server.token))
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Button(revealToken ? "Hide" : "Reveal") { revealToken.toggle() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .accessibilityLabel(revealToken ? "Hide connector token" : "Reveal connector token")
                }
                .font(.caption)

                HStack {
                    Button("Copy Token") { model.copyCaptureToken() }
                    Button("Copy Pairing Info") { model.copyCapturePairingInfo() }
                    Spacer()
                    Button("Regenerate") { model.regenerateCaptureToken() }
                        .tint(IFMTheme.orange)
                        .accessibilityLabel("Regenerate connector token")
                }
                .font(.caption)

                if let error = server.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(IFMTheme.red)
                }
                Text("In Chrome: load the ChromeExtension folder (Developer mode), open its options, and paste the token. The app keeps running with its window closed so saving always works.")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }

    private var statusText: String {
        server.isRunning ? "Running" : (model.captureServerEnabled ? "Starting" : "Off")
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(IFMTheme.muted)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
    }

    private static func masked(_ token: String) -> String {
        guard token.count > 10 else { return "••••••••" }
        return "\(token.prefix(4))••••••••\(token.suffix(4))"
    }
}

/// The Mind's internal sections — a small, friendly tab set instead of one long scroll.
enum MindSection: String, CaseIterable, Identifiable {
    case overview, web, history, tuning, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .web: return "The Web"
        case .history: return "History"
        case .tuning: return "Tuning"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "sparkles"
        case .web: return "point.3.connected.trianglepath.dotted"
        case .history: return "clock.arrow.circlepath"
        case .tuning: return "slider.horizontal.3"
        case .settings: return "gearshape"
        }
    }
}

struct AutonomyPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var section: MindSection = .overview

    var body: some View {
        PageScaffold(title: "The Mind", subtitle: "An autonomous mind that thinks across your ideas — and checks its own thinking.", symbol: "brain.head.profile", accent: IFMTheme.purple) {
            VStack(alignment: .leading, spacing: IFMSpacing.lg) {
                MindNav(selection: $section)
                Group {
                    switch section {
                    case .overview: MindOverview(model: model, go: { section = $0 })
                    case .web: MindWebSection(model: model)
                    case .history: MindHistory(model: model)
                    case .tuning: MindTuning(model: model)
                    case .settings: MindSettings(model: model)
                    }
                }
                .id(section) // distinct identity per tab so the cross-fade actually fires
                .transition(.opacity)
            }
        } rail: {
            AutonomyRail(model: model)
        }
    }
}

/// The pill-style segmented nav at the top of the Mind page.
struct MindNav: View {
    @Binding var selection: MindSection

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(MindSection.allCases) { section in
                    let active = selection == section
                    Button {
                        withAnimation(IFMMotion.standard) { selection = section }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.symbol).font(.system(size: 12, weight: .semibold))
                            Text(section.title).font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .foregroundStyle(active ? Color.white : IFMTheme.muted)
                        .background(active ? IFMTheme.purple : Color.clear)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                }
            }
            .padding(5)
            .background(IFMTheme.panel.opacity(0.7))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(IFMTheme.border.opacity(0.6)) }
            .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

/// A titled section group, reused across the Tuning and Settings tabs.
struct MindGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    @ViewBuilder var content: Content

    init(title: String, subtitle: String, symbol: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.sm) {
            SectionHeader(title, subtitle: subtitle, symbol: symbol, accent: accent)
                .padding(.horizontal, 2)
            content
        }
    }
}

// MARK: - Overview tab (the friendly landing)

struct MindOverview: View {
    @ObservedObject var model: ShellViewModel
    var go: (MindSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.lg) {
            AutomationHeroCard(model: model)
            MindLatestThoughtCard(model: model, onSeeAll: { go(.history) })
            MindWebPeekCard(model: model, onExplore: { go(.web) })
        }
    }
}

/// A plain-language summary of the most recent cycle, with a link into the full history.
struct MindLatestThoughtCard: View {
    @ObservedObject var model: ShellViewModel
    var onSeeAll: () -> Void

    var body: some View {
        SectionCard("Its latest thought", symbol: "brain.head.profile", accent: IFMTheme.purple, trailing: {
            if let session = model.latestThinkingSession {
                Pill(text: session.source, color: session.isCloud ? IFMTheme.purple : IFMTheme.slate)
            }
        }) {
            if let session = model.latestThinkingSession {
                VStack(alignment: .leading, spacing: IFMSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THINKING ABOUT").font(.ifmEyebrow).foregroundStyle(IFMTheme.muted)
                        Text(session.focus).font(.system(size: 17, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if !session.analysis.isEmpty {
                            Text(session.analysis).font(.ifmBody).foregroundStyle(IFMTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: IFMSpacing.md) {
                        ConfidenceGauge(value: session.reflection.confidence)
                        if !session.generatedIdeaIDs.isEmpty {
                            Label("\(session.generatedIdeaIDs.count) new idea\(session.generatedIdeaIDs.count == 1 ? "" : "s")", systemImage: "lightbulb.fill")
                                .font(.ifmCaption).foregroundStyle(IFMTheme.green)
                        }
                        Spacer()
                    }
                    if !session.reflection.weakestLink.isEmpty {
                        overviewLine("Least sure about", session.reflection.weakestLink, "exclamationmark.triangle", IFMTheme.orange)
                    }
                    if !session.reflection.nextToExplore.isEmpty {
                        overviewLine("Wants to explore next", session.reflection.nextToExplore, "arrow.forward.circle", IFMTheme.blue)
                    }
                    Button(action: onSeeAll) {
                        Label("See the full train of thought", systemImage: "arrow.right").font(.ifmCaption)
                    }
                    .buttonStyle(.plain).foregroundStyle(IFMTheme.purple)
                }
            } else {
                MindEmptyState(
                    title: "The mind hasn't thought yet.",
                    message: "Press **Think Now** above to run a cycle — or turn the Mind on and it thinks on its own every ~30 minutes."
                )
            }
        }
    }

    @ViewBuilder
    private func overviewLine(_ label: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(color).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(IFMTheme.muted)
                Text(value).font(.ifmCaption).foregroundStyle(IFMTheme.text).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A compact preview of the web, linking into the full Web tab.
struct MindWebPeekCard: View {
    @ObservedObject var model: ShellViewModel
    var onExplore: () -> Void

    private var nodes: [Thought] {
        guard let session = model.latestThinkingSession else { return [] }
        return model.mindThoughts.filter { $0.sessionID == session.id }
    }
    private var edges: [ThoughtEdge] {
        guard let session = model.latestThinkingSession else { return [] }
        return model.mindEdges.filter { $0.sessionID == session.id }
    }

    var body: some View {
        SectionCard("The web", subtitle: "How its thoughts connect.", symbol: "point.3.connected.trianglepath.dotted", accent: IFMTheme.blue, trailing: {
            Button(action: onExplore) { Label("Explore", systemImage: "arrow.up.right").font(.ifmCaption) }
                .buttonStyle(.plain).foregroundStyle(IFMTheme.blue)
        }) {
            if nodes.count < 2 {
                MindEmptyState(
                    title: model.thoughtCount == 0 ? "No web yet." : "The web is still sparse.",
                    message: model.thoughtCount == 0 ? "When the mind thinks, the connections it draws appear here and grow each cycle." : "Run another cycle to grow it."
                )
            } else {
                VStack(alignment: .leading, spacing: IFMSpacing.sm) {
                    ThoughtWebGraph(thoughts: nodes, edges: edges, height: 230, maxNodes: 5)
                    Text("\(model.thoughtCount) thoughts · \(model.connectionCount) connections across all cycles")
                        .font(.ifmCaption).foregroundStyle(IFMTheme.muted)
                }
            }
        }
    }
}

// MARK: - Web tab

struct MindWebSection: View {
    @ObservedObject var model: ShellViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.md) {
            SectionHeader("The thought-web", subtitle: "Its latest cycle as nodes and typed connections — the web grows every time it thinks.", symbol: "point.3.connected.trianglepath.dotted", accent: IFMTheme.blue)
                .padding(.horizontal, 2)
            ThoughtWebCard(model: model)
        }
    }
}

// MARK: - History tab

struct MindHistory: View {
    @ObservedObject var model: ShellViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.md) {
            SectionHeader("Train of thought", subtitle: "Every cycle the mind has run — tap any one to see how it reasoned.", symbol: "clock.arrow.circlepath", accent: IFMTheme.purple)
                .padding(.horizontal, 2)
            if model.thinkingSessions.isEmpty {
                IFMCard {
                    MindEmptyState(title: "No thinking yet.", message: "Press **Think Now** on the Overview to run the first cycle.")
                }
            } else {
                ForEach(model.thinkingSessions) { session in
                    MindSessionRow(model: model, session: session)
                }
            }
        }
    }
}

/// One past cycle — collapsed to a headline, expandable to its full reasoning + self-critique.
struct MindSessionRow: View {
    @ObservedObject var model: ShellViewModel
    let session: ThinkingSession
    @State private var expanded = false

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        IFMCard(padding: IFMSpacing.md) {
            VStack(alignment: .leading, spacing: expanded ? IFMSpacing.md : 0) {
                Button {
                    withAnimation(IFMMotion.standard) { expanded.toggle() }
                } label: {
                    HStack(spacing: IFMSpacing.sm) {
                        SymbolBadge(symbol: session.isCloud ? "brain.head.profile" : "cpu", color: session.isCloud ? IFMTheme.purple : IFMTheme.slate, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.focus).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(subtitle).font(.ifmCaption).foregroundStyle(IFMTheme.muted).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        ConfidenceGauge(value: session.reflection.confidence)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(IFMTheme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider()
                    if !session.analysis.isEmpty {
                        Text(session.analysis).font(.ifmBody).foregroundStyle(IFMTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    let thoughts = model.mindThoughts.filter { $0.sessionID == session.id }
                    if !thoughts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(thoughts) { ThoughtRow(thought: $0) }
                        }
                    }
                    ReflectionView(reflection: session.reflection)
                }
            }
        }
    }

    private var subtitle: String {
        let when = Self.relative.localizedString(for: session.startedAt, relativeTo: Date())
        let ideas = session.generatedIdeaIDs.count
        let ideaText = ideas == 0 ? "no new ideas" : "\(ideas) new idea\(ideas == 1 ? "" : "s")"
        return "\(when) · \(ideaText) · \(session.source)"
    }
}

// MARK: - Tuning tab

struct MindTuning: View {
    @ObservedObject var model: ShellViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.xl) {
            MindGroup(title: "What it watches", subtitle: "The lanes it researches and the candidates it brings back.", symbol: "scope", accent: IFMTheme.green) {
                ScoutMissionsCard(model: model)
                ScoutFocusCard(model: model)
                AutomationProfileCard(model: model)
            }
            MindGroup(title: "What it's learned about you", subtitle: "Tuned from your real decisions — not hand-edited.", symbol: "brain.head.profile", accent: IFMTheme.purple) {
                LearnedTasteCard(model: model)
                RipenessCalibrationCard(model: model)
                ForecastAccuracyCard(model: model)
            }
        }
    }
}

// MARK: - Settings tab

struct MindSettings: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.xl) {
            MindGroup(title: "Schedule & spend", subtitle: "Guardrails for unattended thinking.", symbol: "gauge.with.dots.needle.bottom.50percent", accent: IFMTheme.orange) {
                GuardrailsCard(model: model)
            }
            MindGroup(title: "Privacy", subtitle: "What can leave this Mac.", symbol: "lock.shield", accent: IFMTheme.slate) {
                AutomationPrivacyCard(model: model)
            }
            MindGroup(title: "Reset", subtitle: "Start the mind's memory fresh.", symbol: "trash", accent: IFMTheme.red) {
                SectionCard("Clear the mind", subtitle: "Deletes all thoughts, connections, and thinking history. Your ideas are untouched.", symbol: "trash", accent: IFMTheme.red) {
                    Button(role: .destructive) { confirmingReset = true } label: {
                        Label("Clear the mind's memory", systemImage: "trash")
                    }
                    .buttonStyle(.bordered).tint(IFMTheme.red)
                }
            }
        }
        .alert("Clear the mind's memory?", isPresented: $confirmingReset) {
            Button("Clear", role: .destructive) { model.clearMind() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every thought, connection, and thinking session. Your ideas are not affected.")
        }
    }
}

/// A small, friendly empty-state block used across the Mind sections.
struct MindEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.ifmBody.weight(.semibold)).foregroundStyle(IFMTheme.text)
            Text(.init(message)).font(.ifmCaption).foregroundStyle(IFMTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

/// The master switch for the whole autonomous engine, with at-a-glance telemetry.
struct AutomationHeroCard: View {
    @ObservedObject var model: ShellViewModel

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        let on = model.autonomyProfile.isEnabled
        let accent = on ? IFMTheme.green : IFMTheme.slate
        IFMCard(padding: IFMSpacing.xl) {
            VStack(alignment: .leading, spacing: IFMSpacing.lg) {
                HStack(alignment: .center, spacing: IFMSpacing.md) {
                    SymbolBadge(symbol: model.isThinking ? "brain.head.profile.fill" : (on ? "brain.head.profile" : "brain"), color: accent, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.isThinking ? "The Mind is thinking…" : (on ? "The Mind is ON" : "The Mind is OFF"))
                            .font(.ifmTitle)
                        Text(on
                             ? "It reasons across your ideas, draws connections into its web, generates new ideas, and critiques its own thinking — on its own every ~30 min, within your caps."
                             : "Turn it on to let the mind think for itself: research your lanes, connect ideas, generate new ones, and check its own reasoning — on your schedule, within your caps.")
                            .font(.ifmBody)
                            .foregroundStyle(IFMTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $model.autonomyProfile.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(IFMTheme.green)
                        .scaleEffect(1.25)
                        .accessibilityLabel("The Mind")
                        .onChange(of: model.autonomyProfile.isEnabled) { _, _ in model.persistAutonomyConfiguration() }
                }

                HStack(spacing: IFMSpacing.sm) {
                    StatTile(value: "\(model.thoughtCount)", label: "Thoughts", symbol: "brain", accent: on ? IFMTheme.purple : IFMTheme.muted)
                    StatTile(value: "\(model.connectionCount)", label: "Connections", symbol: "point.topleft.down.to.point.bottomright.curvepath", accent: on ? IFMTheme.blue : IFMTheme.muted)
                    StatTile(value: confidenceText, label: "Confidence", sub: "last cycle", symbol: "gauge.medium", accent: on ? IFMTheme.green : IFMTheme.muted)
                    StatTile(value: spentToday, label: "Spent today", sub: "of \(capText)", symbol: "dollarsign.circle", accent: spendAccent)
                }
                .opacity(on ? 1 : 0.7)

                HStack(spacing: IFMSpacing.sm) {
                    Button {
                        Task { await model.think() }
                    } label: {
                        HStack(spacing: 6) {
                            if model.isThinking { ProgressView().controlSize(.small) }
                            else { Image(systemName: "sparkles") }
                            Text(model.isThinking ? "Thinking…" : "Think Now")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IFMTheme.purple)
                    .disabled(model.isThinking || model.isRunningJob || model.isRunningScout)
                    .help("Run one cognitive cycle now — reason, connect, generate, and reflect.")

                    Button {
                        Task { await model.runAutonomousScout() }
                    } label: {
                        HStack(spacing: 6) {
                            if model.isRunningScout { ProgressView().controlSize(.small) }
                            else { Image(systemName: "scope") }
                            Text(model.isRunningScout ? "Scouting…" : "Run Scout")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(IFMTheme.green)
                    .disabled(model.isRunningScout || model.isThinking || model.isRunningJob || !on)
                    .help(on ? "Run a single scout pass to bring in fresh signals." : "Turn the Mind on to run the scout.")
                }
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, IFMSpacing.lg)
        }
        .animation(IFMMotion.standard, value: on)
    }

    private var confidenceText: String {
        guard let confidence = model.latestThinkingSession?.reflection.confidence else { return "—" }
        return "\(Int((confidence * 100).rounded()))%"
    }

    private var spentToday: String { String(format: "$%.2f", model.spentTodayUSD) }
    private var capText: String { String(format: "$%.2f", model.schedulerSettings.dailySpendCapUSD) }
    private var spendAccent: Color {
        let cap = model.schedulerSettings.dailySpendCapUSD
        guard cap > 0 else { return IFMTheme.text }
        let fraction = model.spentTodayUSD / cap
        if fraction >= 1 { return IFMTheme.red }
        if fraction >= 0.8 { return IFMTheme.orange }
        return IFMTheme.green
    }
}

// MARK: - The Mind's cycle (shared building blocks)

private struct ThoughtRow: View {
    let thought: Thought
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: thought.kind.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(thoughtKindColor(thought.kind))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(thought.content).font(.ifmCaption).foregroundStyle(IFMTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !thought.rationale.isEmpty {
                    Text(thought.rationale).font(.system(size: 10)).foregroundStyle(IFMTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            Text(thought.kind.label).font(.system(size: 9, weight: .heavy))
                .foregroundStyle(thoughtKindColor(thought.kind))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(thoughtKindColor(thought.kind).opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

/// The metacognition surface — the mind judging *how it just thought*, not the ideas.
private struct ReflectionView: View {
    let reflection: MindReflection
    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11, weight: .bold))
                Text("HOW IT JUDGED ITS OWN THINKING").font(.ifmEyebrow)
                Spacer()
                ConfidenceGauge(value: reflection.confidence)
            }
            .foregroundStyle(IFMTheme.purple)

            if reflection.isEmpty {
                Text("No self-critique was produced this cycle.").font(.ifmCaption).foregroundStyle(IFMTheme.muted)
            } else {
                if !reflection.weakestLink.isEmpty {
                    reflectionLine("Weakest link", reflection.weakestLink, "exclamationmark.triangle", IFMTheme.orange)
                }
                if !reflection.assumptions.isEmpty {
                    reflectionLine("Assumptions it leaned on", reflection.assumptions.joined(separator: " · "), "questionmark.diamond", IFMTheme.slate)
                }
                if !reflection.spuriousConnections.isEmpty {
                    reflectionLine("Links it may have over-drawn", reflection.spuriousConnections.joined(separator: " · "), "scissors", IFMTheme.red)
                }
                if !reflection.processNote.isEmpty {
                    reflectionLine("On its process", reflection.processNote, "gearshape.2", IFMTheme.muted)
                }
                if !reflection.nextToExplore.isEmpty {
                    reflectionLine("Pulling on next", reflection.nextToExplore, "arrow.forward.circle", IFMTheme.blue)
                }
            }
        }
        .padding(IFMSpacing.md)
        .background(IFMTheme.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.purple.opacity(0.18)) }
    }

    @ViewBuilder
    private func reflectionLine(_ label: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(color).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(IFMTheme.muted)
                Text(value).font(.ifmCaption).foregroundStyle(IFMTheme.text).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ConfidenceGauge: View {
    let value: Double
    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(IFMTheme.purple.opacity(0.15)).frame(width: 54, height: 6)
                Capsule().fill(IFMTheme.purple).frame(width: max(3, 54 * value), height: 6)
            }
            Text("\(Int((value * 100).rounded()))%").font(.system(size: 10, weight: .heavy)).foregroundStyle(IFMTheme.purple)
        }
    }
}

/// The structured graph — the latest cycle's thoughts as nodes, its connections as typed,
/// colour-coded links, with the labelled rationale listed beneath.
struct ThoughtWebCard: View {
    @ObservedObject var model: ShellViewModel

    private var nodes: [Thought] {
        guard let session = model.latestThinkingSession else { return [] }
        return model.mindThoughts.filter { $0.sessionID == session.id }
    }
    private var edges: [ThoughtEdge] {
        guard let session = model.latestThinkingSession else { return [] }
        return model.mindEdges.filter { $0.sessionID == session.id }
    }

    var body: some View {
        SectionCard("The web", subtitle: "How its thoughts connect — the web grows every cycle.", symbol: "point.3.connected.trianglepath.dotted", accent: IFMTheme.blue, trailing: {
            Text("\(model.thoughtCount) nodes · \(model.connectionCount) links")
                .font(.ifmCaption).foregroundStyle(IFMTheme.muted)
        }) {
            if nodes.count < 2 {
                Text(model.thoughtCount == 0
                     ? "No web yet — when the mind thinks, the connections it draws appear here and accumulate across cycles."
                     : "The latest cycle was sparse. Run another to grow the web.")
                    .font(.ifmCaption).foregroundStyle(IFMTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: IFMSpacing.md) {
                    ThoughtWebGraph(thoughts: nodes, edges: edges)
                    if !edges.isEmpty {
                        EdgeLegend(types: Array(Set(edges.map(\.type))).sorted { $0.label < $1.label })
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(edges) { edge in EdgeRow(edge: edge, nodes: nodes) }
                        }
                    }
                }
            }
        }
    }
}

private struct ThoughtWebGraph: View {
    let thoughts: [Thought]
    let edges: [ThoughtEdge]
    var height: CGFloat = 340
    /// Cap the nodes drawn on the circle so chips stay readable; the full set is always
    /// listed beneath the graph, so capping the *visual* loses no information.
    var maxNodes: Int = 8

    private var shown: [Thought] { Array(thoughts.prefix(maxNodes)) }
    private var shownEdges: [ThoughtEdge] {
        let ids = Set(shown.map(\.id))
        return edges.filter { ids.contains($0.fromThoughtID) && ids.contains($0.toThoughtID) }
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        let n = shown.count
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard n > 1 else { return [center] }
        // Keep the circle clear of the chip's own footprint so nodes never hug the frame edge.
        let radius = min(size.width, size.height) / 2 - 52
        return (0..<n).map { i in
            let angle = (Double(i) / Double(n)) * 2 * .pi - .pi / 2
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let pos = positions(in: geo.size)
                let index = Dictionary(shown.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
                ZStack {
                    Canvas { context, _ in
                        for edge in shownEdges {
                            guard let i = index[edge.fromThoughtID], let j = index[edge.toThoughtID], i < pos.count, j < pos.count else { continue }
                            var path = Path()
                            path.move(to: pos[i])
                            path.addLine(to: pos[j])
                            context.stroke(path, with: .color(thoughtEdgeColor(edge.type).opacity(0.55)),
                                           style: StrokeStyle(lineWidth: 1.2 + edge.strength * 2.2, lineCap: .round))
                        }
                    }
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, thought in
                        if i < pos.count { NodeChip(thought: thought).position(pos[i]) }
                    }
                }
            }
            .frame(height: height)
            if thoughts.count > shown.count {
                Text("+\(thoughts.count - shown.count) more thought\(thoughts.count - shown.count == 1 ? "" : "s") below")
                    .font(.system(size: 10)).foregroundStyle(IFMTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

private struct NodeChip: View {
    let thought: Thought
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: thought.kind.symbol).font(.system(size: 9, weight: .bold))
            Text(thought.content).lineLimit(2).multilineTextAlignment(.leading)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(IFMTheme.text)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: 92)
        .background(thoughtKindColor(thought.kind).opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(thoughtKindColor(thought.kind).opacity(0.45)) }
        .help(thought.rationale.isEmpty ? thought.content : "\(thought.content)\n\n\(thought.rationale)")
    }
}

private struct EdgeLegend: View {
    let types: [ThoughtEdgeType]
    var body: some View {
        HStack(spacing: 12) {
            ForEach(types, id: \.self) { type in
                HStack(spacing: 4) {
                    Capsule().fill(thoughtEdgeColor(type)).frame(width: 14, height: 3)
                    Text(type.label).font(.system(size: 10)).foregroundStyle(IFMTheme.muted)
                }
            }
            Spacer()
        }
    }
}

private struct EdgeRow: View {
    let edge: ThoughtEdge
    let nodes: [Thought]
    private func label(_ id: UUID) -> String {
        nodes.first { $0.id == id }.map { String($0.content.prefix(46)) } ?? "?"
    }
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(thoughtEdgeColor(edge.type)).frame(width: 6, height: 6).padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                (Text(label(edge.fromThoughtID)).foregroundStyle(IFMTheme.text)
                 + Text("  \(edge.type.label)  ").foregroundStyle(thoughtEdgeColor(edge.type))
                 + Text(label(edge.toThoughtID)).foregroundStyle(IFMTheme.text))
                    .font(.system(size: 11, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                if !edge.rationale.isEmpty {
                    Text(edge.rationale).font(.system(size: 10)).foregroundStyle(IFMTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private func thoughtKindColor(_ kind: ThoughtKind) -> Color {
    switch kind {
    case .observation: return IFMTheme.orange
    case .connection: return IFMTheme.blue
    case .hypothesis: return IFMTheme.purple
    case .question: return IFMTheme.slate
    }
}

private func thoughtEdgeColor(_ type: ThoughtEdgeType) -> Color {
    switch type {
    case .supports: return IFMTheme.green
    case .contradicts: return IFMTheme.red
    case .extends: return IFMTheme.blue
    case .questions: return IFMTheme.slate
    case .derivesFrom: return IFMTheme.purple
    }
}

struct ScoutMissionsCard: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        SectionCard("Scout Missions", subtitle: "The lanes the scout researches on its cadence.", symbol: "antenna.radiowaves.left.and.right", accent: IFMTheme.green, trailing: {
            if !model.autonomyProfile.isEnabled { Pill(text: "Paused", color: IFMTheme.slate) }
        }) {
            HStack(spacing: IFMSpacing.xs) {
                TextField("Mission title", text: $model.scoutMissionDraft.title)
                    .textFieldStyle(.roundedBorder)
                TextField("Query", text: $model.scoutMissionDraft.query)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { model.addScoutMission() }
                    .disabled(model.scoutMissionDraft.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if model.scoutMissions.isEmpty {
                Text("Add a mission like “AI-native macOS utilities”, or run the scout to seed one from your watch topics.")
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .padding(.vertical, 4)
            } else {
                ForEach(model.scoutMissions) { mission in
                    ScoutMissionRow(
                        mission: mission,
                        toggle: { model.toggleScoutMission(mission) },
                        delete: { model.deleteScoutMission(mission) }
                    )
                    if mission.id != model.scoutMissions.last?.id { Divider().opacity(0.5) }
                }
            }
        }
    }
}

struct AutomationProfileCard: View {
    @ObservedObject var model: ShellViewModel
    @State private var expanded = false
    // Edited in local state, committed only on "Save Brief". Binding the fields
    // directly to the @Published profile let an unrelated reload() (e.g. setting a
    // spend cap) silently wipe in-progress edits; local state is immune to that.
    @State private var tasteNotes = ""
    @State private var goals = ""
    @State private var watchTopics = ""
    @State private var excludedTopics = ""
    @State private var preferredOutputs = ""
    @State private var loaded = false

    var body: some View {
        SectionCard("Mission Brief", subtitle: "Who you are and what to watch — the scout reasons against this.", symbol: "person.text.rectangle", accent: IFMTheme.blue) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: IFMSpacing.xs) {
                    Text("Taste notes").font(.ifmCaption).foregroundStyle(IFMTheme.muted)
                    TextEditor(text: $tasteNotes)
                        .frame(minHeight: 70)
                        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                        .accessibilityLabel("Taste notes")
                    TextField("Goals", text: $goals).textFieldStyle(.roundedBorder)
                    TextField("Watch topics, comma separated", text: $watchTopics).textFieldStyle(.roundedBorder)
                    TextField("Excluded topics", text: $excludedTopics).textFieldStyle(.roundedBorder)
                    TextField("Preferred outputs", text: $preferredOutputs).textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Save Brief") { save() }
                            .buttonStyle(.borderedProminent)
                            .tint(IFMTheme.blue)
                    }
                }
                .padding(.top, IFMSpacing.xs)
            } label: {
                Text(briefSummary).font(.ifmCaption).foregroundStyle(IFMTheme.muted).lineLimit(1)
            }
            .tint(IFMTheme.blue)
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        let profile = model.autonomyProfile
        tasteNotes = profile.tasteNotes
        goals = profile.goals
        watchTopics = profile.watchTopics
        excludedTopics = profile.excludedTopics
        preferredOutputs = profile.preferredOutputs
        loaded = true
    }

    private func save() {
        model.autonomyProfile.tasteNotes = tasteNotes
        model.autonomyProfile.goals = goals
        model.autonomyProfile.watchTopics = watchTopics
        model.autonomyProfile.excludedTopics = excludedTopics
        model.autonomyProfile.preferredOutputs = preferredOutputs
        model.persistAutonomyConfiguration()
    }

    private var briefSummary: String {
        let topics = (loaded ? watchTopics : model.autonomyProfile.watchTopics).trimmingCharacters(in: .whitespacesAndNewlines)
        return topics.isEmpty ? "No watch topics yet — tap to set your brief." : "Watching: \(topics)"
    }
}

struct GuardrailsCard: View {
    @ObservedObject var model: ShellViewModel
    @State private var daily = ""
    @State private var monthly = ""

    var body: some View {
        SectionCard("Schedule & Spend", subtitle: "Limits for unattended runs. A manual click always overrides these.", symbol: "gauge.with.dots.needle.bottom.50percent", accent: IFMTheme.orange) {
            ToggleRow(
                "Let the scheduler run cloud jobs unattended",
                subtitle: "When off, only your clicks ever spend money.",
                isOn: Binding(
                    get: { model.schedulerSettings.cloudAutoRun },
                    set: { value in var settings = model.schedulerSettings; settings.cloudAutoRun = value; model.updateScheduler(settings) }
                )
            )
            ToggleRow(
                "Allow public web scouting",
                subtitle: "Search public endpoints for fresh signals.",
                isOn: $model.autonomyProfile.allowWebScouting,
                onChange: { model.persistAutonomyConfiguration() }
            )
            ToggleRow(
                "Require approval before unattended cloud synthesis",
                subtitle: "On: scheduled runs use the free local template. Off: a scheduled run may spend a cloud call within caps.",
                isOn: $model.autonomyProfile.requireApprovalBeforeBuildHandoff,
                onChange: { model.persistAutonomyConfiguration() }
            )
            Divider().opacity(0.5)
            HStack(alignment: .bottom, spacing: IFMSpacing.sm) {
                capField(title: "Daily cap", text: $daily, current: model.schedulerSettings.dailySpendCapUSD) { model.updateDailySpendCap(daily); daily = "" }
                capField(title: "Monthly cap", text: $monthly, current: model.schedulerSettings.monthlySpendCapUSD) { model.updateMonthlySpendCap(monthly); monthly = "" }
                Button("Run Scheduler Now") { model.runSchedulerNow() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func capField(title: String, text: Binding<String>, current: Double, commit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) (now \(String(format: "$%.2f", current)))")
                .font(.ifmCaption).foregroundStyle(IFMTheme.muted)
            HStack(spacing: 4) {
                Text("$").foregroundStyle(IFMTheme.muted)
                TextField("0.00", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit(commit)
                    .accessibilityLabel("\(title) spend cap")
                Button("Set", action: commit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct AutomationPrivacyCard: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        SectionCard("Privacy", subtitle: "Never-send material stays on this Mac.", symbol: "lock.shield", accent: IFMTheme.slate) {
            let blocked = model.sources.filter(\.neverSendToCloud).count
            HStack(spacing: IFMSpacing.sm) {
                StatTile(value: "\(blocked)", label: "Never-send sources", symbol: "lock", accent: blocked > 0 ? IFMTheme.green : IFMTheme.muted)
                StatTile(value: String(format: "$%.2f", model.metrics.totalSpend), label: "Total cloud spend", symbol: "dollarsign.circle", accent: IFMTheme.text)
            }
            Button("Open Privacy Center") { model.selectedPage = .privacyCenter }
                .buttonStyle(.bordered)
        }
    }
}

struct ScoutMissionRow: View {
    var mission: ScoutMission
    var toggle: () -> Void
    var delete: () -> Void
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: mission.isEnabled ? "antenna.radiowaves.left.and.right" : "pause.circle", color: mission.isEnabled ? IFMTheme.green : IFMTheme.gray, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(mission.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(mission.query).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(1)
                HStack(spacing: 8) {
                    Text(mission.lastRunAt.map { "Last ran \(Self.dateFormatter.string(from: $0))" } ?? "Not run yet")
                    Text("Every \(mission.cadenceHours)h")
                    Text(nextRunText)
                        .foregroundStyle(isDue ? IFMTheme.green : IFMTheme.muted)
                }
                .font(.caption2)
                .foregroundStyle(IFMTheme.muted)
            }
            Spacer()
            Button(mission.isEnabled ? "Pause" : "Enable", action: toggle)
            Button(role: .destructive, action: {
                confirmingDelete = true
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete mission")
            .accessibilityLabel("Delete mission")
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Delete “\(mission.title)”?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Mission", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The scout mission will stop running. Existing ideas and sources remain.")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var isDue: Bool {
        mission.isEnabled && mission.lastRunAt.map { Date(timeInterval: Double(max(1, mission.cadenceHours) * 60 * 60), since: $0) <= Date() } ?? true
    }

    private var nextRunText: String {
        guard mission.isEnabled else { return "Paused" }
        guard let lastRunAt = mission.lastRunAt else { return "Due now" }
        let next = Date(timeInterval: Double(max(1, mission.cadenceHours) * 60 * 60), since: lastRunAt)
        return next <= Date() ? "Due now" : "Next \(Self.dateFormatter.string(from: next))"
    }
}

struct LearnedTasteCard: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingReset = false

    var body: some View {
        SectionCard("Learned Taste", subtitle: "Distilled from what you mark Ready, build, or archive — what genuinely pulls you in, not just topic words.", symbol: "brain.head.profile", accent: IFMTheme.purple, trailing: {
            Pill(text: "\(model.tasteModel.observations) signal\(model.tasteModel.observations == 1 ? "" : "s")", color: IFMTheme.purple)
        }) {
            if let profile = model.tasteProfile, !profile.isEmpty {
                profileView(profile)
            } else if model.tasteModel.isEmpty {
                Text("Nothing learned yet. Mark an idea Ready, build one, or archive one — then learn your taste to get a portrait of what pulls you in.")
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .padding(.vertical, 2)
            }

            // The raw learned themes stay as a secondary, always-local signal.
            if !model.tasteModel.isEmpty {
                learnedThemes
            }

            conceptSpaceNote

            actions
        }
        .confirmationDialog("Reset learned taste?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset Learned Taste", role: .destructive) { model.resetLearnedTaste() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Forgets every theme learned from your past decisions, and clears the distilled portrait. Your written taste profile above is unaffected.")
        }
    }

    private func profileView(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(profile.portrait)
                .font(.system(size: 14))
                .foregroundStyle(IFMTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IFMTheme.softPanel)
                .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))

            if !profile.likes.isEmpty {
                criteriaSection(title: "Draws you in", color: IFMTheme.green, criteria: profile.likes)
            }
            if !profile.avoids.isEmpty {
                criteriaSection(title: "Pushes you away", color: IFMTheme.red, criteria: profile.avoids)
            }

            HStack(spacing: 8) {
                Pill(text: profile.source, color: profile.source.hasPrefix("cloud") ? IFMTheme.green : IFMTheme.slate)
                Text("Learned \(profile.generatedAt.formatted(date: .abbreviated, time: .shortened)) · \(profile.decisionCount) decision\(profile.decisionCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                if model.tasteProfileIsStale {
                    Label("New decisions — re-learn", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(IFMTheme.orange)
                        .lineLimit(1)
                }
            }
        }
    }

    private func criteriaSection(title: String, color: Color, criteria: [TasteCriterion]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            ForEach(criteria) { criterion in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(color).frame(width: 6, height: 6).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(criterion.name).font(.system(size: 12, weight: .semibold))
                        if !criterion.note.isEmpty {
                            Text(criterion.note).font(.caption2).foregroundStyle(IFMTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private var learnedThemes: some View {
        let themes = model.tasteModel.topThemes(limit: 8)
        return VStack(alignment: .leading, spacing: 6) {
            if !themes.liked.isEmpty {
                themeRow(title: "Themes it tracks", color: IFMTheme.slate, tokens: themes.liked.map(\.token))
            }
        }
    }

    @ViewBuilder
    private var conceptSpaceNote: some View {
        let manifold = model.conceptTaste
        if manifold.isActive {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "scope")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.green)
                    .padding(.top, 1)
                Text("Scoring new ideas in concept space — by how close they sit to your \(manifold.likedCount) committed vs \(manifold.dislikedCount) dropped ideas, not just matching words.")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IFMTheme.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.sm, style: .continuous))
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                model.relearnTaste()
            } label: {
                HStack(spacing: 6) {
                    if model.isRunningJob { ProgressView().controlSize(.small) }
                    else { Image(systemName: "wand.and.stars") }
                    Text(model.isRunningJob ? "Thinking…" : (model.tasteProfile == nil ? "Learn My Taste" : "Re-learn Taste"))
                }
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.isRunningJob)
            Spacer()
            if !model.tasteModel.isEmpty || model.tasteProfile != nil {
                Button("Reset", role: .destructive) { confirmingReset = true }
                    .font(.caption)
            }
        }
    }

    private func themeRow(title: String, color: Color, tokens: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(tokens, id: \.self) { token in
                        Pill(text: ifmDisplayTerm(token), color: color)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

struct RipenessCalibrationCard: View {
    @ObservedObject var model: ShellViewModel

    private static let axisLabels: [String: String] = [
        "novelty": "Novelty", "clarity": "Clarity", "evidence": "Evidence",
        "resonance": "Taste fit", "feasibility": "Feasibility", "timing": "Timing"
    ]

    var body: some View {
        let calibration = model.ripenessCalibration
        return SectionCard("What Predicts Your Wins", subtitle: "Calibrates ripeness from real build outcomes — the axes that separated what you shipped from what flopped count for more.", symbol: "scalemass", accent: IFMTheme.orange) {
            if !calibration.isCalibrated {
                Text(calibration.observations > 0
                     ? "Recorded \(calibration.observations) outcome\(calibration.observations == 1 ? "" : "s") so far. Once you've built a few that went well and a few that didn't, ripeness re-weights toward what actually predicts your wins."
                     : "No outcomes yet. Record what happened when you build (Shipped / Built / Abandoned / Flopped) and ripeness starts learning which signals matter for you.")
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .padding(.vertical, 2)
            } else {
                ForEach(calibration.drivers(), id: \.axis) { driver in
                    driverRow(label: Self.axisLabels[driver.axis] ?? driver.axis.capitalized, weight: driver.weight)
                }
                Text("Fit from \(calibration.observations) build outcome\(calibration.observations == 1 ? "" : "s"). 1.0× = the old equal weighting.")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                    .padding(.top, 2)
            }
        }
    }

    private func driverRow(label: String, weight: Double) -> some View {
        let emphasized = weight >= 1.05
        let muted = weight <= 0.95
        let color = emphasized ? IFMTheme.green : (muted ? IFMTheme.slate : IFMTheme.muted)
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 86, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(IFMTheme.scrim.opacity(0.08)).frame(height: 7)
                    // Bar centered on the 1.0× midpoint: longer = more predictive.
                    Capsule().fill(color)
                        .frame(width: max(4, proxy.size.width * CGFloat(min(2.0, weight) / 2.0)), height: 7)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)
            Text(String(format: "%.1f×", weight))
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

struct ForecastAccuracyCard: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        let acc = model.forecastAccuracy
        return SectionCard("Are Its Calls Any Good?", subtitle: "When the app promotes an idea to Ready it's making a bet. Here's how those bets have actually played out.", symbol: "target", accent: IFMTheme.green, trailing: {
            if acc.openCount > 0 { Pill(text: "\(acc.openCount) open", color: IFMTheme.slate) }
        }) {
            if acc.isReliable {
                HStack(spacing: IFMSpacing.sm) {
                    StatTile(value: "\(Int((acc.hitRate * 100).rounded()))%", label: "Ready calls that paid off", symbol: "checkmark.seal", accent: acc.beatsCoinFlip ? IFMTheme.green : IFMTheme.orange)
                    StatTile(value: String(format: "%.2f", acc.brier), label: "Brier (lower = sharper)", symbol: "scope", accent: acc.beatsCoinFlip ? IFMTheme.green : IFMTheme.orange)
                }
                Text(verdict(acc))
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(buildingCopy(acc))
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
            }
        }
    }

    private func buildingCopy(_ acc: ForecastAccuracy) -> String {
        if acc.resolvedCount == 0 && acc.openCount == 0 {
            return "No bets yet. When ideas reach Ready and you record what happened (Shipped / Built / Abandoned / Flopped), the app starts grading its own calls."
        }
        if acc.resolvedCount == 0 {
            return "Watching \(acc.openCount) Ready call\(acc.openCount == 1 ? "" : "s"). Record what happens when you build them and the app can start scoring itself."
        }
        return "\(acc.resolvedCount) call\(acc.resolvedCount == 1 ? "" : "s") played out so far — need about 5 before a hit-rate means anything."
    }

    private func verdict(_ acc: ForecastAccuracy) -> String {
        if acc.brier < 0.18 { return "Better than a coin flip — when it says Ready, it's usually right. Trust the funnel." }
        if acc.brier < 0.25 { return "A bit better than a coin flip. The Ready bar is roughly calibrated." }
        return "About a coin flip or worse — the Ready bar looks over-confident. Treat “Ready” as a suggestion, not a verdict, for now."
    }
}

struct ScoutFocusCard: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        let focus = model.scoutFocus
        return SectionCard("Scout Focus", subtitle: "What the scout hunts for — tuned from what you actually build and keep, not just your written query.", symbol: "scope", accent: IFMTheme.green) {
            if focus.isEmpty {
                Text("Searching your missions as written for now. Record a build outcome or mark ideas Ready, and the scout starts leaning toward your proven themes and away from lanes you've abandoned.")
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .padding(.vertical, 2)
            } else {
                if !focus.focusTerms.isEmpty {
                    focusRow(title: "Hunting harder for", color: IFMTheme.green, terms: focus.focusTerms)
                }
                if !focus.avoidTerms.isEmpty {
                    focusRow(title: "Steering away from", color: IFMTheme.red, terms: focus.avoidTerms)
                }
            }
        }
    }

    private func focusRow(title: String, color: Color, terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(terms, id: \.self) { term in
                        Pill(text: ifmDisplayTerm(term), color: color)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

struct AutonomyRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: IFMSpacing.md) {
            Text("The Mind").font(.ifmSectionTitle)
            // Status lives on the Overview hero; the rail carries the at-a-glance numbers.
            SectionCard("State", symbol: "waveform.path.ecg", accent: IFMTheme.purple, padding: IFMSpacing.sm) {
                StatusRow(title: "Mode", isGood: model.autonomyProfile.isEnabled, goodText: "On", badText: "Off")
                StatRow(title: "Thoughts", value: "\(model.thoughtCount)", accent: IFMTheme.purple)
                StatRow(title: "Connections", value: "\(model.connectionCount)", accent: IFMTheme.blue)
                StatRow(title: "Active missions", value: "\(model.scoutMissions.filter(\.isEnabled).count)", accent: IFMTheme.green)
                StatRow(title: "Spent today", value: String(format: "$%.2f", model.spentTodayUSD), accent: IFMTheme.text)
            }
            SectionCard("Search Stack", symbol: "magnifyingglass", accent: IFMTheme.slate, padding: IFMSpacing.sm) {
                StatusRow(title: "Firecrawl", isGood: model.hasKey(.firecrawl), goodText: "Ready", badText: "No key")
                StatusRow(title: "OpenAI web", isGood: model.hasKey(.openAI), goodText: "Ready", badText: "No key")
                StatRow(title: "Public fallback", value: "Always", accent: IFMTheme.green)
            }
            SectionCard("What it does", symbol: "list.bullet.rectangle", accent: IFMTheme.slate, padding: IFMSpacing.sm) {
                Text("Reasons across your ideas, connects them into a web, generates new ones, then critiques its own thinking — on its own, within your caps.")
                    .font(.ifmCaption)
                    .foregroundStyle(IFMTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CostCenterPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingApproveAll = false

    var body: some View {
        PageScaffold(title: "Cost Center", subtitle: "Spend, queue, approvals, and routing.", symbol: "chart.pie", accent: IFMTheme.blue) {
            VStack(spacing: 16) {
                let pendingPreview = model.pendingCloudPreview
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    metric("Total Spend", String(format: "$%.4f", model.metrics.totalSpend), IFMTheme.green)
                    metric("Pending Jobs", "\(model.metrics.pendingJobs)", IFMTheme.orange)
                    metric("Needs Approval", "\(model.metrics.approvalJobs)", IFMTheme.red)
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Queue").font(.headline)
                        if model.jobs.isEmpty {
                            Text("No jobs queued. Run local fermentation or queue a cloud loop from the incubator.")
                                .foregroundStyle(IFMTheme.muted)
                        } else {
                            ForEach(model.jobs.prefix(20)) { job in
                                JobQueueRow(model: model, job: job)
                                Divider()
                            }
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                Button("Queue Cloud Loop") { model.queueFermentationLoop() }
                                Button("Approve All…") { confirmingApproveAll = true }
                                    .disabled(model.metrics.approvalJobs == 0)
                                Button { model.runNextCloudJob() } label: {
                                    HStack(spacing: 6) {
                                        if model.isRunningJob { ProgressView().controlSize(.small) }
                                        Text(model.isRunningJob ? "Running…" : "Run Next Cloud Job")
                                    }
                                }
                                .disabled(model.isRunningJob)
                            }
                        }
                        .scrollIndicators(.never)
                    }
                }
                if let pendingPreview {
                    CloudPayloadPreviewCard(preview: pendingPreview) {
                        model.approveJob(pendingPreview.job)
                    }
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scheduler").font(.headline)
                        Label("Runs while this app is open", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                        Toggle("Allow capped auto-cloud", isOn: Binding(
                            get: { model.schedulerSettings.cloudAutoRun },
                            set: { enabled in
                                var settings = model.schedulerSettings
                                settings.cloudAutoRun = enabled
                                model.updateScheduler(settings)
                            }
                        ))
                        HStack {
                            Text("Local cadence")
                            Spacer()
                            Text("\(model.schedulerSettings.localCadenceMinutes) min")
                                .foregroundStyle(IFMTheme.muted)
                        }
                        capStepper(
                            title: "Daily cap",
                            value: model.schedulerSettings.dailySpendCapUSD,
                            step: 0.50,
                            update: { model.updateDailySpendCap(String($0)) }
                        )
                        capStepper(
                            title: "Monthly cap",
                            value: model.schedulerSettings.monthlySpendCapUSD,
                            step: 5,
                            update: { model.updateMonthlySpendCap(String($0)) }
                        )
                        Button("Run Scheduler Now") { model.runSchedulerNow() }
                            .buttonStyle(.borderedProminent)
                    }
                    .font(.system(size: 14))
                }
            }
            .confirmationDialog(
                "Approve all \(model.metrics.approvalJobs) cloud job(s)?",
                isPresented: $confirmingApproveAll,
                titleVisibility: .visible
            ) {
                Button("Approve All Cloud Jobs", role: .destructive) { model.approveAllJobs() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Review the payload preview first. Never-send sources remain blocked.")
            }
        } rail: {
            RunHistoryRail(model: model)
        }
    }

    private func capStepper(title: String, value: Double, step: Double, update: @escaping (Double) -> Void) -> some View {
        Stepper(value: Binding(
            get: { value },
            set: { update(max(0, $0)) }
        ), in: 0...10_000, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "$%.2f", value))
                    .foregroundStyle(IFMTheme.muted)
                    .monospacedDigit()
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(value).font(.system(size: 28, weight: .bold)).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(IFMTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct JobQueueRow: View {
    @ObservedObject var model: ShellViewModel
    var job: FermentationJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                SymbolBadge(symbol: job.estimatedCostUSD > 0 ? "cloud" : "desktopcomputer", color: color, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.taskClass.rawValue).font(.system(size: 13, weight: .semibold))
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(IFMTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Pill(text: job.status.rawValue, color: color)
                Text(String(format: "$%.4f", job.estimatedCostUSD))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(IFMTheme.muted)
                    .frame(width: 64, alignment: .trailing)
                controls
            }
            if let lastError = job.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.orange)
                    .lineLimit(2)
                    .padding(.leading, 38)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        var parts = [job.ideaID != nil ? "Idea job" : job.sourceID != nil ? "Source job" : "System job"]
        if let route = job.modelRoute {
            parts.append("\(route.provider) / \(route.model)")
        }
        if job.retryCount > 0 {
            parts.append("retry \(job.retryCount)")
        }
        return parts.joined(separator: " • ")
    }

    @ViewBuilder
    private var controls: some View {
        switch job.status {
        case .needsApproval:
            Button("Approve") { model.approveJob(job) }
                .buttonStyle(.bordered)
        case .pending:
            Button("Pause") { model.pauseJob(job) }
                .buttonStyle(.bordered)
        case .paused:
            Button("Resume") { model.resumeJob(job) }
                .buttonStyle(.borderedProminent)
        case .failed:
            Button("Retry") { model.retryJob(job) }
                .buttonStyle(.bordered)
        case .running:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                Text("Running")
                    .font(.caption.bold())
                    .foregroundStyle(IFMTheme.blue)
            }
        case .complete:
            EmptyView()
        }
    }

    private var color: Color {
        switch job.status {
        case .needsApproval: IFMTheme.red
        case .failed, .paused: IFMTheme.orange
        case .running: IFMTheme.blue
        case .complete: IFMTheme.gray
        case .pending: IFMTheme.green
        }
    }
}

struct CloudPayloadPreviewCard: View {
    var preview: PendingCloudPreview
    var approve: () -> Void

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cloud Payload Preview").font(.headline)
                        Text("\(preview.payload.taskClass.rawValue) • \(preview.payload.characterCount) characters")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                    }
                    Spacer()
                    Pill(text: String(format: "$%.4f", preview.job.estimatedCostUSD), color: preview.job.estimatedCostUSD > 0 ? IFMTheme.orange : IFMTheme.green)
                }
                if preview.payload.blockedSourceTitles.isEmpty {
                    Label("No never-send sources included.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.green)
                } else {
                    Label("Blocked: \(preview.payload.blockedSourceTitles.joined(separator: ", "))", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.orange)
                        .lineLimit(2)
                }
                ScrollView {
                    Text(preview.payload.payload.isEmpty ? "Nothing can be sent for this job because all material is blocked." : preview.payload.payload)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(IFMTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 120, maxHeight: 180)
                .background(IFMTheme.scrim.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
                HStack {
                    Text(preview.payload.maySend ? "Review before approving cloud synthesis." : "Cloud approval is blocked by privacy settings.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Button("Approve This Job", action: approve)
                        .buttonStyle(.borderedProminent)
                        .disabled(!preview.payload.maySend)
                }
            }
        }
    }
}

struct PrivacyCenterPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Privacy Center", subtitle: "What stays local and what can be sent to providers.", symbol: "lock.shield", accent: IFMTheme.green) {
            VStack(alignment: .leading, spacing: 16) {
                let pendingPreview = model.pendingCloudPreview
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    privacyStat("Local records", "\(model.ideas.count + model.sources.count)")
                    privacyStat("Never-send", "\(model.sources.filter(\.neverSendToCloud).count)")
                    privacyStat("Cloud spend", String(format: "$%.4f", model.metrics.totalSpend))
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local-first defaults").font(.headline)
                        privacyBullet("Ideas, sources, embeddings, queues, logs, and cache live on this Mac.")
                        privacyBullet("API keys are stored in macOS Keychain.")
                        privacyBullet("Sources marked never-send are excluded from cloud payload previews.")
                    }
                }
                if let pendingPreview {
                    CloudPayloadPreviewCard(preview: pendingPreview) {
                        model.approveJob(pendingPreview.job)
                    }
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Never-send sources").font(.headline)
                        let blocked = model.sources.filter(\.neverSendToCloud)
                        if blocked.isEmpty {
                            Text("No source is currently blocked from cloud use.")
                                .foregroundStyle(IFMTheme.muted)
                        } else {
                            ForEach(blocked) { source in
                                PrivacyBlockedSourceRow(
                                    source: source,
                                    allowCloudUse: { model.toggleNeverSend(source) },
                                    open: { model.openSource(source) }
                                )
                                Divider().opacity(0.45)
                            }
                        }
                    }
                }
            }
        } rail: {
            PrivacySummaryRail(model: model)
        }
    }

    private func privacyStat(_ title: String, _ value: String) -> some View {
        IFMCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(IFMTheme.green)
                Text(title).font(.caption).foregroundStyle(IFMTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func privacyBullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(IFMTheme.green)
    }
}

struct PrivacyBlockedSourceRow: View {
    var source: SourceItem
    var allowCloudUse: () -> Void
    var open: () -> Void
    @State private var confirmingAllow = false

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: "lock.fill", color: IFMTheme.orange, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(source.type.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                Text(source.body.isEmpty ? "No extracted text." : source.body)
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Button("Open", action: open)
                .buttonStyle(.bordered)
            Button("Allow Cloud Use") { confirmingAllow = true }
                .buttonStyle(.borderedProminent)
                .tint(IFMTheme.green)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Allow cloud use for \(source.title)?",
            isPresented: $confirmingAllow,
            titleVisibility: .visible
        ) {
            Button("Allow Cloud Use", action: allowCloudUse)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Future payload previews may include this source. You can mark it never-send again from Sources.")
        }
    }
}

struct RunHistoryRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Run History").font(.system(size: 18, weight: .bold))
            if model.logs.isEmpty {
                Text("No agent runs yet.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
            } else {
                ForEach(model.logs.prefix(8)) { log in
                    IFMCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(log.agentName).font(.caption.bold())
                            Text(log.output).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(3)
                            Text(log.modelUsed).font(.caption2).foregroundStyle(IFMTheme.slate)
                        }
                    }
                }
            }
        }
    }
}

struct PrivacySummaryRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy Summary").font(.system(size: 18, weight: .bold))
            stat("Ideas", "\(model.ideas.count)")
            stat("Sources", "\(model.sources.count)")
            stat("Never-send", "\(model.sources.filter(\.neverSendToCloud).count)")
            stat("Cached model outputs", "\(model.logs.count)")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        IFMCard(padding: 12) {
            HStack {
                Text(title)
                Spacer()
                Text(value).font(.headline)
            }
        }
    }
}

@MainActor
func chooseSourceFile(model: ShellViewModel) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image, .text, .plainText, .pdf, .json, .commaSeparatedText]
    if panel.runModal() == .OK {
        for url in panel.urls {
            model.importFile(url: url)
        }
        model.activeSheet = nil
    }
}
