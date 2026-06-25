import AppKit
import IdeaFermentationCore
import SwiftUI
import UniformTypeIdentifiers

public struct IdeaFermentationRootView: View {
    @StateObject private var model: ShellViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var toastDismiss: Task<Void, Never>?

    public init(store: IdeaStore, captureServer: CaptureServer? = nil) {
        _model = StateObject(wrappedValue: ShellViewModel(store: store, captureServer: captureServer))
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.55)
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 236)
                Divider().opacity(0.45)
                pageBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(model.selectedPage)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : IFMMotion.standard, value: model.selectedPage)
        }
        .frame(minWidth: 1040, maxWidth: .infinity, minHeight: 680, maxHeight: .infinity)
        .background(IFMTheme.canvas)
        .foregroundStyle(IFMTheme.text)
        .tint(IFMTheme.green)
        .overlay(alignment: .top) {
            if let message = model.errorMessage {
                ToastBanner(message: message, tone: ToastTone.classify(message)) {
                    dismissToast()
                }
                .padding(.top, 64)
                .padding(.horizontal, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : IFMMotion.spring, value: model.errorMessage)
        .onChange(of: model.errorMessage) { _, message in
            scheduleToastDismiss(for: message)
        }
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .idea:
                IdeaCaptureSheet(model: model)
            case .source:
                SourceCaptureSheet(model: model)
            case .keys:
                ProviderKeysSheet(model: model)
            case .outcome:
                BuildOutcomeSheet(model: model)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ifmFocusSearch)) { _ in
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .ifmNewIdea)) { _ in
            model.startIdeaCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ifmNewSource)) { _ in
            model.startSourceCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ifmRefresh)) { _ in
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ifmRunLocalPass)) { _ in
            model.runLocalFermentation()
        }
    }

    /// Auto-dismiss transient successes/notices after a few seconds; leave errors
    /// up until the operator dismisses them or a newer message replaces them.
    private func scheduleToastDismiss(for message: String?) {
        toastDismiss?.cancel()
        guard let message, ToastTone.classify(message).autoDismiss else { return }
        toastDismiss = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, model.errorMessage == message else { return }
            withAnimation(reduceMotion ? nil : IFMMotion.spring) { model.errorMessage = nil }
        }
    }

    private func dismissToast() {
        toastDismiss?.cancel()
        withAnimation(reduceMotion ? nil : IFMMotion.spring) { model.errorMessage = nil }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "flask")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(IFMTheme.green)
                    .frame(width: 28, height: 28)
                    .background(IFMTheme.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
                    .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.green.opacity(0.16)) }
                Text("Idea Fermentation Machine")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(width: 236, alignment: .leading)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(IFMTheme.muted)
                TextField("Search ideas, notes, or sources...", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { model.reload() }
                    .onChange(of: model.searchText) { _, newValue in
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.reload() }
                    }
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                        model.reload()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(IFMTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
                Text("⌘K")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(searchFocused ? IFMTheme.green : IFMTheme.muted)
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 220, idealWidth: 390, maxWidth: 470, minHeight: 34, maxHeight: 34)
            .background(IFMTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
            .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.80)) }
            .accessibilityLabel("Search ideas notes or sources")

            Spacer(minLength: 10)

            Button {
                model.selectedPage == .sources ? model.startSourceCapture() : model.startIdeaCapture()
            } label: {
                Label(model.selectedPage == .sources ? "Add Source" : "Add Idea", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityLabel(model.selectedPage == .sources ? "Add source" : "Add idea")

            toolbarIcon("clock.arrow.circlepath", "Refresh") { model.reload() }
            toolbarIcon(model.metrics.approvalJobs > 0 ? "bell.badge" : "bell", "Pending approvals") { model.showNotifications() }
            toolbarIcon("gearshape", "Settings") { model.selectedPage = .settings }
            Menu {
                Button("Settings") { model.selectedPage = .settings }
                Button("Privacy Center") { model.selectedPage = .privacyCenter }
                Button("Cost Center") { model.selectedPage = .costCenter }
            } label: {
                Circle()
                    .fill(IFMTheme.slate)
                    .frame(width: 28, height: 28)
                    .overlay(Text("C").font(.caption.bold()).foregroundStyle(IFMTheme.onAccent))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Workspace menu")
            .accessibilityLabel("Workspace menu")
        }
        .padding(.leading, 78)
        .padding(.trailing, 14)
        .frame(height: 56)
        .background(IFMTheme.panelStrong)
    }

    private func toolbarIcon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
                .ifmHover(restingOpacity: 0.030, hoverOpacity: 0.095)
                .contentShape(RoundedRectangle(cornerRadius: IFMRadius.md))
        }
        .buttonStyle(IFMPressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 6) {
                        ForEach([IFMPage.inbox, .fermenting, .ripening, .ready, .archive]) { page in
                            navButton(page)
                        }
                    }
                    .padding(.top, 14)

                    Divider().padding(.vertical, 14)

                    sectionLabel("Discover")

                    VStack(spacing: 6) {
                        navButton(.sources)
                        navButton(.patterns)
                    }

                    Divider().padding(.vertical, 14)

                    sectionLabel("Operate")

                    VStack(spacing: 6) {
                        navButton(.autonomy)
                        navButton(.costCenter)
                        navButton(.privacyCenter)
                        navButton(.settings)
                    }
                }
            }
            .scrollIndicators(.automatic)

            Divider().opacity(0.45)

            incubatorStatus
                .padding(12)
        }
        .background(IFMTheme.canvas)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(IFMTheme.muted)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
    }

    private var incubatorStatus: some View {
        IFMCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Incubator Status")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                }
                Label(
                    model.ideas.isEmpty ? "Idle" : (model.metrics.pendingJobs == 0 ? "Healthy" : "Jobs pending"),
                    systemImage: "circle.fill"
                )
                .font(.caption)
                .foregroundStyle(model.ideas.isEmpty ? IFMTheme.muted : IFMTheme.green)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Diversity")
                        Spacer()
                        Text("\(Int(model.metrics.diversity * 100))%")
                    }
                    .font(.caption)
                    MiniProgress(value: model.metrics.diversity)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Incubation Load")
                        Spacer()
                        Text("\(Int(model.metrics.incubationLoad * 100))%")
                    }
                    .font(.caption)
                    MiniProgress(value: model.metrics.incubationLoad)
                }
                Button { model.runLocalFermentation() } label: {
                    Label("Run Local Pass", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Run local fermentation pass")
            }
        }
    }

    private func navButton(_ page: IFMPage) -> some View {
        SidebarNavButton(model: model, page: page)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch model.selectedPage {
        case .inbox:
            InboxPage(model: model)
        case .fermenting:
            FermentingPage(model: model)
        case .ripening:
            RipeningPage(model: model)
        case .ready:
            ReadyPage(model: model)
        case .archive:
            ArchivePage(model: model)
        case .sources:
            SourcesPage(model: model)
        case .patterns:
            PatternsPage(model: model)
        case .autonomy:
            AutonomyPage(model: model)
        case .settings:
            SettingsPage(model: model)
        case .costCenter:
            CostCenterPage(model: model)
        case .privacyCenter:
            PrivacyCenterPage(model: model)
        }
    }
}

