import AppKit
import Foundation
import IdeaFermentationCore
import SwiftUI
import UniformTypeIdentifiers

public enum IFMPage: String, CaseIterable, Identifiable, Sendable {
    case inbox
    case fermenting
    case ripening
    case ready
    case archive
    case sources
    case patterns
    case settings
    case autonomy
    case costCenter
    case privacyCenter

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .fermenting: "Fermenting"
        case .ripening: "Ripening"
        case .ready: "Ready"
        case .archive: "Archive"
        case .sources: "Sources"
        case .patterns: "Patterns"
        case .settings: "Settings"
        case .autonomy: "Automation"
        case .costCenter: "Cost Center"
        case .privacyCenter: "Privacy Center"
        }
    }

    var subtitle: String {
        switch self {
        case .inbox: "New ideas waiting"
        case .fermenting: "Ideas in incubation"
        case .ripening: "Getting interesting"
        case .ready: "Worth building"
        case .archive: "Completed ideas"
        case .sources: "Notes, links, captures"
        case .patterns: "Connections found"
        case .settings: "Keys and data"
        case .autonomy: "Master switch & scout"
        case .costCenter: "Spend and queue"
        case .privacyCenter: "Cloud controls"
        }
    }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .fermenting: "flask"
        case .ripening: "sun.max"
        case .ready: "sparkles"
        case .archive: "archivebox"
        case .sources: "doc.text"
        case .patterns: "circle.grid.3x3"
        case .settings: "gearshape"
        case .autonomy: "bolt.badge.automatic"
        case .costCenter: "chart.pie"
        case .privacyCenter: "lock.shield"
        }
    }

    var accent: Color {
        switch self {
        case .inbox: IFMTheme.blue
        case .fermenting: IFMTheme.green
        case .ripening: IFMTheme.orange
        case .ready: IFMTheme.green
        case .archive: IFMTheme.gray
        case .sources: IFMTheme.purple
        case .patterns: IFMTheme.slate
        case .settings, .autonomy, .costCenter, .privacyCenter: IFMTheme.slate
        }
    }

    var hasMockup: Bool { true }
}

public enum IFMSheet: Identifiable, Sendable {
    case idea
    case source
    case keys
    case outcome

    public var id: String {
        switch self {
        case .idea: "idea"
        case .source: "source"
        case .keys: "keys"
        case .outcome: "outcome"
        }
    }
}

public struct BuildOutcomeDraft: Equatable, Sendable {
    public var ideaID: UUID?
    public var ideaTitle: String
    public var result: BuildResult
    public var note: String

    public init(ideaID: UUID? = nil, ideaTitle: String = "", result: BuildResult = .built, note: String = "") {
        self.ideaID = ideaID
        self.ideaTitle = ideaTitle
        self.result = result
        self.note = note
    }
}

public struct IdeaDraft: Equatable, Sendable {
    public var title = ""
    public var body = ""
    public var tags = ""

    public init() {}
}

public struct SourceDraft: Equatable, Sendable {
    public var title = ""
    public var body = ""
    public var url = ""
    public var type: SourceType = .note
    public var neverSendToCloud = false

    public init() {}
}

public struct ProviderKeyDraft: Equatable, Sendable {
    public var gemini = ""
    public var zai = ""
    public var kimi = ""
    public var openAI = ""
    public var anthropic = ""
    public var firecrawl = ""
    public var openAICompatible = ""
    public var fallbackLabel = "OpenAI Compatible"
    public var fallbackBaseURL = "https://api.openai.com/v1/"
    public var fallbackModel = "gpt-4.1-mini"
    public var fallbackInputCost = ""
    public var fallbackOutputCost = ""

    public init() {}

    public var nonEmptyKeyUpdates: [(key: APIProviderKey, value: String)] {
        [
            (.gemini, gemini),
            (.zai, zai),
            (.kimi, kimi),
            (.openAI, openAI),
            (.anthropic, anthropic),
            (.firecrawl, firecrawl),
            (.openAICompatible, openAICompatible)
        ]
        .compactMap { key, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : (key, trimmed)
        }
    }
}

public struct ScoutMissionDraft: Equatable, Sendable {
    public var title = ""
    public var query = ""

    public init() {}
}

public struct AppMetrics: Equatable, Sendable {
    public var diversity: Double
    public var incubationLoad: Double
    public var averageRipeness: Double
    public var totalSpend: Double
    public var pendingJobs: Int
    public var approvalJobs: Int
}

public struct PendingCloudPreview: Equatable, Sendable {
    public var job: FermentationJob
    public var payload: CloudPayloadPreview
}

@MainActor
public final class ShellViewModel: ObservableObject {
    @Published var selectedPage: IFMPage = .inbox
    @Published var ideas: [IdeaSeed] = []
    @Published var sources: [SourceItem] = []
    @Published var jobs: [FermentationJob] = []
    @Published var logs: [AgentRunLog] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var activeSheet: IFMSheet?
    @Published var ideaDraft = IdeaDraft()
    @Published var sourceDraft = SourceDraft()
    @Published var keyDraft = ProviderKeyDraft()
    @Published var outcomeDraft = BuildOutcomeDraft()
    @Published var metrics = AppMetrics(diversity: 0, incubationLoad: 0, averageRipeness: 0, totalSpend: 0, pendingJobs: 0, approvalJobs: 0)
    /// Cloud spend recorded since midnight — surfaced on the Automation hero. Cached in
    /// reload() so the view never queries the store per render.
    @Published var spentTodayUSD = 0.0
    @Published var isRunningJob = false
    @Published var schedulerSettings = SchedulerSettings()
    @Published var providerSettings = ProviderSettings()
    @Published var autonomyProfile = AutonomyProfile()
    @Published var scoutMissions: [ScoutMission] = []
    @Published var scoutMissionDraft = ScoutMissionDraft()
    @Published var isRunningScout = false
    @Published var connections: [IdeaConnection] = []
    @Published var briefs: [PrototypeBrief] = []
    @Published var critiques: [IdeaCritique] = []
    @Published var tasteModel = TasteModel()
    @Published var buildOutcomes: [BuildOutcome] = []
    @Published var portfolioReport: PortfolioReport?
    @Published var tasteProfile: TasteProfile?
    @Published var ripenessCalibration = RipenessCalibration()
    /// Concept-space taste over the whole portfolio. Cached here and rebuilt in
    /// reload() (after every mutation) so the UI never recomputes centroids per render.
    @Published var conceptTaste = TasteManifold()
    /// How well the app's own Ready predictions have held up against real outcomes.
    @Published var forecastAccuracy = ForecastAccuracy()
    /// Full-corpus status counts + source count for the sidebar nav, so an active search
    /// can't make the global nav badges drop to the filtered subset.
    @Published var statusCounts: [IdeaStatus: Int] = [:]
    @Published var totalSourceCount = 0

    public var pendingCloudPreview: PendingCloudPreview? {
        jobs.lazy
            .filter { $0.status == .needsApproval }
            .compactMap(makePendingCloudPreview)
            .first
    }

    let store: IdeaStore
    let captureServer: CaptureServer?
    /// How provider keys are resolved. Defaults to the Keychain in production; tests
    /// inject a stub so they never touch the operator's real keys or the network.
    private let keyLookup: (APIProviderKey) -> String?
    /// Estimated cost of cloud runs that have been admitted but not yet recorded as
    /// committed usage. Spend-cap checks count this on top of committed spend so two
    /// concurrent runs (a manual click + a scheduled scout) can't both pass the cap
    /// against the same headroom and jointly overshoot. Mutated only on @MainActor.
    private var reservedSpendUSD: Double = 0
    private var schedulerTask: Task<Void, Never>?
    let inbox = InboxPageViewModel()
    let fermenting = FermentingPageViewModel()
    let ripening = RipeningPageViewModel()
    let ready = ReadyPageViewModel()
    let archive = ArchivePageViewModel()
    let sourcesPage = SourcesPageViewModel()
    let patterns = PatternsPageViewModel()