/// One sidebar navigation row. Extracted so it can own its own hover state — macOS
/// users expect the pointer to light up rows — and animate selection changes.
struct SidebarNavButton: View {
    @ObservedObject var model: ShellViewModel
    var page: IFMPage
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSelected: Bool { model.selectedPage == page }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : IFMMotion.quick) { model.selectedPage = page }
        } label: {
            HStack(spacing: 10) {
                if isSelected {
                    Capsule()
                        .fill(page.accent)
                        .frame(width: 3, height: 28)
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: page.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(page.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? page.accent : IFMTheme.text)
                    Text(page.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(IFMTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                if model.count(for: page) > 0 {
                    Text("\(model.count(for: page))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? page.accent : IFMTheme.muted)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((isSelected ? page.accent : IFMTheme.slate).opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: IFMRadius.md).stroke(page.accent.opacity(0.20))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: IFMRadius.md))
        }
        .buttonStyle(IFMPressableButtonStyle())
        .padding(.horizontal, 12)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : IFMMotion.quick, value: hovering)
        .accessibilityLabel(page.title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint(page.subtitle)
    }

    private var rowBackground: Color {
        if isSelected { return page.accent.opacity(0.105) }
        return hovering ? IFMTheme.scrim.opacity(0.05) : Color.clear
    }
}

struct PageScaffold<Main: View, Rail: View>: View {
    var title: String
    var subtitle: String
    var symbol: String?
    var accent: Color
    @ViewBuilder var main: Main
    @ViewBuilder var rail: Rail

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            SymbolBadge(symbol: symbol ?? "square.grid.2x2", color: accent, size: 38)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.system(size: 26, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(IFMTheme.muted)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 12)
                        }
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(accent.opacity(0.18))
                                .frame(width: 76, height: 2)
                                .offset(y: 4)
                        }
                        main
                    }
                    .padding(.horizontal, proxy.size.width < 760 ? 16 : 22)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(IFMTheme.canvas)

                if proxy.size.width >= 980 {
                    Divider().opacity(0.45)

                    ScrollView {
                        rail
                            .padding(14)
                    }
                    .scrollIndicators(.automatic)
                    .frame(width: min(310, max(276, proxy.size.width * 0.27)))
                    .frame(maxHeight: .infinity)
                    .background(IFMTheme.panel.opacity(0.64))
                }
            }
        }
    }
}

struct InboxPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Idea Inbox", subtitle: "Capture anything. We'll turn it into seeds for future breakthroughs.", symbol: nil, accent: IFMTheme.green) {
            VStack(spacing: 16) {
                IFMCard(padding: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "sprout")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(IFMTheme.green)
                        Text("Drop a seed")
                            .font(.system(size: 20, weight: .bold))
                        Text("Add a half-baked idea, thought, screenshot, link, or note.")
                            .font(.system(size: 13))
                            .foregroundStyle(IFMTheme.muted)
                            .multilineTextAlignment(.center)
                        Pill(text: "Everything enters the incubation.", color: IFMTheme.green)
                    }
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .overlay {
                        RoundedRectangle(cornerRadius: IFMRadius.md)
                            .stroke(IFMTheme.green.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                        guard let data else { return }
                        let fallbackURL = String(data: data, encoding: .utf8)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .flatMap(URL.init(string:))
                        guard let url = URL(dataRepresentation: data, relativeTo: nil) ?? fallbackURL else { return }
                        Task { @MainActor in model.importFile(url: url) }
                    }
                    return true
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 10)], spacing: 10) {
                    captureButton("Voice Note", "Paste transcript", "mic", IFMTheme.gray) { model.startSourceCapture(type: .voiceMemo) }
                    captureButton("Screenshot", "Import image", "camera.viewfinder", IFMTheme.blue) { chooseSourceFile(model: model) }
                    captureButton("Link", "Save a URL", "link", IFMTheme.green) { model.startSourceCapture(type: .link) }
                    captureButton("Note", "Write something", "doc.text", IFMTheme.orange) { model.startIdeaCapture() }
                    captureButton("Sketch", "Import file", "pencil.and.scribble", IFMTheme.blue) { chooseSourceFile(model: model) }
                }

                HStack {
                    Text("Newly Captured")
                        .font(.headline)
                    Text("\(model.inbox.items.count) Items")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Spacer()
                }

                if model.inbox.items.isEmpty {
                    EmptyStateCard(title: "No ideas yet", message: "Add your first seed or import a source. The workspace starts clean.", symbol: "sprout", actionTitle: "Add Idea") {
                        model.startIdeaCapture()
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.inbox.items.prefix(20)) { idea in
                            IdeaInboxRow(model: model, idea: idea)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
                    .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                }
            }
        } rail: {
            RawMaterialRail(sources: model.inbox.rawMaterial)
        }
    }

    private func captureButton(_ title: String, _ subtitle: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                SymbolBadge(symbol: symbol, color: color, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(IFMTheme.muted).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 66)
            .frame(maxWidth: .infinity)
            .background(IFMTheme.panelStrong)
            .ifmContainer(stroke: IFMTheme.border.opacity(0.75))
            .ifmTileShadow()
        }
        .buttonStyle(IFMPressableButtonStyle())
        .ifmHover(hoverOpacity: 0.04)
        .accessibilityLabel(title)
    }
}

struct IdeaInboxRow: View {
    @ObservedObject var model: ShellViewModel
    var idea: IdeaSeed

    /// Honest ripeness tier (the value the row actually carries), shown instead of an
    /// always-green "Fresh" that ignored the data.
    private var ripenessTier: (label: String, color: Color) {
        if idea.ripeness >= 55 { return ("Ripe", IFMTheme.green) }
        if idea.ripeness >= 30 { return ("Maturing", IFMTheme.orange) }
        return ("Fresh", IFMTheme.muted)
    }

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: idea.manualTags.contains("audio") ? "headphones" : "sparkles", color: idea.status == .inbox ? IFMTheme.green : IFMTheme.orange, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(idea.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Circle().fill(ripenessTier.color).frame(width: 6, height: 6)
                    Spacer()
                    Text(idea.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                }
                Text(idea.body)
                    .font(.system(size: 13))
                    .foregroundStyle(IFMTheme.muted)
                    .lineLimit(2)
                HStack {
                    ForEach(idea.manualTags.prefix(4), id: \.self) { tag in
                        Pill(text: tag, color: IFMTheme.slate)
                    }
                    Spacer()
                    FreshnessDots(score: idea.ripeness)
                    Text(ripenessTier.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ripenessTier.color)
                    IdeaActionsMenu(model: model, idea: idea)
                }
            }
        }
        .padding(10)
        .background(IFMTheme.panelStrong)
        Divider().padding(.leading, 86)
    }
}

struct IdeaActionsMenu: View {
    @ObservedObject var model: ShellViewModel
    var idea: IdeaSeed
    @State private var confirmingDelete = false

    var body: some View {
        Menu {
            Button("Move to Fermenting") { model.moveIdeaToFermenting(idea) }
            Button("Mark Ready") { model.markIdeaReady(idea) }
            if model.buildPlan(for: idea) == nil {
                Button("Create Build Plan") { model.createBuildPlan(for: idea) }
            } else {
                Button("Open Build Plan") { model.openBuildPlan(for: idea) }
            }
            Button("Record Build Outcome…") { model.startBuildOutcome(for: idea) }
            Button("Archive") { model.archiveIdea(idea) }
            Button("Duplicate") { model.duplicateIdea(idea) }
            Divider()
            Button("Delete", role: .destructive) { confirmingDelete = true }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(IFMTheme.muted)
                .frame(width: 28, height: 24)
        }
        .menuStyle(.borderlessButton)
        .help("Idea actions")
        .accessibilityLabel("Idea actions")
        .confirmationDialog(
            "Delete “\(idea.title)”?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Idea", role: .destructive) { model.deleteIdea(idea) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the idea from the local database.")
        }
    }
}

struct FreshnessDots: View {
    var score: Double

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Double(index) < score / 25 ? IFMTheme.green : IFMTheme.scrim.opacity(0.08))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct RawMaterialRail: View {
    var sources: [SourceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Today's Raw Material")
                .font(.system(size: 18, weight: .bold))
            Text("Everything captured today that can feed new ideas.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
            HStack {
                Pill(text: "All", color: IFMTheme.green)
                Pill(text: "Notes \(sources.filter { $0.type == .note }.count)", color: IFMTheme.slate)
                Pill(text: "Screens \(sources.filter { $0.type == .screenshot }.count)", color: IFMTheme.slate)
                Pill(text: "Links \(sources.filter { $0.type == .link || $0.type == .article }.count)", color: IFMTheme.slate)
            }
            RailSection(title: "Notes", count: sources.filter { $0.type == .note }.count) {
                ForEach(sources.filter { $0.type == .note }.prefix(3)) { source in
                    SourceMiniCard(source: source)
                }
            }
            RailSection(title: "Links", count: sources.filter { $0.type == .link }.count) {
                ForEach(sources.filter { $0.type == .link || $0.type == .article }.prefix(3)) { source in
                    SourceMiniCard(source: source)
                }
            }
            if sources.isEmpty {
                Text("No sources captured today.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }
}

struct FermentingPage: View {
    @ObservedObject var model: ShellViewModel

    var columns: [(FermentationStage, Color, [IdeaSeed])] {
        [
            (.cooling, IFMTheme.blue, model.fermenting.items.filter { $0.stage == .cooling }),
            (.brewing, IFMTheme.orange, model.fermenting.items.filter { $0.stage == .brewing }),
            (.crossPollinating, IFMTheme.purple, model.fermenting.items.filter { $0.stage == .crossPollinating }),
            (.needsDistance, IFMTheme.red, model.fermenting.items.filter { $0.stage == .needsDistance })
        ]
    }

    var body: some View {
        PageScaffold(title: "Fermenting", subtitle: "\(model.fermenting.items.count) ideas in incubation", symbol: "flask", accent: IFMTheme.green) {
            VStack(spacing: 18) {
                if model.fermenting.items.isEmpty {
                    EmptyStateCard(title: "No ideas fermenting", message: "Add ideas, then run a local fermentation pass to move them out of Inbox.", symbol: "flask", actionTitle: "Run Local Pass") {
                        model.runLocalFermentation()
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(columns, id: \.0) { stage, color, ideas in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: stage == .cooling ? "snowflake" : stage == .brewing ? "mug" : stage == .crossPollinating ? "link" : "moon")
                                            .foregroundStyle(color)
                                        Text(stage.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(color)
                                        Spacer()
                                        Text("\(ideas.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(color)
                                    }
                                    Text(stage == .cooling ? "Letting insights settle" : stage == .brewing ? "Building momentum" : stage == .crossPollinating ? "Connecting distant dots" : "Steeping in the background")
                                        .font(.caption)
                                        .foregroundStyle(IFMTheme.muted)
                                    ForEach(ideas.prefix(3)) { idea in
                                        FermentingCard(model: model, idea: idea, color: color)
                                    }
                                    Button { model.startIdeaCapture() } label: { Label("Add Idea", systemImage: "plus") }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(color)
                                }
                                .padding(14)
                                .frame(width: 230, alignment: .top)
                                .background(color.opacity(0.045))
                                .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
                                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(color.opacity(0.24)) }
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                    FermentationDetailCard(model: model, idea: model.fermenting.items.first)
                    IncubationTimeline(model: model)
                }
            }
        } rail: {
            IncubatorControlsRail(model: model)
        }
    }
}

struct FermentingCard: View {
    @ObservedObject var model: ShellViewModel
    var idea: IdeaSeed
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(idea.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .frame(height: 36, alignment: .topLeading)
                Spacer()
                Pill(text: "\(Int(idea.ripeness))%", color: color)
                IdeaActionsMenu(model: model, idea: idea)
            }
            Text("Last updated \(idea.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
                .lineLimit(1)
            Text(question(for: idea))
                .font(.system(size: 13))
                .lineLimit(3)
                .frame(height: 48, alignment: .topLeading)
            HStack {
                ForEach(idea.manualTags.prefix(2), id: \.self) { tag in Pill(text: tag, color: color) }
                Pill(text: "+\(max(1, idea.sourceIDs.count))", color: IFMTheme.slate)
            }
        }
        .padding(12)
        .frame(height: 154, alignment: .top)
        .background(IFMTheme.panelStrong)
        .ifmContainer()
    }

    private func question(for idea: IdeaSeed) -> String {
        switch idea.stage {
        case .cooling:
            "What source would make this idea more concrete?"
        case .brewing:
            "What signal has strengthened since the last revisit?"
        case .crossPollinating:
            "Which adjacent idea or source should this connect to?"
        case .needsDistance:
            "What assumption should wait before spending attention?"
        case .readyToPrototype:
            "What is the smallest test that proves the core loop?"
        case .seed:
            "What would make this worth incubating?"
        }
    }
}

struct FermentationDetailCard: View {
    @ObservedObject var model: ShellViewModel
    var idea: IdeaSeed?

    var body: some View {
        guard let idea else {
            return AnyView(EmptyView())
        }
        return AnyView(
            IFMCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 18) {
                        SymbolBadge(symbol: "flask", color: IFMTheme.orange, size: 58)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(idea.title)
                                .font(.system(size: 24, weight: .bold))
                            Text(idea.body)
                                .font(.system(size: 14))
                                .foregroundStyle(IFMTheme.muted)
                            Text("\(idea.stage.title)  •  Added \(idea.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(IFMTheme.muted)
                        }
                        Spacer()
                        RipenessRing(score: idea.ripeness, color: IFMTheme.orange)
                    }
                    .padding(18)
                    HStack {
                        Button("Queue Critique") { model.queueCritique(for: idea) }
                        Button("Queue Prototype Brief") { model.queuePrototypeBrief(for: idea) }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    Divider()
                    let critique = model.critique(for: idea)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 0)], spacing: 0) {
                        DetailPane(title: "Signals", symbol: "sun.max", color: IFMTheme.orange, lines: idea.manualTags.isEmpty ? ["Add tags or sources to strengthen the signal."] : idea.manualTags)
                        DetailPane(title: "Evidence", symbol: "doc.text", color: IFMTheme.green, lines: ["\(idea.sourceIDs.count) linked sources", "Evidence score \(Int(idea.evidence))"])
                        DetailPane(title: "Contradictions", symbol: "exclamationmark.triangle", color: IFMTheme.red, lines: critique.map { $0.contradictions + $0.risks } ?? ["Queue critique to surface objections."])
                        DetailPane(title: "Next Experiment", symbol: "bolt", color: IFMTheme.blue, lines: critique?.assumptions.isEmpty == false ? critique!.assumptions : ["Queue a prototype brief when ready."])
                        DetailPane(title: "Readiness", symbol: "chart.line.uptrend.xyaxis", color: IFMTheme.purple, lines: ["Ripeness \(Int(idea.ripeness))", "Feasibility \(Int(idea.feasibility))"])
                        DetailPane(title: "Privacy", symbol: "lock.shield", color: IFMTheme.slate, lines: ["Preview cloud payloads before sending."])
                    }
                }
            }
        )
    }
}