    public init(
        store: IdeaStore,
        captureServer: CaptureServer? = nil,
        keyLookup: @escaping (APIProviderKey) -> String? = { KeychainStore.load($0) }
    ) {
        self.store = store
        self.captureServer = captureServer
        self.keyLookup = keyLookup
        try? store.resumeInterruptedJobs()
        reload()
        startScheduler()
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureArrived), name: .ifmCaptureDidArrive, object: nil)
    }

    deinit {
        schedulerTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    /// A page was captured from the browser; refresh and surface it (unless the
    /// operator is mid-task in a sheet).
    @objc private func handleCaptureArrived() {
        reload()
        if activeSheet == nil { selectedPage = .sources }
    }

    public func reload() {
        do {
            // Fetch the full corpus ONCE and reuse it for the manifold, forecasts, counts,
            // and metrics — instead of decoding every idea three times per mutation.
            let corpus = try store.listIdeas()
            let allSources = try store.listSources()
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ideas = corpus
                sources = allSources
            } else {
                ideas = try store.searchIdeas(searchText)
                sources = try store.searchSources(searchText)
            }
            statusCounts = corpus.reduce(into: [:]) { $0[$1.status, default: 0] += 1 }
            totalSourceCount = allSources.count
            jobs = try store.listJobs()
            logs = try store.runLogs()
            connections = try store.connections()
            briefs = try store.prototypeBriefs()
            critiques = try store.critiques()
            schedulerSettings = try store.loadSchedulerSettings()
            providerSettings = try store.loadProviderSettings()
            autonomyProfile = try store.loadAutonomyProfile()
            scoutMissions = try store.loadScoutMissions()
            tasteModel = try store.loadTasteModel()
            buildOutcomes = try store.buildOutcomes()
            portfolioReport = try store.loadPortfolioReport()
            tasteProfile = try store.loadTasteProfile()
            ripenessCalibration = try store.loadRipenessCalibration()
            conceptTaste = TasteManifold.build(ideas: corpus, outcomes: buildOutcomes)
            spentTodayUSD = (try? store.usageTotalUSD(since: Calendar.current.startOfDay(for: Date()))) ?? 0
            forecastAccuracy = refreshForecasts(corpus: corpus)
            metrics = try makeMetrics(corpus: corpus)
            refreshPageModels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startIdeaCapture(title: String = "", body: String = "") {
        ideaDraft = IdeaDraft()
        ideaDraft.title = title
        ideaDraft.body = body
        activeSheet = .idea
    }

    public func startSourceCapture(type: SourceType = .note) {
        sourceDraft = SourceDraft()
        sourceDraft.type = type
        activeSheet = .source
    }

    public func saveIdeaDraft() {
        addIdea(title: ideaDraft.title, body: ideaDraft.body, tags: ideaDraft.tags)
        activeSheet = nil
    }

    public func addIdea(title: String, body: String, tags: String = "") {
        do {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty || !cleanBody.isEmpty else { return }
            let cleanTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let finalTitle = cleanTitle.isEmpty ? String(cleanBody.prefix(48)) : cleanTitle
            let hash = TextHashing.sha256("\(finalTitle)\n\(cleanBody)\n\(cleanTags.joined(separator: " "))")
            if let existing = try store.idea(textHash: hash) {
                selectedPage = .inbox
                errorMessage = "Already captured: \(existing.title)."
                reload()
                return
            }
            _ = try store.createIdea(
                title: finalTitle,
                body: cleanBody,
                tags: cleanTags
            )
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSourceDraft() {
        Task { await saveSourceDraftAsync() }
    }

    public func saveSourceDraftAsync() async {
        do {
            let cleanURL = sourceDraft.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanTitle = sourceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanBody = sourceDraft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let source: SourceItem
            if !cleanURL.isEmpty, let url = URL(string: cleanURL), url.scheme?.hasPrefix("http") == true {
                var fetched = try await SourceExtractor.readableURL(url)
                if !cleanTitle.isEmpty { fetched.title = cleanTitle }
                if !cleanBody.isEmpty { fetched.body = cleanBody }
                fetched.neverSendToCloud = sourceDraft.neverSendToCloud
                source = fetched
            } else {
                source = SourceItem(
                    type: sourceDraft.type,
                    title: cleanTitle.isEmpty ? "Untitled source" : cleanTitle,
                    body: cleanBody,
                    url: cleanURL.isEmpty ? nil : cleanURL,
                    neverSendToCloud: sourceDraft.neverSendToCloud
                )
            }
            if let existing = try existingSource(matching: source) {
                selectedPage = .sources
                activeSheet = nil
                errorMessage = "Already captured: \(existing.title)."
                reload()
                return
            }
            let stored = try store.createSource(source)
            try store.enqueue(FermentationJob(sourceID: stored.id, taskClass: .extract, inputHash: stored.textHash))
            selectedPage = .sources
            activeSheet = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func queueFermentationLoop() {
        do {
            let engine = makeEngine()
            let jobs = try engine.queueLoop(maxJobs: 12)
            reload()
            errorMessage = jobs.isEmpty
                ? "Nothing to queue yet. Capture ideas or sources first, then queue a cloud loop."
                : "Queued \(jobs.count) cloud job\(jobs.count == 1 ? "" : "s"). Track them in the Cost Center."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func queueCritique(for idea: IdeaSeed) {
        runIdeaAgentNow(for: idea, taskClass: .critique, label: "Critique")
    }

    public func queuePrototypeBrief(for idea: IdeaSeed) {
        runIdeaAgentNow(for: idea, taskClass: .prototypeBrief, label: "Prototype brief")
    }

    public func runLocalFermentation() {
        // Gate on the store, not the (possibly search-filtered) `ideas` array, so an
        // active search that matches nothing can't claim the whole inbox is empty.
        guard (try? store.listIdeas())?.isEmpty == false else {
            selectedPage = .inbox
            errorMessage = "No ideas to ferment yet. Capture a seed in the Inbox first, then run a local pass."
            return
        }
        do {
            let engine = makeEngine()
            let updated = try engine.runLocalPass(maxIdeas: 50)
            reload()
            errorMessage = "Local pass complete — scored \(updated.count) idea\(updated.count == 1 ? "" : "s"). Ripe ones move to Ripening and Ready."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// User-initiated AI runs immediately and shows its result inline — the click
    /// is the consent, so there's no approval queue to shuffle through. Spend caps
    /// and the never-send privacy filter still apply as a safety net, not a gate.
    /// When the cloud can't run (no key, cap reached, or never-send material) it
    /// falls back to the local pass so there is always an instant result.
    private func runIdeaAgentNow(for idea: IdeaSeed, taskClass: ModelTaskClass, label: String) {
        guard !isRunningJob else {
            errorMessage = "Another AI run is finishing — try again in a moment."
            return
        }
        // Don't double-run the same agent on the same idea. Only a genuinely in-flight
        // job blocks a fresh run — a parked/paused job or a leftover needs-approval job
        // from the old queue flow must NOT permanently wedge the instant button.
        let activeStatuses: Set<JobStatus> = [.pending, .running]
        if jobs.contains(where: { $0.ideaID == idea.id && $0.taskClass == taskClass && activeStatuses.contains($0.status) }) {
            selectedPage = page(for: idea.status)
            errorMessage = "\(label) is already running for \(idea.title)."
            return
        }

        // Asking the AI to engage with this idea is a soft signal of interest — past the
        // dedup guard so a duplicate click while one runs doesn't re-teach.
        registerInterest(in: idea)

        let input = "\(idea.title)\n\(idea.body)\n\(idea.manualTags.joined(separator: " "))"
        let route = makeRouter().route(
            taskClass: taskClass,
            inputTokens: CostEstimator.roughTokenCount(input),
            outputTokens: 800
        )

        // No usable key → local pass. (The operator can still get a result.)
        let providers = ProviderFactory.defaultProviders(settings: providerSettings)
        guard let provider = providers.first(where: { $0.providerName == route.provider }),
              let key = apiKey(for: provider.providerName) else {
            runLocalAgentFallback(for: idea, taskClass: taskClass, label: label,
                                  reason: "Ran a local \(label.lowercased()) for \(idea.title) — no cloud key yet. Add a key in Settings for a sharper one.")
            return
        }

        // Privacy net: a tainted idea's own body is protected content, so it never goes
        // to the cloud; and if every part of the payload is never-send, keep it local.
        // Check both the durable flag AND a live never-send link, so a writer that forgot
        // to stamp the flag still can't leak the body.
        let relatedSources = idea.sourceIDs.compactMap { id in sources.first { $0.id == id } }
        if idea.derivedFromNeverSend || relatedSources.contains(where: { $0.neverSendToCloud }) {
            runLocalAgentFallback(for: idea, taskClass: taskClass, label: label,
                                  reason: "\(idea.title) came from never-send material, so it stayed local. Lift the privacy block on its source to use the cloud.")
            return
        }
        let preview = PrivacyPolicy.preview(idea: idea, sources: relatedSources, taskClass: taskClass)
        guard preview.maySend else {
            runLocalAgentFallback(for: idea, taskClass: taskClass, label: label,
                                  reason: "\(idea.title) is marked never-send, so it stayed local. Lift the privacy block to use the cloud.")
            return
        }

        // Spend cap is the safety net, not a gate: only fall back if a PRICED run would
        // breach it. An unpriced model (e.g. Kimi, nil price) still runs on the
        // operator's key — refusing it would force local forever and the "cap reached"
        // message would be a lie.
        if let cost = route.estimatedCostUSD, !fitsSpendCaps(cost) {
            runLocalAgentFallback(for: idea, taskClass: taskClass, label: label,
                                  reason: "Spend cap reached — ran a local \(label.lowercased()) for \(idea.title) instead. Raise the cap in Settings to keep using the cloud.")
            return
        }

        // User-initiated: the click is the approval, so the job runs straight away.
        let userRoute = ModelRoute(
            provider: route.provider,
            model: route.model,
            taskClass: route.taskClass,
            rationale: route.rationale,
            estimatedCostUSD: route.estimatedCostUSD,
            needsApproval: false
        )
        do {
            let job = try store.enqueue(FermentationJob(
                ideaID: idea.id,
                taskClass: taskClass,
                status: .pending,
                estimatedCostUSD: route.estimatedCostUSD ?? 0,
                modelRoute: userRoute,
                inputHash: TextHashing.sha256("\(taskClass.rawValue)\n\(input)")
            ))
            // Reserve the estimated cost against the caps until the run's actual usage
            // is recorded, so a concurrent scout synthesis can't pass the cap against
            // the same headroom.
            let releaseReservation = reserveSpend(route.estimatedCostUSD)
            isRunningJob = true
            selectedPage = page(for: idea.status)
            reload()
            let engine = makeEngine()
            Task {
                defer { Task { @MainActor in
                    releaseReservation()
                    self.isRunningJob = false
                } }
                do {
                    _ = try await engine.runJob(job, provider: provider, apiKey: key, bypassApproval: true)
                    await MainActor.run {
                        self.reload()
                        self.errorMessage = "\(label) ready for \(idea.title) via \(provider.providerName). \(self.resultLocationHint(for: taskClass))"
                    }
                } catch {
                    await MainActor.run {
                        self.runLocalAgentFallback(for: idea, taskClass: taskClass, label: label,
                                                   reason: "Cloud \(label.lowercased()) didn't land (\(error.localizedDescription)) — ran a local \(label.lowercased()) for \(idea.title) instead.")
                    }
                }
            }
        } catch {
            isRunningJob = false
            errorMessage = error.localizedDescription
        }
    }

    /// The local equivalent of a cloud agent run — used when the cloud can't or
    /// shouldn't run. A prototype brief maps to the full local build plan; every
    /// other agent maps to the per-idea local pass (which always leaves a critique).
    private func runLocalAgentFallback(for idea: IdeaSeed, taskClass: ModelTaskClass, label: String, reason: String) {
        if taskClass == .prototypeBrief {
            // The local build plan is rich on its own; createBuildPlan sets a clear
            // success message and navigates, so there's nothing to add here.
            createBuildPlan(for: idea)
            return
        }
        do {
            let engine = makeEngine()
            let updated = try engine.processIdeaLocally(idea)
            selectedPage = page(for: updated.status)
            reload()
            errorMessage = reason + " " + resultLocationHint(for: taskClass)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Where the result of a finished agent run shows up, so the toast can point the
    /// operator straight to it instead of leaving them hunting.
    private func resultLocationHint(for taskClass: ModelTaskClass) -> String {
        switch taskClass {
        case .critique, .connect:
            return "It's on the idea's card and in Patterns."
        case .prototypeBrief:
            return "Open it from the idea's ··· menu."
        default:
            return "It's on the idea."
        }
    }

    // MARK: Cross-idea reasoning

    /// Reasons across the WHOLE portfolio at once — merges, tensions, blind spots, and
    /// what to build next. Cloud-first on the strongest judgment model, with the
    /// deterministic local report as the fallback. Same caps / reservation / privacy
    /// discipline as the per-idea agents.
    public func runPortfolioReasoning() {
        guard !isRunningJob else {
            errorMessage = "Another AI run is finishing — try again in a moment."
            return
        }
        guard (try? store.listIdeas())?.isEmpty == false else {
            selectedPage = .inbox
            errorMessage = "No ideas to reason over yet. Capture a few seeds first, then synthesize."
            return
        }

        let route = makeRouter().route(taskClass: .prototypeBrief, inputTokens: 1_200, outputTokens: 900)
        let providers = ProviderFactory.defaultProviders(settings: providerSettings)

        // No usable key → the local heuristic synthesis, instantly.
        guard let provider = providers.first(where: { $0.providerName == route.provider }),
              let key = apiKey(for: provider.providerName),
              let model = provider.availableModels.first(where: { $0.name == route.model }) ?? provider.availableModels.first
        else {
            saveLocalPortfolioReport(note: "Synthesized \(ideas.count) ideas locally — add a cloud key for the full reasoned pass.")
            return
        }
        // Spend cap is the safety net: a priced run that would breach it falls back.
        if let cost = route.estimatedCostUSD, !fitsSpendCaps(cost) {
            saveLocalPortfolioReport(note: "Spend cap reached — synthesized \(ideas.count) ideas locally instead.")
            return
        }

        let releaseReservation = reserveSpend(route.estimatedCostUSD)
        isRunningJob = true
        // Reason over the WHOLE portfolio from the store, never the search-filtered
        // `ideas` view — otherwise an active search silently shrinks the synthesis.
        let snapshotIdeas = (try? store.listIdeas()) ?? ideas
        let snapshotConnections = (try? store.connections()) ?? connections
        let snapshotSources = (try? store.listSources()) ?? sources
        let snapshotOutcomes = (try? store.buildOutcomes()) ?? buildOutcomes
        let taste = tasteModel
        let profile = autonomyProfile
        // Only feed a CLOUD-distilled profile into the prompt — a local profile is just
        // the same theme tokens the digest already lists, so it would double-count.
        let learnedTaste = tasteProfile?.source.hasPrefix("cloud") == true ? tasteProfile : nil
        Task {
            defer { Task { @MainActor in
                releaseReservation()
                self.isRunningJob = false
            } }
            do {
                guard let result = try await PortfolioReasoner.reason(
                    ideas: snapshotIdeas, connections: snapshotConnections, sources: snapshotSources,
                    outcomes: snapshotOutcomes, taste: taste, profile: profile, tasteProfile: learnedTaste,
                    provider: provider, model: model, apiKey: key, now: Date()
                ) else {
                    await MainActor.run {
                        self.saveLocalPortfolioReport(note: "The model returned nothing usable — used the local synthesis instead.")
                    }
                    return
                }
                await MainActor.run {
                    self.recordPortfolioUsage(provider: provider, model: model, response: result.response)
                    try? self.store.savePortfolioReport(result.report)
                    self.selectedPage = .patterns
                    self.reload()
                    let count = result.report.insights.count
                    self.errorMessage = "Portfolio synthesis ready via \(provider.providerName) — \(count) cross-idea insight\(count == 1 ? "" : "s")."
                }
            } catch {
                await MainActor.run {
                    self.saveLocalPortfolioReport(note: "Cloud synthesis didn't land (\(error.localizedDescription)) — used the local one.")
                }
            }
        }
    }

    private func saveLocalPortfolioReport(note: String) {
        // Use the full store, not the search-filtered `ideas` view, so the local
        // synthesis covers the whole portfolio too.
        let allIdeas = (try? store.listIdeas()) ?? ideas
        let allConnections = (try? store.connections()) ?? connections
        let report = PortfolioReasoner.localReport(ideas: allIdeas, connections: allConnections, taste: tasteModel, now: Date())
        try? store.savePortfolioReport(report)
        selectedPage = .patterns
        reload()
        errorMessage = note
    }

    private func recordPortfolioUsage(provider: any LLMProvider, model: LLMModel, response: LLMResponse, taskClass: ModelTaskClass = .prototypeBrief) {
        let cost = CostEstimator.estimate(model: model, inputTokens: response.inputTokens, outputTokens: response.outputTokens) ?? 0
        try? store.saveUsage(LLMUsageRecord(
            provider: provider.providerName, model: model.name, taskClass: taskClass,
            inputTokens: response.inputTokens, outputTokens: response.outputTokens, estimatedCostUSD: cost
        ))
    }

    /// A multi-step "deep critique": two cloud calls that reason about the idea AND about
    /// the first-pass critique, surfacing the load-bearing assumption and the cheapest
    /// test to kill it. Cloud-only (the loop needs a real model); falls back to a single
    /// local critique when there's no key, the cap is reached, or it's never-send.
    public func deepCritique(for idea: IdeaSeed) {
        guard !isRunningJob else {
            errorMessage = "Another AI run is finishing — try again in a moment."
            return
        }
        registerInterest(in: idea)

        let relatedSources = idea.sourceIDs.compactMap { id in sources.first { $0.id == id } }
        if idea.derivedFromNeverSend || relatedSources.contains(where: { $0.neverSendToCloud }) {
            runLocalAgentFallback(for: idea, taskClass: .critique, label: "Critique",
                                  reason: "\(idea.title) came from never-send material, so it got a local critique. Lift the privacy block for a deep one.")
            return
        }

        let route = makeRouter().route(taskClass: .critique, inputTokens: 900, outputTokens: 700)
        let providers = ProviderFactory.defaultProviders(settings: providerSettings)
        guard let provider = providers.first(where: { $0.providerName == route.provider }),
              let key = apiKey(for: provider.providerName),
              let model = provider.availableModels.first(where: { $0.name == route.model }) ?? provider.availableModels.first
        else {
            runLocalAgentFallback(for: idea, taskClass: .critique, label: "Critique",
                                  reason: "Deep critique needs a cloud key — gave \(idea.title) a local critique. Add a key in Settings.")
            return
        }
        // Two cloud calls of *different* size — step 2 also carries the first-pass draft,
        // so estimate each call honestly and reserve the sum rather than assuming symmetry.
        let step1Cost = route.estimatedCostUSD ?? 0
        let step2Cost = CostEstimator.estimate(model: model, inputTokens: 1_900, outputTokens: 400) ?? 0
        let estimatedTotal = step1Cost + step2Cost
        if route.estimatedCostUSD != nil, !fitsSpendCaps(estimatedTotal) {
            runLocalAgentFallback(for: idea, taskClass: .critique, label: "Critique",
                                  reason: "Spend cap reached — gave \(idea.title) a local critique instead.")
            return
        }
        let releaseReservation = reserveSpend(estimatedTotal)
        isRunningJob = true
        selectedPage = page(for: idea.status)
        let taste = tasteProfile?.source.hasPrefix("cloud") == true ? tasteProfile : nil
        let builder = autonomyProfile
        Task {
            defer { Task { @MainActor in releaseReservation(); self.isRunningJob = false } }
            do {
                let outcome = try await AgentCritic.deepCritique(idea: idea, tasteProfile: taste, builderProfile: builder, provider: provider, model: model, apiKey: key)
                await MainActor.run {
                    // Record every call that actually came back — even on a degraded run we
                    // still paid for it, so the spend ledger and caps stay honest.
                    for response in outcome.responses {
                        self.recordPortfolioUsage(provider: provider, model: model, response: response, taskClass: .critique)
                    }
                    guard let critique = outcome.critique else {
                        self.runLocalAgentFallback(for: idea, taskClass: .critique, label: "Critique",
                                                   reason: "The deep critique's first pass didn't produce usable reasoning — used a local one for \(idea.title).")
                        return
                    }
                    try? self.store.saveCritique(IdeaCritique(
                        ideaID: idea.id,
                        assumptions: critique.assumptions,
                        risks: critique.risks,
                        contradictions: critique.contradictions,
                        source: "deep · \(provider.providerName)"
                    ))
                    self.reload()
                    self.errorMessage = "Deep critique ready for \(idea.title) via \(provider.providerName) — load-bearing assumption + the test to kill it. It's on the idea's card and in Patterns."
                }
            } catch {
                await MainActor.run {
                    self.runLocalAgentFallback(for: idea, taskClass: .critique, label: "Critique",
                                               reason: "Deep critique didn't land (\(error.localizedDescription)) — used a local one for \(idea.title).")
                }
            }
        }
    }

    /// Resolve the ideas an insight is about, for the clickable chips in the UI.
    public func ideas(for insight: PortfolioInsight) -> [IdeaSeed] {
        insight.relatedIdeaTitles.compactMap { title in
            ideas.first { $0.title.lowercased() == title.lowercased() }
        }
    }

    /// Navigate to an idea by title — used by the clickable insight chips.
    public func focusIdea(titled title: String) {
        guard let idea = ideas.first(where: { $0.title.lowercased() == title.lowercased() })
            ?? ideas.first(where: { $0.title.lowercased().contains(title.lowercased()) }) else { return }
        selectedPage = page(for: idea.status)
    }

    /// True when the saved synthesis was generated against a different number of ideas
    /// than the portfolio holds now — a cheap "this is out of date" signal so the card
    /// can nudge a re-synthesis instead of silently showing a stale report.
    public var portfolioReportIsStale: Bool {
        guard let report = portfolioReport else { return false }
        let current = (try? store.listIdeas().count) ?? ideas.count
        return report.ideaCount != current
    }

    // MARK: Taste as judgment

    /// The ideas the operator's decisions reveal they're drawn to vs. drop. Committing
    /// (Ready) or a positive build outcome = liked; a negative outcome or archiving an
    /// idea that never had a positive outcome = disliked.
    private func tasteDecisionSets() -> (liked: [IdeaSeed], disliked: [IdeaSeed]) {
        let allIdeas = (try? store.listIdeas()) ?? ideas
        let outcomes = (try? store.buildOutcomes()) ?? buildOutcomes
        let positiveIDs = Set(outcomes.filter { $0.result.isPositive }.map { $0.ideaID })
        let negativeIDs = Set(outcomes.filter { !$0.result.isPositive }.map { $0.ideaID })
        let liked = allIdeas.filter { $0.status == .ready || positiveIDs.contains($0.id) }
        let disliked = allIdeas.filter { negativeIDs.contains($0.id) || ($0.status == .archived && !positiveIDs.contains($0.id)) }
        return (liked, disliked)
    }

    /// Distills a conceptual taste portrait + rubric from the operator's decisions.
    /// Cloud-first on the strongest judgment model with the local theme-based portrait
    /// as the fallback — same caps / reservation / privacy discipline as the agents.
    public func relearnTaste() {
        guard !isRunningJob else {
            errorMessage = "Another AI run is finishing — try again in a moment."
            return
        }
        let decisions = tasteDecisionSets()
        guard !decisions.liked.isEmpty || !decisions.disliked.isEmpty || !tasteModel.isEmpty else {
            selectedPage = .autonomy
            errorMessage = "Teach taste first — mark an idea Ready, build one, or archive one, then re-learn."
            return
        }

        // Estimate the reservation from the actual decision payload rather than a flat
        // guess, so a large set reserves closer to what it will really cost. (Actual
        // cost is still recorded from the response tokens.)
        let estimateInput = max(600, (decisions.liked + decisions.disliked).reduce(400) { $0 + ($1.title.count + $1.body.count) / 4 })
        let route = makeRouter().route(taskClass: .prototypeBrief, inputTokens: estimateInput, outputTokens: 700)
        let providers = ProviderFactory.defaultProviders(settings: providerSettings)
        guard let provider = providers.first(where: { $0.providerName == route.provider }),
              let key = apiKey(for: provider.providerName),
              let model = provider.availableModels.first(where: { $0.name == route.model }) ?? provider.availableModels.first
        else {
            saveLocalTasteProfile(decisions: decisions, note: "Refreshed your taste profile locally — add a cloud key for a reasoned portrait of why.")
            return
        }
        if let cost = route.estimatedCostUSD, !fitsSpendCaps(cost) {
            saveLocalTasteProfile(decisions: decisions, note: "Spend cap reached — refreshed your taste profile locally instead.")
            return
        }

        let releaseReservation = reserveSpend(route.estimatedCostUSD)
        isRunningJob = true
        let sources = (try? store.listSources()) ?? self.sources
        let outcomes = (try? store.buildOutcomes()) ?? buildOutcomes
        let notes = autonomyProfile.tasteNotes
        Task {
            defer { Task { @MainActor in
                releaseReservation()
                self.isRunningJob = false
            } }
            do {
                guard let result = try await TasteDistiller.distill(
                    liked: decisions.liked, disliked: decisions.disliked, outcomes: outcomes,
                    sources: sources, existingNotes: notes,
                    provider: provider, model: model, apiKey: key, now: Date()
                ) else {
                    await MainActor.run {
                        self.saveLocalTasteProfile(decisions: decisions, note: "The model returned nothing usable — used the local taste portrait instead.")
                    }
                    return
                }
                await MainActor.run {
                    self.recordPortfolioUsage(provider: provider, model: model, response: result.response)
                    try? self.store.saveTasteProfile(result.profile)
                    self.selectedPage = .autonomy
                    self.reload()
                    self.errorMessage = "Taste portrait refreshed via \(provider.providerName) — \(result.profile.criteria.count) criteria learned."
                }
            } catch {
                await MainActor.run {
                    self.saveLocalTasteProfile(decisions: decisions, note: "Cloud taste pass didn't land (\(error.localizedDescription)) — used the local portrait.")
                }
            }
        }
    }

    /// True when decisions have changed since the taste profile was distilled — mirrors
    /// `portfolioReportIsStale` so the card can nudge a refresh.
    public var tasteProfileIsStale: Bool {
        guard let profile = tasteProfile else { return false }
        let decisions = tasteDecisionSets()
        return profile.decisionCount != decisions.liked.count + decisions.disliked.count
    }

    private func saveLocalTasteProfile(decisions: (liked: [IdeaSeed], disliked: [IdeaSeed]), note: String) {
        let profile = TasteDistiller.localProfile(taste: tasteModel, decisionCount: decisions.liked.count + decisions.disliked.count, now: Date())
        try? store.saveTasteProfile(profile)
        selectedPage = .autonomy
        reload()
        errorMessage = note
    }

    public func approveAllJobs() {
        do {
            for job in jobs where job.status == .needsApproval {
                if makePendingCloudPreview(for: job)?.payload.maySend != false {
                    try store.approveJob(job.id)
                }
            }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func approveJob(_ job: FermentationJob) {
        do {
            if makePendingCloudPreview(for: job)?.payload.maySend == false {
                errorMessage = "This job includes only never-send material. Remove the privacy block before approving cloud use."
                return
            }
            try store.approveJob(job.id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func pauseJob(_ job: FermentationJob) {
        guard job.status != .running else {
            errorMessage = "Running jobs finish the current pass before they can pause."
            return
        }
        updateJob(job) { updated in
            updated.status = .paused
        }
    }

    public func resumeJob(_ job: FermentationJob) {
        updateJob(job) { updated in
            updated.status = resumeStatus(for: updated)
            updated.lastError = nil
            updated.retryAfter = nil
        }
    }

    public func retryJob(_ job: FermentationJob) {
        resumeJob(job)
    }

    public func runNextCloudJob() {
        guard !isRunningJob else { return }
        isRunningJob = true
        Task {
            var releaseReservation: () -> Void = {}
            defer { Task { @MainActor in
                releaseReservation()
                self.isRunningJob = false
            } }
            do {
                try ensureSpendCapsAllowNextJob()
                let providers = ProviderFactory.defaultProviders(settings: providerSettings)
                guard let job = try store.nextRunnableJob() else {
                    await MainActor.run { self.errorMessage = "No pending jobs to run." }
                    return
                }
                let route = job.modelRoute
                let provider = providers.first { $0.providerName == route?.provider } ?? providers[0]
                guard let key = apiKey(for: provider.providerName) else {
                    await MainActor.run { self.errorMessage = "Add a \(provider.providerName) API key in Settings first." }
                    return
                }
                // Reserve this job's cost against the caps across the run so a
                // concurrent scout synthesis can't double-spend the same headroom.
                await MainActor.run { releaseReservation = self.reserveSpend(job.estimatedCostUSD) }
                let engine = makeEngine()
                _ = try await engine.runNext(provider: provider, apiKey: key)
                await MainActor.run { self.reload() }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    public func importFile(url: URL) {
        do {
            let extracted = try SourceExtractor.extract(url: url)
            if let existing = try existingSource(matching: extracted) {
                selectedPage = .sources
                errorMessage = "Already captured: \(existing.title)."
                reload()
                return
            }
            let source = try store.createSource(extracted)
            try store.enqueue(FermentationJob(sourceID: source.id, taskClass: .extract, inputHash: source.textHash))
            selectedPage = .sources
            reload()
            if source.extractionStatus == .failed {
                errorMessage = "Imported \(source.title), but local text extraction did not find readable text. The file is saved and queued for later analysis."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func existingSource(matching source: SourceItem) throws -> SourceItem? {
        let hash = source.textHash.isEmpty ? TextHashing.sha256("\(source.title)\n\(source.body)") : source.textHash
        return try store.source(textHash: hash)
    }

    public func moveIdeaToFermenting(_ idea: IdeaSeed) {
        updateIdea(idea) {
            $0.status = .fermenting
            if $0.stage == .seed { $0.stage = .brewing }
        }
    }

    public func markIdeaReady(_ idea: IdeaSeed) {
        updateIdea(idea) {
            $0.status = .ready
            $0.stage = .readyToPrototype
            $0.ripeness = max($0.ripeness, 80)
        }
        reinforceTaste(with: idea, label: 1)
    }

    public func archiveIdea(_ idea: IdeaSeed) {
        updateIdea(idea) {
            $0.status = .archived
        }
        // Archiving a Ready idea usually means it shipped or moved on, not a
        // rejection — so only treat archiving an *unripe* idea as a negative signal.
        if idea.status != .ready {
            reinforceTaste(with: idea, label: -1)
        }
    }

    public func resurfaceIdea(_ idea: IdeaSeed) {
        updateIdea(idea) {
            $0.status = .inbox
            $0.stage = .seed
        }
    }

    public func deleteIdea(_ idea: IdeaSeed) {
        do {
            if idea.status != .ready {
                reinforceTaste(with: idea, label: -1)
            }
            try store.deleteIdea(idea.id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ideas an insight cites, resolved against the FULL corpus (not the search-filtered
    /// view) and excluding archived/terminal ideas — the candidates a merge can act on.
    public func mergeCandidates(for insight: PortfolioInsight) -> [IdeaSeed] {
        let all = (try? store.listIdeas()) ?? ideas
        return insight.relatedIdeaTitles.compactMap { title in
            all.first { $0.title.lowercased() == title.lowercased() && $0.status != .archived }
        }
    }

    public func mergeIdea(_ secondary: IdeaSeed, into primary: IdeaSeed) {
        mergeIdeas([secondary], into: primary)
    }

    /// Fold one or more ideas into a survivor — making the portfolio synthesis's "these
    /// are really one idea" insight executable. Unions bodies/tags/sources/axes, MIGRATES
    /// the folded ideas' connections to the survivor (so the graph isn't thinned),
    /// inherits privacy taint, recomputes the text hash, then removes the folded ideas.
    public func mergeIdeas(_ secondaries: [IdeaSeed], into primary: IdeaSeed) {
        do {
            var merged = try store.idea(id: primary.id)
            var folded: [UUID] = []
            for secondary in secondaries where secondary.id != merged.id {
                let other = try store.idea(id: secondary.id)
                let otherBody = other.body.trimmingCharacters(in: .whitespacesAndNewlines)
                if !otherBody.isEmpty, !merged.body.contains(otherBody) {
                    merged.body += "\n\n— merged from “\(other.title)” —\n\(other.body)"
                }
                merged.manualTags = Array(Set(merged.manualTags + other.manualTags)).sorted()
                merged.sourceIDs = Array(Set(merged.sourceIDs + other.sourceIDs))
                merged.ripeness = max(merged.ripeness, other.ripeness)
                merged.novelty = max(merged.novelty, other.novelty)
                merged.evidence = max(merged.evidence, other.evidence)
                merged.personalResonance = max(merged.personalResonance, other.personalResonance)
                merged.feasibility = max(merged.feasibility, other.feasibility)
                merged.timing = max(merged.timing, other.timing)
                merged.status = moreMatureStatus(merged.status, other.status)
                // Privacy taint is inherited — the merged body now contains the other
                // idea's content, which may be never-send.
                merged.derivedFromNeverSend = merged.derivedFromNeverSend || other.derivedFromNeverSend

                // Migrate the folded idea's connections to the survivor (re-point the
                // endpoint, drop self-edges; saveConnection de-dupes undirected pairs) —
                // otherwise edges THIRD ideas hold to it would be silently destroyed.
                for connection in try store.connections(for: other.id) {
                    let from = connection.fromID == other.id ? merged.id : connection.fromID
                    let to = connection.toID == other.id ? merged.id : connection.toID
                    if from != to {
                        try store.saveConnection(IdeaConnection(fromID: from, toID: to, explanation: connection.explanation, confidence: connection.confidence))
                    }
                }
                // Re-point the folded idea's sources to the survivor.
                for sourceID in other.sourceIDs {
                    if var source = try? store.source(id: sourceID) {
                        source.linkedIdeaIDs.removeAll { $0 == other.id }
                        if !source.linkedIdeaIDs.contains(merged.id) { source.linkedIdeaIDs.append(merged.id) }
                        try store.upsertSource(source)
                    }
                }
                folded.append(other.id)
            }
            guard !folded.isEmpty else { return }

            // The body changed, so the dedup/search hash must be recomputed.
            merged.textHash = TextHashing.sha256("\(merged.title)\n\(merged.body)\n\(merged.manualTags.joined(separator: " "))")
            merged.updatedAt = Date()
            // Additive writes first, deletions last — a crash mid-merge leaves a harmless
            // duplicate, never lost content.
            try store.upsertIdea(merged)
            for id in folded {
                try store.deleteIdea(id) // store-level (no taste penalty — merge isn't rejection)
            }
            selectedPage = page(for: merged.status)
            reload()
            errorMessage = "Merged \(folded.count) idea\(folded.count == 1 ? "" : "s") into “\(merged.title)”."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moreMatureStatus(_ lhs: IdeaStatus, _ rhs: IdeaStatus) -> IdeaStatus {
        func rank(_ status: IdeaStatus) -> Int {
            switch status {
            case .ready: 4
            case .ripening: 3
            case .fermenting: 2
            case .inbox: 1
            case .archived: 0
            }
        }
        return rank(lhs) >= rank(rhs) ? lhs : rhs
    }

    public func duplicateIdea(_ idea: IdeaSeed) {
        do {
            var copy = try store.createIdea(title: "\(idea.title) Copy", body: idea.body, tags: idea.manualTags, status: .inbox, stage: .seed)
            // A copy of a tainted idea carries the same protected content.
            if idea.derivedFromNeverSend {
                copy.derivedFromNeverSend = true
                try store.upsertIdea(copy)
            }
            selectedPage = .inbox
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The page a given idea lives on, so navigation lands where the idea's card
    /// actually is — not always on Ready.
    func page(for status: IdeaStatus) -> IFMPage {
        switch status {
        case .inbox: .inbox
        case .fermenting: .fermenting
        case .ripening: .ripening
        case .ready: .ready
        case .archived: .archive
        }
    }

    public func createBuildPlan(for idea: IdeaSeed) {
        do {
            guard try store.prototypeBriefs(for: idea.id).isEmpty else {
                selectedPage = page(for: idea.status)
                reload()
                errorMessage = "Build plan already exists for \(idea.title). Open it from the idea's ··· menu."
                return
            }
            let brief = buildPlanBrief(for: idea)
            try store.savePrototypeBrief(brief)
            reinforceTaste(with: idea, label: 1)
            selectedPage = page(for: idea.status)
            reload()
            errorMessage = "Build plan created for \(idea.title). Open it from the idea's ··· menu."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func buildPlan(for idea: IdeaSeed) -> PrototypeBrief? {
        briefs.first { $0.ideaID == idea.id }
    }

    public func critique(for idea: IdeaSeed) -> IdeaCritique? {
        critiques.first { $0.ideaID == idea.id }
    }

    public func openBuildPlan(for idea: IdeaSeed) {
        do {
            if buildPlan(for: idea) == nil {
                createBuildPlan(for: idea)
            }
            let folder = try IdeaStore.applicationSupportURL()
                .appendingPathComponent("Build Plans", isDirectory: true)
            guard let brief = buildPlan(for: idea) else { return }
            let url = try writeBuildPlan(brief, to: folder)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleNeverSend(_ source: SourceItem) {
        do {
            var updated = source
            updated.neverSendToCloud.toggle()
            try store.upsertSource(updated)
            // Marking a source never-send taints every idea that draws on it, so their
            // bodies are withheld too. (Taint is sticky — un-marking doesn't clear it,
            // since the protected content was already copied into the idea.)
            if updated.neverSendToCloud {
                for ideaID in updated.linkedIdeaIDs {
                    if var idea = try? store.idea(id: ideaID), !idea.derivedFromNeverSend {
                        idea.derivedFromNeverSend = true
                        try store.upsertIdea(idea)
                    }
                }
            }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createIdea(from source: SourceItem) {
        do {
            var idea = try store.createIdea(title: source.title, body: source.body.isEmpty ? "Imported from \(source.type.rawValue)." : source.body, tags: [source.type.rawValue])
            // The new idea's body is a copy of the source body. Link them in BOTH
            // directions so privacy redaction (which keys on the idea↔source link) still
            // protects a never-send source's content that now lives in the idea body.
            idea.sourceIDs = [source.id]
            // The body is a copy of the source body — if that source is never-send, the
            // idea inherits the taint so every cloud path withholds it from here on.
            idea.derivedFromNeverSend = source.neverSendToCloud
            try store.upsertIdea(idea)
            if !source.linkedIdeaIDs.contains(idea.id) {
                var linkedSource = source
                linkedSource.linkedIdeaIDs.append(idea.id)
                try store.upsertSource(linkedSource)
            }
            // Pulling an idea out of a source is a soft signal of interest (success path
            // only — the duplicate branch below doesn't re-teach).
            registerInterest(in: idea)
            selectedPage = .inbox
            reload()
            errorMessage = "Added “\(idea.title)” to the Inbox."
        } catch IdeaStoreError.duplicate {
            selectedPage = .inbox
            errorMessage = "Already captured as an idea: \(source.title)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func queueSourceAnalysis(_ source: SourceItem) {
        do {
            let activeStatuses: Set<JobStatus> = [.pending, .running, .paused, .needsApproval]
            if jobs.contains(where: { $0.sourceID == source.id && $0.taskClass == .summarize && activeStatuses.contains($0.status) }) {
                selectedPage = .costCenter
                errorMessage = "Analysis already queued for \(source.title)."
                return
            }
            try store.enqueue(FermentationJob(sourceID: source.id, taskClass: .summarize, inputHash: source.textHash))
            selectedPage = .costCenter
            reload()
            errorMessage = "Analysis queued for \(source.title). Track it in the Cost Center."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func openSource(_ source: SourceItem) {
        if let path = source.filePath {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else if let rawURL = source.url, let url = URL(string: rawURL) {
            NSWorkspace.shared.open(url)
        } else {
            errorMessage = "This source has no file or URL to open."
        }
    }

    public func deleteSource(_ source: SourceItem) {
        do {
            try store.deleteSource(source.id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addLessonFromArchive() {
        do {
            guard let idea = archive.items.first else {
                errorMessage = "Nothing archived yet. Archive or record an outcome on an idea first, then its lesson can be composted here."
                return
            }
            _ = try store.createSource(SourceItem(type: .note, title: "Lesson: \(idea.title)", body: "Archived lesson from \(idea.title): \(idea.body)", extractionStatus: .captured))
            selectedPage = .sources
            reload()
            errorMessage = "Lesson from \(idea.title) saved to Sources."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startLaunchStep(_ title: String) {
        // The launch path only applies to ideas that have actually reached Ready —
        // don't quietly grab an archived or half-baked idea just to have something to
        // act on. With nothing ready, say so and point the operator at the next step.
        guard let idea = ready.items.first else {
            selectedPage = .ready
            errorMessage = "Nothing is ready to build yet. Capture an idea in the Inbox and run a local pass — ready ideas appear here first, then \(title) can begin."
            return
        }
        createBuildPlan(for: idea)
    }

    public func openLaunchDashboard() {
        do {
            let folder = try IdeaStore.applicationSupportURL()
                .appendingPathComponent("Build Plans", isDirectory: true)
            let exported = try exportBuildPlans(to: folder)
            guard let first = exported.first else {
                selectedPage = .ready
                errorMessage = "Create a build plan from a ready idea to start the launch dashboard."
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([first])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    public func exportBuildPlans(to folder: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var seen = Set<UUID>()
        return try briefs.compactMap { brief in
            guard seen.insert(brief.ideaID).inserted else { return nil }
            return try writeBuildPlan(brief, to: folder)
        }
    }

    public func openPrivacySettings() {
        selectedPage = .privacyCenter
    }

    public func showNotifications() {
        selectedPage = .costCenter
        errorMessage = metrics.approvalJobs > 0 ? "\(metrics.approvalJobs) job(s) need approval." : "No pending notifications."
    }

    public func showScheduler() {
        selectedPage = .costCenter
    }

    public func addScoutMission() {
        let cleanQuery = scoutMissionDraft.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return }
        let cleanTitle = scoutMissionDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        scoutMissions.append(ScoutMission(
            title: cleanTitle.isEmpty ? cleanQuery : cleanTitle,
            query: cleanQuery
        ))
        scoutMissionDraft = ScoutMissionDraft()
        persistAutonomyConfiguration()
    }

    public func toggleScoutMission(_ mission: ScoutMission) {
        guard let index = scoutMissions.firstIndex(where: { $0.id == mission.id }) else { return }
        scoutMissions[index].isEnabled.toggle()
        persistAutonomyConfiguration()
    }

    public func deleteScoutMission(_ mission: ScoutMission) {
        scoutMissions.removeAll { $0.id == mission.id }
        persistAutonomyConfiguration()
    }

    public func persistAutonomyConfiguration() {
        do {
            try saveAutonomyConfiguration()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveAutonomyConfiguration() throws {
        try store.saveAutonomyProfile(autonomyProfile)
        try store.saveScoutMissions(scoutMissions)
    }

    @discardableResult
    public func runAutonomousScout(useWeb: Bool = true, scheduledOnly: Bool = false, now: Date = Date()) async -> Bool {
        guard !isRunningScout else { return false }
        isRunningScout = true
        defer { isRunningScout = false }
        do {
            if scoutMissions.isEmpty {
                scoutMissions = [defaultScoutMission()]
                try saveAutonomyConfiguration()
            }
            guard let mission = scoutMissionToRun(scheduledOnly: scheduledOnly, now: now) else {
                if !scheduledOnly { errorMessage = "Enable an eligible scout mission first." }
                return false
            }
            if !scheduledOnly, let lastRunAt = mission.lastRunAt, now.timeIntervalSince(lastRunAt) < 60 {
                errorMessage = "Scout just ran. Give public sites a minute before running it again."
                return false
            }
            let shouldUseWeb = useWeb && autonomyProfile.allowWebScouting
            // Self-tuning brief: search the operator's proven lanes, not just the
            // literal mission query, and drop signals in lanes they've abandoned.
            let focus = scoutFocus
            let webSignals = shouldUseWeb ? await scoutSignals(query: focus.augment(query: mission.query)) : []
            let profileFiltered = AutonomousScout.filterSignals(webSignals, profile: autonomyProfile)
            let filteredWebSignals = focus.filter(profileFiltered)
            let signals = filteredWebSignals.isEmpty ? AutonomousScout.fallbackSignals(profile: autonomyProfile, mission: mission) : filteredWebSignals
            let sourceIDs = try saveScoutSources(signals, mission: mission)

            // Route the new material. If it's clearly about an idea you already have,
            // attach it as fresh evidence instead of spawning a near-duplicate — which
            // also makes cross-pollination a real event you can feel. Only start a new
            // idea when nothing existing is a strong semantic match.
            let signalText = ([mission.query] + signals.map { "\($0.title) \($0.summary)" }).joined(separator: " ")
            let queryVector = LocalEmbeddings.embed(signalText)
            let strongest = try store.listIdeas()
                .map { (idea: $0, score: LocalEmbeddings.cosine(queryVector, $0.embedding)) }
                .max { $0.score < $1.score }

            if let strongest, strongest.score >= LocalEmbeddings.strongMatchFloor {
                try attachScoutEvidence(sourceIDs, to: strongest.idea, mission: mission)
            } else {
                // A real synthesis call (when web scouting + a cloud key + the spend
                // cap allow) proposes an ORIGINAL idea from the signals; otherwise the
                // deterministic template. Either way it's source-backed and local-scored.
                let synthesized = shouldUseWeb ? await synthesizeScoutIdea(mission: mission, signals: signals, focus: focus, unattended: scheduledOnly) : nil
                let seed = synthesized ?? AutonomousScout.draftIdea(profile: autonomyProfile, mission: mission, signals: signals)
                var idea = try store.createIdea(title: seed.title, body: seed.body, tags: seed.tags)
                idea.sourceIDs = sourceIDs
                // When web scouting is off the fallback sources are never-send, so a
                // scout idea built from them inherits the taint.
                if sourceIDs.contains(where: { (try? store.source(id: $0))?.neverSendToCloud == true }) {
                    idea.derivedFromNeverSend = true
                }
                try store.upsertIdea(idea)
                let job = try store.enqueue(FermentationJob(
                    ideaID: idea.id,
                    taskClass: .scoreRipeness,
                    estimatedCostUSD: 0,
                    modelRoute: ModelRoute(
                        provider: "Local",
                        model: "scout-v1",
                        taskClass: .scoreRipeness,
                        rationale: "Autonomous scout output gets a local ripeness pass before cloud synthesis.",
                        estimatedCostUSD: 0,
                        needsApproval: false
                    ),
                    inputHash: TextHashing.sha256("scout\n\(idea.title)\n\(idea.body)")
                ))
                try store.saveRunLog(AgentRunLog(
                    jobID: job.id,
                    agentName: "Scout Agent",
                    promptVersion: synthesized != nil ? "synth-v1" : (shouldUseWeb ? "web-v1" : "local-v1"),
                    inputTrace: mission.id.uuidString,
                    output: "\(synthesized != nil ? "Synthesized" : "Created") \(idea.title) from \(signals.count) scout signal(s).",
                    modelUsed: synthesized != nil ? "Cloud synthesis" : (shouldUseWeb ? "Public web endpoints" : "Local/fallback")
                ))
            }
            markScoutMissionRan(mission)
            try saveAutonomyConfiguration()
            selectedPage = .inbox
            reload()
            return true
        } catch {
            errorMessage = error.localizedDescription
            reload()
            return false
        }
    }

    public func saveKeys() {
        do {
            for update in keyDraft.nonEmptyKeyUpdates {
                try KeychainStore.save(update.value, for: update.key)
            }
            providerSettings = ProviderSettings(
                fallbackProviderLabel: keyDraft.fallbackLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "OpenAI Compatible" : keyDraft.fallbackLabel,
                fallbackBaseURL: keyDraft.fallbackBaseURL,
                fallbackModelName: keyDraft.fallbackModel,
                fallbackInputCostPerMillion: Double(keyDraft.fallbackInputCost),
                fallbackOutputCostPerMillion: Double(keyDraft.fallbackOutputCost)
            )
            try store.saveProviderSettings(providerSettings)
            keyDraft = ProviderKeyDraft()
            activeSheet = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func hasKey(_ key: APIProviderKey) -> Bool {
        keyLookup(key) != nil
    }

    public func resetAllData() {
        do {
            try store.deleteAllData()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Browser connector

    public var captureServerEnabled: Bool {
        (try? store.loadCaptureServerConfig().isEnabled) ?? true
    }

    public func setCaptureServerEnabled(_ enabled: Bool) {
        captureServer?.setEnabled(enabled)
    }

    public func regenerateCaptureToken() {
        captureServer?.regenerateToken()
        errorMessage = "New connector token generated. Re-paste it into the Chrome extension."
    }

    public func copyCaptureToken() {
        guard let token = captureServer?.currentToken, !token.isEmpty else { return }
        copyToPasteboard(token)
    }

    public func copyCapturePairingInfo() {
        guard let info = captureServer?.pairingInfo() else { return }
        copyToPasteboard(info)
    }

    private func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    public func exportPatternReport(_ markdown: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Idea-Fermentation-Pattern-Report.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func prepareKeyDraft() {
        keyDraft.fallbackLabel = providerSettings.fallbackProviderLabel
        keyDraft.fallbackBaseURL = providerSettings.fallbackBaseURL
        keyDraft.fallbackModel = providerSettings.fallbackModelName
        keyDraft.fallbackInputCost = providerSettings.fallbackInputCostPerMillion.map { "\($0)" } ?? ""
        keyDraft.fallbackOutputCost = providerSettings.fallbackOutputCostPerMillion.map { "\($0)" } ?? ""
        activeSheet = .keys
    }

    public func runSchedulerNow() {
        do {
            let engine = makeEngine()
            schedulerSettings.nextLocalRunAt = nil
            schedulerSettings = try engine.tickScheduler(settings: schedulerSettings)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateScheduler(_ settings: SchedulerSettings) {
        do {
            schedulerSettings = settings
            try store.saveSchedulerSettings(settings)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateDailySpendCap(_ value: String) {
        guard let dollars = Double(value), dollars >= 0 else { return }
        var settings = schedulerSettings
        settings.dailySpendCapUSD = dollars
        updateScheduler(settings)
    }

    public func updateMonthlySpendCap(_ value: String) {
        guard let dollars = Double(value), dollars >= 0 else { return }
        var settings = schedulerSettings
        settings.monthlySpendCapUSD = dollars
        updateScheduler(settings)
    }

    public func count(for page: IFMPage) -> Int {
        // Nav badges describe the whole portfolio (full-corpus counts), so an active
        // search filtering the visible lists doesn't make the sidebar numbers drop.
        switch page {
        case .inbox: statusCounts[.inbox] ?? 0
        case .fermenting: statusCounts[.fermenting] ?? 0
        case .ripening: statusCounts[.ripening] ?? 0
        case .ready: statusCounts[.ready] ?? 0
        case .archive: statusCounts[.archived] ?? 0
        case .sources: totalSourceCount
        case .patterns: connections.count
        case .autonomy: scoutMissions.filter(\.isEnabled).count
        case .settings, .costCenter, .privacyCenter: 0
        }
    }

    private func refreshPageModels() {
        inbox.configure(ideas: ideas.filter { $0.status == .inbox }, sources: sources)
        fermenting.configure(ideas: ideas.filter { $0.status == .fermenting }, sources: sources)
        ripening.configure(ideas: ideas.filter { $0.status == .ripening }, sources: sources)
        ready.configure(ideas: ideas.filter { $0.status == .ready }, sources: sources)
        archive.configure(ideas: ideas.filter { $0.status == .archived }, sources: sources)
        sourcesPage.configure(sources: sources, ideas: ideas)
        patterns.configure(ideas: ideas, logs: logs, connections: connections)
    }

    private func startScheduler() {
        schedulerTask?.cancel()
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await MainActor.run { self?.tickSchedulerIfDue() }
            }
        }
    }

    private func tickSchedulerIfDue() {
        do {
            let engine = makeEngine()
            schedulerSettings = try engine.tickScheduler(settings: schedulerSettings)
            if schedulerSettings.cloudAutoRun, try canAutoRunCloud() {
                runNextCloudJob()
            } else {
                reload()
            }
            if !isRunningScout, !AutonomousScout.dueMissions(profile: autonomyProfile, missions: scoutMissions).isEmpty {
                Task { await self.runAutonomousScout(scheduledOnly: true) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func canAutoRunCloud() throws -> Bool {
        guard let job = try store.nextRunnableJob(), job.estimatedCostUSD > 0 else { return false }
        return fitsSpendCaps(job.estimatedCostUSD)
    }

    private func ensureSpendCapsAllowNextJob() throws {
        guard let job = try store.nextRunnableJob(), job.estimatedCostUSD > 0 else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? day
        guard committedPlusReservedUSD(since: day) + job.estimatedCostUSD <= schedulerSettings.dailySpendCapUSD else {
            throw LLMProviderError.requestFailed("Daily spend cap reached.")
        }
        guard committedPlusReservedUSD(since: month) + job.estimatedCostUSD <= schedulerSettings.monthlySpendCapUSD else {
            throw LLMProviderError.requestFailed("Monthly spend cap reached.")
        }
    }

    private func makePendingCloudPreview(for job: FermentationJob) -> PendingCloudPreview? {
        guard job.status == .needsApproval else { return nil }
        if let ideaID = job.ideaID, let idea = ideas.first(where: { $0.id == ideaID }) {
            let relatedSources = idea.sourceIDs.compactMap { id in sources.first { $0.id == id } }
            return PendingCloudPreview(job: job, payload: appendAgentLearning(to: PrivacyPolicy.preview(idea: idea, sources: relatedSources, taskClass: job.taskClass)))
        }
        if let sourceID = job.sourceID, let source = sources.first(where: { $0.id == sourceID }) {
            let payload = source.neverSendToCloud ? "" : "\(source.title)\n\n\(source.body)"
            return PendingCloudPreview(
                job: job,
                payload: appendAgentLearning(to: CloudPayloadPreview(
                    title: source.title,
                    taskClass: job.taskClass,
                    characterCount: payload.count,
                    blockedSourceTitles: source.neverSendToCloud ? [source.title] : [],
                    payload: payload,
                    maySend: !source.neverSendToCloud
                ))
            )
        }
        return PendingCloudPreview(
            job: job,
            payload: appendAgentLearning(to: CloudPayloadPreview(
                title: "Queued \(job.taskClass.rawValue)",
                taskClass: job.taskClass,
                characterCount: job.inputHash.count,
                blockedSourceTitles: [],
                payload: job.inputHash,
                maySend: true
            ))
        )
    }

    private func appendAgentLearning(to preview: CloudPayloadPreview) -> CloudPayloadPreview {
        guard preview.maySend else { return preview }
        let payload = AgentLearning.appendContext(
            to: preview.payload,
            ideas: ideas,
            sources: sources,
            logs: logs,
            jobs: jobs,
            connections: connections,
            outcomes: buildOutcomes
        )
        return CloudPayloadPreview(
            title: preview.title,
            taskClass: preview.taskClass,
            characterCount: payload.count,
            blockedSourceTitles: preview.blockedSourceTitles,
            payload: payload,
            maySend: preview.maySend
        )
    }

    private func updateJob(_ job: FermentationJob, mutate: (inout FermentationJob) -> Void) {
        do {
            var updated = try store.job(id: job.id)
            mutate(&updated)
            updated.updatedAt = Date()
            try store.enqueue(updated)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resumeStatus(for job: FermentationJob) -> JobStatus {
        if job.estimatedCostUSD > 0, job.modelRoute?.needsApproval == true {
            return .needsApproval
        }
        return .pending
    }

    private func buildPlanBrief(for idea: IdeaSeed) -> PrototypeBrief {
        let actions = [
            "Build the smallest usable prototype for the core loop.",
            "Test it with one real target user or one realistic workflow.",
            "Record the decision: keep building, revise, pause, or archive."
        ]
        let acceptanceChecks = [
            "A user can understand the value without extra explanation.",
            "The prototype proves one measurable behavior, not a full product.",
            "Feedback and next decision are captured back in Idea Fermentation Machine."
        ]
        let tags = idea.manualTags.isEmpty ? "No tags yet" : idea.manualTags.joined(separator: ", ")
        let sourceLine = idea.sourceIDs.isEmpty ? "No linked sources yet" : "\(idea.sourceIDs.count) linked source(s)"
        let actionMarkdown = actions.map { "- \($0)" }.joined(separator: "\n")
        let checkMarkdown = acceptanceChecks.map { "- \($0)" }.joined(separator: "\n")

        // Weave in everything the fermentation loop already learned about this idea
        // so the handoff is a self-contained packet, not just the raw note.
        let linkedSources = idea.sourceIDs.compactMap { id in sources.first { $0.id == id } }
        let evidenceMarkdown = linkedSources.isEmpty
            ? "_No linked sources yet — capture evidence before building._"
            : linkedSources.map { source in
                let snippet = source.body.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = snippet.isEmpty ? (source.url ?? "stored locally") : String(snippet.prefix(180))
                return "- **\(source.title)** (\(source.type.rawValue)) — \(detail)"
            }.joined(separator: "\n")

        let ideaCritique = critique(for: idea)
        let riskBullets = ideaCritique.map { $0.risks + $0.contradictions }.flatMap { $0.isEmpty ? nil : $0 }
            ?? ["Scope creep", "Weak evidence", "Unclear user pull", "Building past the smallest useful test"]
        let riskMarkdown = riskBullets.map { "- \($0)" }.joined(separator: "\n")

        let relatedTitles = connections
            .filter { $0.fromID == idea.id || $0.toID == idea.id }
            .compactMap { connection -> String? in
                let otherID = connection.fromID == idea.id ? connection.toID : connection.fromID
                return ideas.first { $0.id == otherID }.map { "- \($0.title)" }
            }
        let relatedMarkdown = relatedTitles.isEmpty ? "_No connected ideas yet._" : relatedTitles.joined(separator: "\n")

        let implementationPrompt = """
        Build a focused prototype of "\(idea.title)".

        Goal:
        \(idea.body)

        Constraints:
        - Ship the smallest version that proves the core loop — a prototype, not a product, and not a feature system.
        - Use the simplest stack that runs today; do not add abstractions before they are needed.
        - Keep it local-first and privacy-respecting where the idea touches personal data.

        Acceptance criteria:
        \(acceptanceChecks.map { "- \($0)" }.joined(separator: "\n"))

        Deliver a runnable prototype plus a one-paragraph note on what it proves and what it does not.
        """

        let markdown = """
        # \(idea.title)

        ## Build Handoff
        \(idea.body)

        ## Context
        - Tags: \(tags)
        - Evidence: \(sourceLine)
        - Readiness: ripeness \(Int(idea.ripeness)), feasibility \(Int(idea.feasibility)), resonance \(Int(idea.personalResonance)), novelty \(Int(idea.novelty))

        ## Evidence
        \(evidenceMarkdown)

        ## MVP Scope
        One focused prototype that proves the core loop for \(idea.title).

        ## Risks & Contradictions
        \(riskMarkdown)

        ## Related Ideas
        \(relatedMarkdown)

        ## Next Actions
        \(actionMarkdown)

        ## Acceptance Checks
        \(checkMarkdown)

        ## Implementation Prompt
        Copy this into Codex or Claude Code to start building:

        ```
        \(implementationPrompt)
        ```
        """
        return PrototypeBrief(
            ideaID: idea.id,
            audience: "Early users with this exact problem.",
            mvpScope: "One focused prototype that proves the core loop for \(idea.title).",
            risks: riskBullets.prefix(2).joined(separator: "; "),
            nextActions: actions,
            markdown: markdown
        )
    }

    private func writeBuildPlan(_ brief: PrototypeBrief, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ideaTitle = ideas.first(where: { $0.id == brief.ideaID })?.title ?? "Idea"
        let fileName = "\(Self.safeFileName(ideaTitle))-\(brief.ideaID.uuidString.prefix(8))-Build-Plan.md"
        let url = folder.appendingPathComponent(fileName)
        try brief.markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeMetrics(corpus: [IdeaSeed]) throws -> AppMetrics {
        // Metrics describe the whole portfolio, so they read the full corpus — never the
        // search-filtered `ideas` view.
        let tagCount = Set(corpus.flatMap(\.manualTags)).count
        let sourceTypes = Set(sources.map(\.type)).count
        let diversity = min(1, Double(tagCount + sourceTypes) / 12)
        let load = min(1, Double(jobs.filter { $0.status == .pending || $0.status == .running }.count) / 25)
        let avg = corpus.isEmpty ? 0 : corpus.reduce(0) { $0 + $1.ripeness } / Double(corpus.count)
        return AppMetrics(
            diversity: diversity,
            incubationLoad: load,
            averageRipeness: avg,
            totalSpend: try store.usageTotalUSD(),
            pendingJobs: jobs.filter { $0.status == .pending }.count,
            approvalJobs: jobs.filter { $0.status == .needsApproval }.count
        )
    }

    private func apiKey(for provider: String) -> String? {
        if provider == "Gemini" { return keyLookup(.gemini) }
        if provider == "Z.ai" { return keyLookup(.zai) }
        if provider == "Kimi" { return keyLookup(.kimi) }
        if provider == "OpenAI" { return keyLookup(.openAI) }
        if provider == "Claude" { return keyLookup(.anthropic) }
        return keyLookup(.openAICompatible)
    }

    /// Provider names the operator currently has a usable key for. Drives routing
    /// so queued cloud jobs land on a provider that can actually run.
    private func availableProviderNames() -> Set<String> {
        var names: Set<String> = []
        if hasKey(.gemini) { names.insert("Gemini") }
        if hasKey(.zai) { names.insert("Z.ai") }
        if hasKey(.kimi) { names.insert("Kimi") }
        if hasKey(.openAI) { names.insert("OpenAI") }
        if hasKey(.anthropic) { names.insert("Claude") }
        if hasKey(.openAICompatible) { names.insert(providerSettings.fallbackProviderLabel) }
        return names
    }

    private func makeRouter() -> ModelRouter {
        ModelRouter(availableProviders: availableProviderNames())
    }

    /// A fermentation engine wired with the operator's taste profile (so local
    /// scoring reflects what they actually care about) and key-aware routing.
    private func makeEngine() -> FermentationEngine {
        FermentationEngine(store: store, router: makeRouter(), taste: TasteSignals(profile: autonomyProfile, learned: tasteModel), calibration: ripenessCalibration)
    }

    /// Snapshot a forecast for any idea that has reached Ready without one yet (the
    /// app's *prediction*), then recompute how well past predictions have held up.
    /// Idempotent: the open-forecast guard means it's safe to run on every reload.
    private func refreshForecasts(corpus: [IdeaSeed]) -> ForecastAccuracy {
        do {
            var logs = try store.forecastLogs()
            let withOpen = Set(logs.filter { !$0.isResolved }.map(\.ideaID))
            for idea in corpus where idea.status == .ready && !withOpen.contains(idea.id) {
                let log = makeForecast(for: idea)
                try store.saveForecastLog(log)
                logs.insert(log, at: 0)
            }
            return ForecastAccuracy(from: logs)
        } catch {
            return forecastAccuracy
        }
    }

    private func makeForecast(for idea: IdeaSeed) -> ForecastLog {
        // Prefer the stored ripeness score (it has all six axes incl. clarity, which the
        // idea row doesn't); fall back to the idea's own axis fields.
        let score = (try? store.ripenessScores(for: idea.id))?.sorted { $0.createdAt > $1.createdAt }.first
        return ForecastLog(
            ideaID: idea.id,
            ripenessAtPrediction: idea.ripeness,
            predictedProbability: ForecastLog.probability(forRipeness: idea.ripeness),
            novelty: score?.novelty ?? idea.novelty,
            clarity: score?.clarity ?? 0,
            evidence: score?.evidence ?? idea.evidence,
            resonance: score?.personalResonance ?? idea.personalResonance,
            feasibility: score?.feasibility ?? idea.feasibility,
            timing: score?.timing ?? idea.timing,
            source: "auto"
        )
    }

    /// Resolve an idea's forecast against a real outcome. Re-records overwrite the same
    /// row (no duplicate), mirroring how taste reversal is handled on re-record.
    private func resolveForecast(ideaID: UUID, result: BuildResult) {
        guard var forecast = try? store.latestForecast(for: ideaID) else { return }
        forecast.resolvedAt = Date()
        forecast.actualPositive = result.isPositive
        forecast.outcomeResult = result
        try? store.saveForecastLog(forecast)
    }

    /// Refit the ripeness re-weighting from build outcomes: each outcome pairs the
    /// idea's axis scores with whether the build went well. Cheap, local, deterministic.
    private func recalibrateRipeness() {
        do {
            let outcomes = try store.buildOutcomes()
            let samples: [RipenessCalibration.Sample] = outcomes.compactMap { outcome in
                // Use the score as it stood AT outcome time, never a post-outcome re-score
                // (which could be contaminated by the outcome itself). No build-time score
                // ⇒ no sample, rather than learning from a fabricated one.
                let scores = (try? store.ripenessScores(for: outcome.ideaID)) ?? []
                guard let score = scores
                    .filter({ $0.createdAt <= outcome.createdAt })
                    .max(by: { $0.createdAt < $1.createdAt })
                else { return nil }
                return RipenessCalibration.Sample(
                    novelty: score.novelty, clarity: score.clarity, evidence: score.evidence,
                    resonance: score.personalResonance, feasibility: score.feasibility, timing: score.timing,
                    positive: outcome.result.isPositive
                )
            }
            let calibration = RipenessCalibration.fit(samples: samples)
            try store.saveRipenessCalibration(calibration)
            ripenessCalibration = calibration
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Learning loop (Phase 6)

    /// Records a taste signal from one of the operator's decisions: +1 when they
    /// commit to an idea (mark Ready, build), −1 when they let an unripe idea die.
    /// The next local pass scores similar ideas accordingly — the taste profile
    /// tuning itself instead of being hand-edited.
    private func reinforceTaste(with idea: IdeaSeed, label: Double, rate: Double = TasteModel.defaultLearningRate, countsAsObservation: Bool = true) {
        guard label != 0 else { return }
        do {
            // Learn over the idea's curated themes (tags + distinctive title words),
            // not its whole body — so the model captures real themes, not filler.
            let terms = TasteModel.themeTerms(title: idea.title, tags: idea.manualTags)
            guard !terms.isEmpty else { return }
            let updated = try store.loadTasteModel().reinforced(with: terms, label: label, rate: rate, countsAsObservation: countsAsObservation)
            try store.saveTasteModel(updated)
            tasteModel = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A soft, high-frequency *intent* signal: the operator asked the AI to engage with
    /// this idea (critique, brief) or pulled it out of a source. It nudges the token
    /// taste model gently and is NOT counted as a committed decision.
    ///
    /// Token-bag only: never feeds RipenessCalibration or TasteManifold (those stay on
    /// real commitments — Ready / build outcomes), and it never mutates idea status or
    /// writes a BuildOutcome.
    private func registerInterest(in idea: IdeaSeed) {
        reinforceTaste(with: idea, label: 1, rate: TasteModel.softInterestRate, countsAsObservation: false)
    }

    // MARK: Build outcome loop

    public func buildOutcome(for idea: IdeaSeed) -> BuildOutcome? {
        buildOutcomes.first { $0.ideaID == idea.id }
    }

    public func startBuildOutcome(for idea: IdeaSeed) {
        outcomeDraft = BuildOutcomeDraft(ideaID: idea.id, ideaTitle: idea.title, result: buildOutcome(for: idea)?.result ?? .built, note: buildOutcome(for: idea)?.note ?? "")
        activeSheet = .outcome
    }

    public func saveBuildOutcomeDraft() {
        guard let ideaID = outcomeDraft.ideaID else {
            activeSheet = nil
            return
        }
        let result = outcomeDraft.result
        let note = outcomeDraft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            // Resolve from the store, not the (possibly search-filtered) ideas array,
            // so an active search can't make the sheet silently drop the outcome.
            let idea = try store.idea(id: ideaID)
            // Re-recording must not double-teach: reverse the prior outcome's taste
            // signal before applying the new one, so the model reflects only the latest.
            if let prior = try store.buildOutcome(for: ideaID) {
                reinforceTaste(with: idea, label: -prior.result.tasteLabel, rate: prior.result.tasteRate)
            }
            try store.saveBuildOutcome(BuildOutcome(ideaID: ideaID, result: result, note: note))
            // Building is the strongest taste signal there is — reinforce harder than
            // a mere mark-ready, in the direction the outcome implies.
            reinforceTaste(with: idea, label: result.tasteLabel, rate: result.tasteRate)
            // Resolve the app's own prediction against reality before archiving, so it
            // can measure whether its Ready calls actually pan out.
            resolveForecast(ideaID: ideaID, result: result)
            // A recorded outcome is an endpoint: the idea composts into the Archive,
            // now carrying its real result and lesson instead of a heuristic guess.
            updateIdea(idea) { $0.status = .archived }
            // Every outcome is a labeled example — refit which ripeness axes actually
            // predict this operator's wins.
            recalibrateRipeness()
            activeSheet = nil
            selectedPage = .archive
            errorMessage = "Recorded outcome for \(idea.title): \(result.title)."
        } catch {
            errorMessage = "Could not record that outcome: \(error.localizedDescription)"
            activeSheet = nil
        }
    }

    public func resetLearnedTaste() {
        do {
            try store.saveTasteModel(TasteModel())
            try store.clearTasteProfile()
            tasteModel = TasteModel()
            tasteProfile = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func safeFileName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let name = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Build-Plan" : String(name.prefix(80))
    }

    /// Attach scouted sources to an existing idea as fresh evidence, revive it if it
    /// was parked, cross-link the sources, and queue a local re-score.
    private func attachScoutEvidence(_ sourceIDs: [UUID], to idea: IdeaSeed, mission: ScoutMission) throws {
        var target = idea
        let existing = Set(target.sourceIDs)
        let newSourceIDs = sourceIDs.filter { !existing.contains($0) }
        target.sourceIDs += newSourceIDs
        // Attaching a never-send source as evidence taints the idea.
        if newSourceIDs.contains(where: { (try? store.source(id: $0))?.neverSendToCloud == true }) {
            target.derivedFromNeverSend = true
        }
        if target.status == .archived {
            target.status = .fermenting
            target.stage = .brewing
        }
        target.updatedAt = Date()
        try store.upsertIdea(target)

        for sourceID in sourceIDs {
            if var source = try? store.source(id: sourceID), !source.linkedIdeaIDs.contains(target.id) {
                source.linkedIdeaIDs.append(target.id)
                try store.upsertSource(source)
            }
        }

        let job = try store.enqueue(FermentationJob(
            ideaID: target.id,
            taskClass: .scoreRipeness,
            modelRoute: ModelRoute(provider: "Local", model: "scout-v1", taskClass: .scoreRipeness, rationale: "Re-score after attaching new scout evidence.", estimatedCostUSD: 0, needsApproval: false),
            inputHash: TextHashing.sha256("scout-attach\n\(target.id)\n\(sourceIDs.map(\.uuidString).joined())")
        ))
        try store.saveRunLog(AgentRunLog(
            jobID: job.id,
            agentName: "Scout Agent",
            promptVersion: "attach-v1",
            inputTrace: mission.id.uuidString,
            output: "Attached \(sourceIDs.count) new source(s) to existing idea \(target.title).",
            modelUsed: "Local/route"
        ))
    }

    /// One quality-routed cloud call that synthesizes an original idea from the
    /// signals. Returns nil (caller falls back to the template) unless a usable
    /// provider key exists and the day's spend cap still has room — so an
    /// autonomous run can never silently blow the budget.
    private func synthesizeScoutIdea(mission: ScoutMission, signals: [ScoutSignal], focus: ScoutFocus, unattended: Bool) async -> ExtractedSeed? {
        // A manual "Run scout now" is user-initiated — the click is the consent, so it
        // synthesizes immediately (still spend-capped). An *unattended* scheduled run
        // sends taste/goals to a third-party LLM with nobody watching, so it stays off
        // until the operator has explicitly dropped the approval requirement.
        if unattended && autonomyProfile.requireApprovalBeforeBuildHandoff { return nil }
        let providers = ProviderFactory.defaultProviders(settings: providerSettings)
        let route = makeRouter().route(taskClass: .prototypeBrief, inputTokens: 600, outputTokens: 500)
        guard let provider = providers.first(where: { $0.providerName == route.provider }),
              let key = apiKey(for: provider.providerName),
              let model = provider.availableModels.first(where: { $0.name == route.model }) ?? provider.availableModels.first,
              canAffordSynthesis(estimatedCost: route.estimatedCostUSD)
        else { return nil }
        // Hold the cost against the caps across the await so a concurrent manual run
        // can't pass the same headroom; release once usage is recorded (or it failed).
        let releaseReservation = reserveSpend(route.estimatedCostUSD)
        defer { releaseReservation() }
        do {
            guard let seed = try await AutonomousScout.synthesize(
                profile: autonomyProfile, mission: mission, signals: signals,
                provider: provider, model: model, apiKey: key, focus: focus,
                tasteProfile: tasteProfile?.source.hasPrefix("cloud") == true ? tasteProfile : nil
            ) else { return nil }
            try? store.saveUsage(LLMUsageRecord(
                provider: provider.providerName, model: model.name, taskClass: .prototypeBrief,
                inputTokens: 600, outputTokens: 500, estimatedCostUSD: route.estimatedCostUSD ?? 0
            ))
            return seed
        } catch {
            return nil
        }
    }

    /// True only when a priced cloud synthesis fits within BOTH the daily and monthly
    /// spend caps. An unpriced model (nil estimate) is refused outright, so it can't
    /// slip a real cloud call past the caps recorded as a phantom $0.
    private func canAffordSynthesis(estimatedCost: Double?) -> Bool {
        // Unattended synthesis refuses an unpriced model (nil) so a real cloud call
        // can't slip past the caps recorded as a phantom $0.
        guard let estimatedCost else { return false }
        return fitsSpendCaps(estimatedCost)
    }

    /// Committed spend (from the DB) plus the cost of runs admitted but not yet
    /// recorded. Every cap check gates on this so two concurrent runs can't both pass
    /// against the same headroom and jointly overshoot.
    private func committedPlusReservedUSD(since date: Date) -> Double {
        ((try? store.usageTotalUSD(since: date)) ?? 0) + reservedSpendUSD
    }

    /// Whether a priced run of `cost` fits under BOTH the daily and monthly caps,
    /// counting committed + reserved spend. A zero/negative cost always fits.
    private func fitsSpendCaps(_ cost: Double) -> Bool {
        guard cost > 0 else { return true }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? day
        return committedPlusReservedUSD(since: day) + cost <= schedulerSettings.dailySpendCapUSD
            && committedPlusReservedUSD(since: month) + cost <= schedulerSettings.monthlySpendCapUSD
    }

    /// Reserve `cost` for an admitted-but-not-yet-recorded run. Returns a release
    /// closure to call exactly once when the run's usage is committed (or it failed),
    /// so the reservation can't leak and permanently shrink the operator's headroom.
    private func reserveSpend(_ cost: Double?) -> () -> Void {
        let amount = max(0, cost ?? 0)
        reservedSpendUSD += amount
        var released = false
        return { [weak self] in
            guard !released else { return }
            released = true
            guard let self else { return }
            self.reservedSpendUSD = max(0, self.reservedSpendUSD - amount)
        }
    }

    /// The self-tuning scout brief — derived live from what the operator has built,
    /// kept, and abandoned. Empty until there is real signal.
    public var scoutFocus: ScoutFocus {
        ScoutFocus.derive(taste: tasteModel, outcomes: buildOutcomes, ideas: ideas, profile: autonomyProfile)
    }

    private func scoutSignals(query: String) async -> [ScoutSignal] {
        var signals: [ScoutSignal] = []
        if let firecrawlKey = KeychainStore.load(.firecrawl) {
            let firecrawl = FirecrawlSearchProvider()
            signals += (try? await firecrawl.search(query: query, limit: 5, apiKey: firecrawlKey)) ?? []
        }
        if signals.count < 2, let openAIKey = KeychainStore.load(.openAI) {
            let openAI = OpenAIWebSearchProvider()
            signals += (try? await openAI.search(query: query, limit: 5, apiKey: openAIKey)) ?? []
        }
        if signals.isEmpty {
            signals = (try? await AutonomousScout.webSignals(for: ScoutMission(title: query, query: query), limit: 5)) ?? []
        }
        if signals.isEmpty {
            let htmlFallback = BeautifulSoupSearchProvider()
            signals = (try? await htmlFallback.search(query: query, limit: 3, apiKey: "")) ?? []
        }
        return Array(unique(signals).prefix(6))
    }

    private func unique(_ signals: [ScoutSignal]) -> [ScoutSignal] {
        var seen = Set<String>()
        return signals.filter { signal in
            let key = signal.url ?? signal.title.lowercased()
            return seen.insert(key).inserted
        }
    }

    private func scoutMissionToRun(scheduledOnly: Bool, now: Date) -> ScoutMission? {
        let due = AutonomousScout.dueMissions(profile: autonomyProfile, missions: scoutMissions, now: now, limit: 1).first
        if scheduledOnly { return due }
        if let due { return due }
        guard let forced = AutonomousScout.dueMissions(profile: autonomyProfile, missions: scoutMissions.map { mission in
            var copy = mission
            copy.lastRunAt = nil
            return copy
        }, now: now, limit: 1).first else { return nil }
        return scoutMissions.first { $0.id == forced.id } ?? forced
    }

    private func defaultScoutMission() -> ScoutMission {
        let query = autonomyProfile.watchTopics
            .split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "AI-native app ideas"
        return ScoutMission(title: "Daily Idea Scout", query: query)
    }

    private func saveScoutSources(_ signals: [ScoutSignal], mission: ScoutMission) throws -> [UUID] {
        try signals.map { signal in
            let source = SourceItem(
                type: signal.kind,
                title: signal.title,
                body: "\(signal.summary)\n\nScout mission: \(mission.query)\nCaptured: \(ISO8601DateFormatter().string(from: Date()))",
                url: signal.url,
                extractionStatus: .captured,
                neverSendToCloud: !autonomyProfile.allowWebScouting
            )
            return try store.createSource(source).id
        }
    }

    private func markScoutMissionRan(_ mission: ScoutMission) {
        guard let index = scoutMissions.firstIndex(where: { $0.id == mission.id }) else { return }
        scoutMissions[index].lastRunAt = Date()
    }

    private func updateIdea(_ idea: IdeaSeed, mutate: (inout IdeaSeed) -> Void) {
        do {
            var updated = idea
            mutate(&updated)
            updated.updatedAt = Date()
            try store.upsertIdea(updated)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
public final class InboxPageViewModel: ObservableObject {
    @Published var items: [IdeaSeed] = []
    @Published var rawMaterial: [SourceItem] = []
    func configure(ideas: [IdeaSeed], sources: [SourceItem]) {
        items = ideas
        rawMaterial = Array(sources.prefix(12))
    }
}

@MainActor
public final class FermentingPageViewModel: ObservableObject {
    @Published var items: [IdeaSeed] = []
    @Published var signals: [SourceItem] = []
    func configure(ideas: [IdeaSeed], sources: [SourceItem]) {
        items = ideas
        signals = Array(sources.prefix(8))
    }
}

@MainActor
public final class RipeningPageViewModel: ObservableObject {
    @Published var items: [IdeaSeed] = []
    @Published var changes: [SourceItem] = []
    func configure(ideas: [IdeaSeed], sources: [SourceItem]) {
        items = ideas.sorted { $0.ripeness > $1.ripeness }
        changes = Array(sources.filter { Calendar.current.isDateInToday($0.createdAt) }.prefix(10))
    }
}

@MainActor
public final class ReadyPageViewModel: ObservableObject {
    @Published var items: [IdeaSeed] = []
    @Published var sources: [SourceItem] = []
    func configure(ideas: [IdeaSeed], sources: [SourceItem]) {
        items = ideas.sorted { $0.ripeness > $1.ripeness }
        self.sources = sources
    }
}

@MainActor
public final class ArchivePageViewModel: ObservableObject {
    @Published var items: [IdeaSeed] = []
    @Published var sources: [SourceItem] = []
    func configure(ideas: [IdeaSeed], sources: [SourceItem]) {
        items = ideas
        self.sources = sources
    }
}

@MainActor
public final class SourcesPageViewModel: ObservableObject {
    @Published var items: [SourceItem] = []
    @Published var ideas: [IdeaSeed] = []
    func configure(sources: [SourceItem], ideas: [IdeaSeed]) {
        items = sources
        self.ideas = ideas
    }
}

@MainActor
public final class PatternsPageViewModel: ObservableObject {
    @Published var ideas: [IdeaSeed] = []
    @Published var logs: [AgentRunLog] = []
    @Published var connections: [IdeaConnection] = []

    func configure(ideas: [IdeaSeed], logs: [AgentRunLog], connections: [IdeaConnection]) {
        self.ideas = ideas
        self.logs = logs
        self.connections = connections
    }
}