struct DetailPane: View {
    var title: String
    var symbol: String
    var color: Color
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(IFMTheme.text)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(color.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.72)) }
    }
}

struct IncubationTimeline: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("How Incubation Works")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "info.circle").foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Button("Open Scheduler") { model.showScheduler() }
                }
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(["Captured", "Local Pass", "Queued", "Reviewed", "Ready"], id: \.self) { label in
                            VStack(spacing: 8) {
                                Circle()
                                    .stroke(IFMTheme.orange, lineWidth: 2)
                                    .frame(width: 18, height: 18)
                                Text(label)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            if label != "Ready" {
                                Rectangle().fill(IFMTheme.border).frame(width: 96, height: 1)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}

struct IncubatorControlsRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Incubator Controls")
                .font(.system(size: 20, weight: .bold))
            Label(model.metrics.pendingJobs == 0 ? "Idle" : "Jobs pending", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(IFMTheme.green)
            control("Diversity", "\(Int(model.metrics.diversity * 100))%", model.metrics.diversity)
            control("Incubation Load", "\(Int(model.metrics.incubationLoad * 100))%", model.metrics.incubationLoad)
            control("Average Ripeness", "\(Int(model.metrics.averageRipeness))", min(1, model.metrics.averageRipeness / 100))
            IFMCard {
                HStack {
                    SymbolBadge(symbol: "house", color: IFMTheme.green)
                    VStack(alignment: .leading) {
                        Text("Incubator Mode").font(.system(size: 14, weight: .semibold))
                        Text("Local first\nCloud jobs require keys and approval.").font(.caption).foregroundStyle(IFMTheme.muted)
                    }
                    Spacer()
                }
            }
            Button { model.runLocalFermentation() } label: {
                Label("Run Local Pass", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { model.queueFermentationLoop() } label: {
                Label("Queue Cloud Loop", systemImage: "cloud")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            IFMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Activity").font(.headline)
                    Text("\(model.logs.count) agent runs\n\(model.metrics.pendingJobs) jobs pending\n\(model.metrics.approvalJobs) jobs need approval")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                }
            }
        }
    }

    private func control(_ title: String, _ value: String, _ progress: Double) -> some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Text(value).font(.caption).foregroundStyle(IFMTheme.muted)
                }
                Text("Balance new inputs vs. existing knowledge.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
                MiniProgress(value: progress)
                HStack { Text("Low"); Spacer(); Text("High") }
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }
}

struct RipeningPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Ripening", subtitle: "Ideas gaining traction. Pay attention—some are ready to grow.", symbol: "sun.max", accent: IFMTheme.orange) {
            VStack(spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    metric("\(model.ripening.items.count)", "Ripening", "Ideas showing strong momentum", IFMTheme.orange, values: model.ripening.items.map(\.ripeness))
                    metric("\(model.logs.count)", "Agent Runs", "Recorded local or cloud passes", IFMTheme.purple, values: model.logs.enumerated().map { Double($0.offset + 1) })
                    metric("\(Int(model.metrics.averageRipeness))%", "Signal Strength", "Average across all active ideas", IFMTheme.green, values: model.ideas.map(\.ripeness))
                }
                if model.ripening.items.isEmpty {
                    EmptyStateCard(title: "Nothing is ripening yet", message: "Run a local pass after capturing a few real ideas. Items move here when their signal improves.", symbol: "sun.max", actionTitle: "Run Local Pass", accent: IFMTheme.orange) {
                        model.runLocalFermentation()
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(model.ripening.items.enumerated()), id: \.element.id) { index, idea in
                            RipeningRow(model: model, rank: index + 1, idea: idea)
                        }
                    }
                }
            }
        } rail: {
            WhatChangedRail(sources: model.ripening.changes)
        }
    }

    private func metric(_ value: String, _ title: String, _ subtitle: String, _ color: Color, values: [Double]) -> some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(color)
                    Text(title).font(.system(size: 14, weight: .semibold))
                }
                Text(subtitle).font(.caption).foregroundStyle(IFMTheme.muted)
                Sparkline(color: color, values: values.isEmpty ? [0, 0, 0] : values)
            }
        }
    }
}

struct RipeningRow: View {
    @ObservedObject var model: ShellViewModel
    var rank: Int
    var idea: IdeaSeed

    var body: some View {
        IFMCard(padding: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("\(rank)").font(.system(size: 30, weight: .bold)).foregroundStyle(IFMTheme.muted)
                    Text("\(Int(idea.ripeness))%").font(.caption.bold()).foregroundStyle(IFMTheme.green)
                }
                .frame(width: 56)
                .frame(maxHeight: .infinity)
                .background((rank == 1 ? IFMTheme.orange : rank == 2 ? IFMTheme.green : IFMTheme.purple).opacity(0.12))
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(idea.title).font(.system(size: 18, weight: .bold)).lineLimit(1)
                        Spacer()
                        IdeaActionsMenu(model: model, idea: idea)
                    }
                    Text(idea.body).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(3)
                    HStack { ForEach(idea.manualTags.prefix(3), id: \.self) { Pill(text: $0, color: IFMTheme.slate) } }
                    Text("Updated \(idea.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    HStack {
                        Button("Queue Critique") { model.queueCritique(for: idea) }
                        Button("Prototype Brief") { model.queuePrototypeBrief(for: idea) }
                    }
                    .font(.caption)
                }
                .padding(14)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        section("Why It’s Ripening", idea.manualTags.isEmpty ? ["Local pass found enough body text and source signal."] : idea.manualTags)
                        section("Evidence", ["\(idea.sourceIDs.count) linked sources", "Evidence \(Int(idea.evidence))"])
                        section("Contradictions", model.critique(for: idea).map { Array(($0.contradictions + $0.risks).prefix(3)) } ?? ["Queue critique to find objections."], danger: true)
                        section("Next Experiment", ["Queue a prototype brief or build plan."])
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                VStack(spacing: 8) {
                    Text("Ripeness").font(.caption).foregroundStyle(IFMTheme.muted)
                    Text("\(Int(idea.ripeness))").font(.system(size: 30, weight: .bold)).foregroundStyle(idea.ripeness > 65 ? IFMTheme.green : IFMTheme.orange)
                    Text(idea.ripeness > 65 ? "High" : "Medium").font(.caption.bold()).foregroundStyle(idea.ripeness > 65 ? IFMTheme.green : IFMTheme.orange)
                }
                .frame(width: 84)
            }
            .frame(minHeight: 142)
        }
    }

    private func section(_ title: String, _ lines: [String], danger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold())
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: danger ? "exclamationmark.triangle" : "checkmark")
                    .font(.caption)
                    .foregroundStyle(danger ? IFMTheme.red : IFMTheme.text)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct WhatChangedRail: View {
    var sources: [SourceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("What Changed").font(.system(size: 18, weight: .bold))
                Spacer()
                Pill(text: "\(sources.count)", color: IFMTheme.slate)
            }
            Text("Today").font(.caption).foregroundStyle(IFMTheme.muted)
            RailSection(title: "Screenshots", count: sources.filter { $0.type == .screenshot }.count) {
                ForEach(sources.filter { $0.type == .screenshot }.prefix(4)) { source in SourceTinyLine(source: source) }
            }
            RailSection(title: "Conversations", count: sources.filter { $0.type == .conversation }.count) {
                ForEach(sources.filter { $0.type == .conversation }.prefix(3)) { source in SourceTinyLine(source: source) }
            }
            RailSection(title: "Articles & Links", count: sources.filter { $0.type == .article || $0.type == .link }.count) {
                ForEach(sources.filter { $0.type == .article || $0.type == .link }.prefix(3)) { source in SourceTinyLine(source: source) }
            }
            RailSection(title: "Notes", count: sources.filter { $0.type == .note }.count) {
                ForEach(sources.filter { $0.type == .note }.prefix(2)) { source in SourceTinyLine(source: source) }
            }
            if sources.isEmpty {
                Text("No new source changes yet.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }
}

struct ReadyPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Ready To Build", subtitle: "Ideas that have ripened and are ready for prototyping.", symbol: nil, accent: IFMTheme.red) {
            VStack(spacing: 18) {
                if model.ready.items.isEmpty {
                    EmptyStateCard(title: "No ideas are ready yet", message: "Ready ideas appear after local scoring or cloud synthesis finds enough signal.", symbol: "sparkles", actionTitle: "Run Local Pass", accent: IFMTheme.red) {
                        model.runLocalFermentation()
                    }
                } else {
                    ForEach(model.ready.items.prefix(20)) { idea in
                        ReadyIdeaCard(model: model, idea: idea)
                    }
                }
            }
        } rail: {
            ReadyRail(model: model)
        }
    }
}

struct ReadyIdeaCard: View {
    @ObservedObject var model: ShellViewModel
    var idea: IdeaSeed

    var body: some View {
        let brief = model.buildPlan(for: idea)
        IFMCard(padding: 0) {
            HStack(spacing: 18) {
                ThumbnailCollage(seed: idea.title)
                    .frame(width: 218, height: 154)
                    .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(IFMTheme.red)
                        Text(idea.title).font(.system(size: 18, weight: .bold)).lineLimit(1)
                        Spacer()
                        Pill(text: "Readiness \(Int(idea.ripeness))", color: IFMTheme.red)
                        IdeaActionsMenu(model: model, idea: idea)
                    }
                    Text(idea.body)
                        .font(.system(size: 13))
                        .foregroundStyle(IFMTheme.text)
                        .lineLimit(3)
                    HStack(alignment: .top, spacing: 18) {
                        infoBlock("Signal", idea.manualTags.isEmpty ? "No tags yet." : idea.manualTags.joined(separator: ", "))
                        infoBlock("Evidence", "\(idea.sourceIDs.count) linked sources")
                        infoBlock("Readiness", "Ripeness \(Int(idea.ripeness)) · Feasibility \(Int(idea.feasibility))")
                    }
                    Divider()
                    HStack(alignment: .top) {
                        infoBlock("MVP Scope", brief?.mvpScope ?? "Write a smallest-test brief from this idea.")
                        infoBlock("Risk", model.critique(for: idea)?.risks.first ?? brief?.risks ?? "Run critique before building.")
                        infoBlock("First Prototype Steps", brief?.nextActions.prefix(3).joined(separator: " -> ") ?? "Create build plan -> define test -> ship smallest version")
                        Spacer()
                        VStack(spacing: 8) {
                            Button(brief == nil ? "Create Build Plan" : "Open Build Plan") {
                                brief == nil ? model.createBuildPlan(for: idea) : model.openBuildPlan(for: idea)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(IFMTheme.red)
                            Button("Record Outcome") { model.startBuildOutcome(for: idea) }
                                .buttonStyle(.bordered)
                                .help("Log shipped / built / abandoned — teaches your taste model")
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.trailing, 14)
            }
        }
    }

    private func infoBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(IFMTheme.muted)
            Text(body).font(.caption).lineLimit(4)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
    }
}

struct ReadyRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            IFMCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Readiness Checklist").font(.system(size: 18, weight: .bold))
                    HStack {
                        RipenessRing(score: model.metrics.averageRipeness, color: IFMTheme.red, caption: "Avg. Ripeness")
                        VStack(alignment: .leading, spacing: 12) {
                            checklist("Ideas ready", "\(model.ready.items.count)", IFMTheme.green)
                            checklist("Needs approval", "\(model.metrics.approvalJobs)", IFMTheme.orange)
                            checklist("Pending jobs", "\(model.metrics.pendingJobs)", IFMTheme.blue)
                        }
                    }
                    Text("\(model.ready.items.count) ideas currently meet the Ready to Build bar.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Button("Run Local Pass") { model.runLocalFermentation() }
                        .frame(maxWidth: .infinity)
                }
            }
            IFMCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Launch Path").font(.system(size: 18, weight: .bold))
                    ForEach(Array(["Prototype", "Beta", "Waitlist", "Pricing", "Release"].enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle([IFMTheme.red, IFMTheme.orange, IFMTheme.purple, IFMTheme.green, IFMTheme.blue][index])
                                .frame(width: 28, height: 28)
                                .overlay { Circle().stroke([IFMTheme.red, IFMTheme.orange, IFMTheme.purple, IFMTheme.green, IFMTheme.blue][index]) }
                            SymbolBadge(symbol: ["wrench", "heart", "person", "creditcard", "paperplane"][index], color: [IFMTheme.purple, IFMTheme.blue, IFMTheme.purple, IFMTheme.green, IFMTheme.blue][index])
                            VStack(alignment: .leading) {
                                Text(title).font(.system(size: 14, weight: .semibold))
                                Text(["Build the smallest version that proves the core value.", "Get feedback from early users and iterate.", "Gauge demand and collect high-intent users.", "Validate pricing with willing early adopters.", "Launch publicly and keep improving."][index])
                                    .font(.caption)
                                    .foregroundStyle(IFMTheme.muted)
                            }
                            Spacer()
                            Button("Start") { model.startLaunchStep(title) }
                                .disabled(model.ready.items.isEmpty)
                                .help(model.ready.items.isEmpty ? "No ideas are ready to build yet" : "Create a build brief for your top ready idea")
                        }
                    }
                    Button("↗  Export Build Plans") { model.openLaunchDashboard() }
                        .frame(maxWidth: .infinity)
                        .disabled(model.briefs.isEmpty)
                        .help(model.briefs.isEmpty ? "No build plans yet — create one from a ready idea first" : "Export your build plans")
                }
            }
        }
    }

    private func checklist(_ title: String, _ score: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(color)
            Text(title).font(.caption)
            Spacer()
            Text(score).font(.caption).foregroundStyle(IFMTheme.muted)
        }
    }
}

struct ArchivePage: View {
    @ObservedObject var model: ShellViewModel
    @State private var highRipenessOnly = false
    @State private var newestFirst = true

    private var archivedIdeas: [IdeaSeed] {
        model.archive.items
            .filter { !highRipenessOnly || $0.ripeness >= 70 }
            .sorted { newestFirst ? $0.updatedAt > $1.updatedAt : $0.updatedAt < $1.updatedAt }
    }

    var body: some View {
        PageScaffold(title: "Archive", subtitle: "Ideas that have reached an endpoint. Compost for future growth.", symbol: nil, accent: IFMTheme.green) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ForEach(["All", "Archived \(model.archive.items.count)"], id: \.self) { label in
                        Pill(text: label, color: label == "All" ? IFMTheme.green : IFMTheme.slate)
                    }
                    Spacer()
                    Menu("Filter") {
                        Toggle("High ripeness only", isOn: $highRipenessOnly)
                        Button("Clear Filter") { highRipenessOnly = false }
                    }
                    Menu(newestFirst ? "Sort: Newest" : "Sort: Oldest") {
                        Button("Newest First") { newestFirst = true }
                        Button("Oldest First") { newestFirst = false }
                    }
                }
                if model.archive.items.isEmpty {
                    EmptyStateCard(title: "Archive is empty", message: "When you ship, pause, merge, or kill ideas, they’ll land here as reusable compost.", symbol: "archivebox", actionTitle: "Browse Ideas") {
                        model.selectedPage = .inbox
                    }
                } else {
                    ScrollView(.horizontal) {
                        ArchiveTable(model: model, ideas: archivedIdeas)
                            .frame(minWidth: 920)
                    }
                    .scrollIndicators(.automatic)
                }
                HStack {
                    Text("Showing \(archivedIdeas.count) archived ideas")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Spacer()
                    if model.archive.items.count != archivedIdeas.count {
                        Button("Clear Filters") {
                            highRipenessOnly = false
                            newestFirst = true
                        }
                    }
                }
            }
        } rail: {
            ArchiveRail(model: model)
        }
    }
}

struct ArchiveTable: View {
    @ObservedObject var model: ShellViewModel
    var ideas: [IdeaSeed]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Idea").frame(maxWidth: .infinity, alignment: .leading)
                Text("Outcome").frame(width: 110, alignment: .leading)
                Text("Decision Date").frame(width: 110, alignment: .leading)
                Text("Reason / Outcome").frame(maxWidth: .infinity, alignment: .leading)
                Text("What I Learned").frame(maxWidth: .infinity, alignment: .leading)
                Text("Action").frame(width: 90, alignment: .leading)
            }
            .font(.caption)
            .foregroundStyle(IFMTheme.muted)
            .padding(12)
            Divider()
            ForEach(ideas) { idea in
                let outcome = archiveOutcome(for: idea)
                HStack(spacing: 12) {
                    HStack {
                        SymbolBadge(symbol: outcome.symbol, color: outcome.color)
                        VStack(alignment: .leading) {
                            Text(idea.title).font(.system(size: 13, weight: .semibold))
                            Text(idea.body).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Pill(text: outcome.label, color: outcome.color)
                        .frame(width: 110, alignment: .leading)
                    Text(idea.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .frame(width: 110, alignment: .leading)
                    Text(reason(for: idea))
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(lesson(for: idea))
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Resurface") { model.resurfaceIdea(idea) }
                        .buttonStyle(.bordered)
                        .frame(width: 90, alignment: .leading)
                }
                .padding(12)
                Divider()
            }
        }
        .background(IFMTheme.panelStrong)
        .ifmContainer()
    }

    private func archiveOutcome(for idea: IdeaSeed) -> (label: String, symbol: String, color: Color) {
        // A real recorded build outcome always wins over the heuristic guess.
        if let outcome = model.buildOutcome(for: idea) {
            switch outcome.result {
            case .shipped: return ("Shipped", "paperplane.fill", IFMTheme.green)
            case .built: return ("Built", "checkmark.seal.fill", IFMTheme.green)
            case .abandoned: return ("Abandoned", "xmark.bin", IFMTheme.gray)
            case .flopped: return ("Flopped", "bolt.slash", IFMTheme.orange)
            }
        }
        if idea.ripeness >= 75 {
            return ("High Signal", "sparkles", IFMTheme.green)
        }
        if idea.stage == .needsDistance {
            return ("Paused", "pause.circle", IFMTheme.orange)
        }
        if idea.sourceIDs.count > 1 {
            return ("Merged", "arrow.triangle.merge", IFMTheme.blue)
        }
        if !idea.manualTags.isEmpty {
            return ("Learned", "book.closed", IFMTheme.purple)
        }
        return ("Archived", "archivebox", IFMTheme.gray)
    }

    private func reason(for idea: IdeaSeed) -> String {
        if idea.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No archive note yet."
        }
        return idea.body
    }

    private func lesson(for idea: IdeaSeed) -> String {
        if let note = model.buildOutcome(for: idea)?.note, !note.isEmpty {
            return note
        }
        if idea.manualTags.isEmpty {
            return "No explicit lesson captured yet."
        }
        return "Themes: \(idea.manualTags.joined(separator: ", "))"
    }
}

struct ArchiveRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        let lessonCount = model.archive.items.filter { !$0.manualTags.isEmpty || !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        VStack(alignment: .leading, spacing: 18) {
            IFMCard {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Idea Archive").font(.headline)
                        Text("\(model.archive.items.count)").font(.system(size: 28, weight: .bold))
                        Text("Total archived").font(.caption).foregroundStyle(IFMTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundStyle(IFMTheme.gray.opacity(0.45))
                }
            }
            IFMCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Lessons Extracted").font(.headline)
                    Text(model.archive.items.isEmpty ? "No archived lessons yet." : "\(lessonCount) archived ideas include notes or themes you can reuse.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                }
            }
            IFMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Compost Your Learnings", systemImage: "leaf.fill").font(.headline).foregroundStyle(IFMTheme.green)
                    Text("Turn past ideas into future fuel. Document a lesson from any idea.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Button("Add Lesson") { model.addLessonFromArchive() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

}

struct SourcesPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var sourceFilter: SourceType?
    @State private var last30DaysOnly = false
    @State private var needsProcessingOnly = false
    @State private var newestFirst = true

    private var visibleSources: [SourceItem] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return model.sourcesPage.items
            .filter { sourceFilter == nil || $0.type == sourceFilter }
            .filter { !last30DaysOnly || $0.createdAt >= cutoff }
            .filter { !needsProcessingOnly || $0.extractionStatus == .failed || $0.extractionStatus == .captured }
            .sorted { newestFirst ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt }
    }

    private var hasActiveSourceFilters: Bool {
        sourceFilter != nil || last30DaysOnly || needsProcessingOnly || !newestFirst
    }

    var body: some View {
        let sourceHealth = SourceHealth.overall(model.sourcesPage.items)
        PageScaffold(title: "Sources", subtitle: "Raw material feeding your idea fermentation.", symbol: nil, accent: IFMTheme.purple) {
            VStack(spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 14)], spacing: 14) {
                    sourceMetric("\(model.sourcesPage.items.count)", "Total Sources", "local records", "doc.text", IFMTheme.purple)
                    sourceMetric("\(model.sourcesPage.items.filter { $0.type == .screenshot }.count)", "Screenshots", "image captures", "photo", IFMTheme.blue)
                    sourceMetric("\(model.sourcesPage.items.filter { $0.type == .voiceMemo }.count)", "Voice Memos", "transcripts", "mic", IFMTheme.blue)
                    sourceMetric("\(model.sourcesPage.items.filter { $0.type == .link || $0.type == .article }.count)", "Articles / Links", "web material", "link", IFMTheme.purple)
                    sourceMetric(model.sourcesPage.items.isEmpty ? "Idle" : SourceHealth.label(sourceHealth), "Source Health", model.sourcesPage.items.isEmpty ? "No sources yet" : "\(Int(sourceHealth.rounded()))% ready", "checkmark.seal", IFMTheme.green)
                }
                ScrollView(.horizontal) {
                    HStack {
                        Menu(sourceFilter?.rawValue.capitalized ?? "All Types") {
                            Button("All Types") { sourceFilter = nil }
                            ForEach(SourceType.allCases, id: \.self) { type in
                                Button(type.rawValue.capitalized) { sourceFilter = type }
                            }
                        }
                        Button("Clear Filters", action: clearSourceFilters)
                            .disabled(!hasActiveSourceFilters)
                        Toggle("Last 30 Days", isOn: $last30DaysOnly)
                        Toggle("Needs processing", isOn: $needsProcessingOnly)
                        Menu(newestFirst ? "Newest First" : "Oldest First") {
                            Button("Newest First") { newestFirst = true }
                            Button("Oldest First") { newestFirst = false }
                        }
                    }
                }
                .scrollIndicators(.never)
                if visibleSources.isEmpty {
                    if model.sourcesPage.items.isEmpty {
                        EmptyStateCard(title: "No sources yet", message: "Import files, paste URLs, or save notes. Sources stay local and become searchable.", symbol: "doc.text", actionTitle: "Add Source", accent: IFMTheme.purple) {
                            model.startSourceCapture()
                        }
                    } else {
                        EmptyStateCard(title: "No sources match these filters", message: "Clear filters or broaden the time range to see the sources already in your local library.", symbol: "line.3.horizontal.decrease.circle", actionTitle: "Clear Filters", accent: IFMTheme.purple) {
                            clearSourceFilters()
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 252), spacing: 12, alignment: .top)], spacing: 12) {
                        ForEach(visibleSources.prefix(30)) { source in
                            SourceCard(model: model, source: source)
                        }
                    }
                }
            }
        } rail: {
            SourcesRail(model: model)
        }
    }

    private func clearSourceFilters() {
        sourceFilter = nil
        last30DaysOnly = false
        needsProcessingOnly = false
        newestFirst = true
    }

    private func sourceMetric(_ value: String, _ label: String, _ sub: String, _ symbol: String, _ color: Color) -> some View {
        IFMCard {
            HStack(spacing: 12) {
                SymbolBadge(symbol: symbol, color: color)
                VStack(alignment: .leading) {
                    Text(value).font(.system(size: 18, weight: .bold))
                    Text(label).font(.caption).foregroundStyle(IFMTheme.muted)
                    Text(sub).font(.caption).foregroundStyle(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SourceCard: View {
    @ObservedObject var model: ShellViewModel
    var source: SourceItem

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SymbolBadge(symbol: symbol, color: color)
                    VStack(alignment: .leading) {
                        Text(source.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(color)
                        Text(source.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                    }
                    Spacer()
                    SourceActionsMenu(model: model, source: source)
                }
                Text(source.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)
                Text(source.body.isEmpty ? "No extracted text yet. The original source is still stored locally." : source.body)
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
                    .lineLimit(3)
                    .frame(height: 48, alignment: .topLeading)
                SourcePreviewSlot(source: source, color: color)
                    .frame(height: 64)
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Connected Ideas").font(.caption).foregroundStyle(IFMTheme.muted)
                        Text(source.linkedIdeaIDs.isEmpty ? "No linked ideas yet" : "\(source.linkedIdeaIDs.count) linked")
                            .font(.caption)
                    }
                    Spacer()
                    Text("Signal").font(.caption).foregroundStyle(IFMTheme.muted)
                    FreshnessDots(score: SourceHealth.score(source))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 256, maxHeight: 256, alignment: .top)
        }
    }

    private var symbol: String {
        switch source.type {
        case .screenshot: "photo"
        case .voiceMemo: "mic"
        case .article: "doc.richtext"
        case .note: "note.text"
        case .conversation: "message"
        case .document: "doc"
        case .link: "link"
        case .quote: "quote.opening"
        case .sketch: "pencil.and.scribble"
        case .file: "folder"
        }
    }

    private var color: Color {
        switch source.type {
        case .screenshot, .voiceMemo, .link: IFMTheme.blue
        case .article, .note, .sketch: IFMTheme.orange
        case .conversation, .quote: IFMTheme.purple
        case .document, .file: IFMTheme.green
        }
    }
}

struct SourcePreviewSlot: View {
    var source: SourceItem
    var color: Color

    var body: some View {
        Group {
            if source.type == .screenshot, let path = source.filePath, let nsImage = NSImage(contentsOfFile: path) {
                // The actual captured image — not a stand-in collage masquerading as a preview.
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                HStack(spacing: 10) {
                    SymbolBadge(symbol: source.extractionStatus == .failed ? "exclamationmark.triangle" : "checkmark", color: source.extractionStatus == .failed ? IFMTheme.orange : color, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.extractionStatus.rawValue.capitalized)
                            .font(.caption.bold())
                        Text(source.metadata.originalFileName ?? source.url ?? "Local source")
                            .font(.caption2)
                            .foregroundStyle(IFMTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color.opacity(0.055))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
        .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border.opacity(0.75)) }
    }
}

struct SourceActionsMenu: View {
    @ObservedObject var model: ShellViewModel
    var source: SourceItem
    @State private var confirmingDelete = false

    var body: some View {
        Menu {
            Button("Open") { model.openSource(source) }
            Button(source.neverSendToCloud ? "Allow Cloud Use" : "Never Send to Cloud") { model.toggleNeverSend(source) }
            Button("Create Idea From Source") { model.createIdea(from: source) }
            Button("Queue Analysis") { model.queueSourceAnalysis(source) }
            Divider()
            Button("Delete", role: .destructive) { confirmingDelete = true }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(IFMTheme.muted)
                .frame(width: 28, height: 24)
        }
        .menuStyle(.borderlessButton)
        .help("Source actions")
        .accessibilityLabel("Source actions")
        .confirmationDialog(
            "Delete “\(source.title)”?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Source", role: .destructive) { model.deleteSource(source) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the source record from the local database.")
        }
    }
}

struct SourcesRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        let health = SourceHealth.overall(model.sources)
        let pipelineRows = sourcePipelineRows
        VStack(alignment: .leading, spacing: 18) {
            IFMCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Extraction Pipeline").font(.headline)
                        Spacer()
                    }
                    ForEach(pipelineRows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.symbol)
                                .foregroundStyle(row.color)
                            VStack(alignment: .leading) {
                                Text(row.title).font(.system(size: 14, weight: .semibold))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(IFMTheme.muted)
                            }
                            Spacer()
                            Text("\(row.count)").font(.caption).foregroundStyle(IFMTheme.muted)
                        }
                    }
                }
            }
            IFMCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Source Health").font(.headline)
                        Spacer()
                        Text("\(Int(health.rounded()))%").font(.system(size: 24, weight: .bold)).foregroundStyle(IFMTheme.green)
                    }
                    Sparkline(color: IFMTheme.green, values: sourceHealthTrend)
                    Text(model.sources.isEmpty ? "Capture sources to build the local knowledge base." : "\(SourceHealth.label(health)) source readiness based on extraction, text, and idea links.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Button("Add Source") { model.startSourceCapture() }
                        .frame(maxWidth: .infinity)
                }
            }
            IFMCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Privacy & Processing").font(.headline)
                        Spacer()
                        Pill(text: "Local First", color: IFMTheme.green)
                    }
                    Text("All sources are processed on this Mac. Nothing leaves your device.")
                        .font(.caption)
                    ForEach(["No data sent to the cloud", "Private embeddings (local)", "You own your data"], id: \.self) {
                        Label($0, systemImage: "checkmark").font(.caption).foregroundStyle(IFMTheme.green)
                    }
                    Button("Privacy Settings") { model.openPrivacySettings() }
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var sourcePipelineRows: [SourcePipelineRow] {
        let queued = model.jobs.filter { $0.sourceID != nil && [.pending, .running, .paused].contains($0.status) }.count
        let processed = model.sources.filter { [.summarized, .tagged, .connected, .revisitScheduled].contains($0.extractionStatus) }.count
        let approvals = model.jobs.filter { $0.sourceID != nil && $0.status == .needsApproval }.count
        return [
            SourcePipelineRow(title: "Captured", detail: "Source records stored locally", count: model.sources.count, symbol: model.sources.isEmpty ? "circle" : "checkmark.circle.fill", color: model.sources.isEmpty ? IFMTheme.muted : IFMTheme.green),
            SourcePipelineRow(title: "Queued", detail: "Source jobs waiting or running", count: queued, symbol: queued == 0 ? "circle" : "clock.fill", color: queued == 0 ? IFMTheme.muted : IFMTheme.orange),
            SourcePipelineRow(title: "Processed", detail: "Summarized, tagged, or linked", count: processed, symbol: processed == 0 ? "circle" : "checkmark.circle.fill", color: processed == 0 ? IFMTheme.muted : IFMTheme.green),
            SourcePipelineRow(title: "Needs Approval", detail: "Cloud work paused for review", count: approvals, symbol: approvals == 0 ? "circle" : "exclamationmark.circle.fill", color: approvals == 0 ? IFMTheme.muted : IFMTheme.orange)
        ]
    }

    private var sourceHealthTrend: [Double] {
        let values = model.sources.prefix(12).map(SourceHealth.score)
        return values.isEmpty ? [0, 0, 0] : values
    }
}

private struct SourcePipelineRow: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var count: Int
    var symbol: String
    var color: Color
}

struct RailSection<Content: View>: View {
    var title: String
    var count: Int
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                if count > 0 { Pill(text: "\(count)", color: IFMTheme.slate) }
                Spacer()
            }
            content
        }
    }
}

struct SourceMiniCard: View {
    var source: SourceItem

    var body: some View {
        IFMCard(padding: 10) {
            HStack(alignment: .top, spacing: 10) {
                SymbolBadge(symbol: "doc.text", color: IFMTheme.orange, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title).font(.caption.bold()).lineLimit(1)
                    Text(source.body).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(2)
                }
            }
        }
    }
}

struct SourceTinyLine: View {
    var source: SourceItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SymbolBadge(symbol: "doc", color: IFMTheme.slate, size: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.title).font(.caption.bold()).lineLimit(2)
                Text(source.body).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(2)
            }
            Spacer()
        }
    }
}

struct RipenessRing: View {
    var score: Double
    var color: Color
    var caption: String = "Ripeness"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.14), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(1, score / 100))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.65), color], center: .center, angle: .degrees(-90)),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : IFMMotion.gentle, value: score)
            VStack(spacing: 2) {
                Text("\(Int(score))")
                    .font(.system(size: 22, weight: .bold))
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : IFMMotion.standard, value: score)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
        .frame(width: 86, height: 86)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue("\(Int(score)) out of 100")
    }
}

struct ThumbnailCollage: View {
    var seed: String

    var colors: [Color] {
        let palette: [Color] = [IFMTheme.green, IFMTheme.blue, IFMTheme.orange, IFMTheme.purple, IFMTheme.slate]
        // `String.hashValue` is seeded per process, so the collage reshuffled its
        // colors every launch. `Tokenizer.stableHash` (FNV-1a) keeps a given seed
        // mapped to the same palette forever — the same discipline the embeddings use.
        let offset = Int(Tokenizer.stableHash(seed) % UInt64(palette.count))
        return (0..<4).map { palette[($0 + offset) % palette.count] }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: IFMRadius.md)
                    .fill(colors[index].opacity(0.12))
                    .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(colors[index].opacity(0.28)) }
                    .overlay {
                        VStack {
                            Image(systemName: ["rectangle.grid.2x2", "map", "list.bullet.rectangle", "chart.xyaxis.line"][index])
                                .font(.title2)
                                .foregroundStyle(colors[index])
                            Spacer()
                        }
                        .padding(10)
                    }
            }
        }
        .padding(8)
        .background(IFMTheme.scrim.opacity(0.035))
    }
}
