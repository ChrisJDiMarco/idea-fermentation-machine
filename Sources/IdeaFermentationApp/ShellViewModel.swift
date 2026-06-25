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
        case .autonomy: "Autonomy"
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
        case .autonomy: "Agent scout"
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
        case .autonomy: "sparkle.magnifyingglass"
        case .costCenter: "chart.pie"
        case .privacyCenter: "lock.shield"
        }
    }

    var accent: Color {
        switch self {
        case .inbox: IFMTheme.blue
        case .fermenting: IFMTheme.green
        case .ripening: IFMTheme.orange
        case .ready: IFMTheme.red
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

    public var id: String {
        switch self {
        case .idea: "idea"
        case .source: "source"
        case .keys: "keys"
        }
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
    @Published var metrics = AppMetrics(diversity: 0, incubationLoad: 0, averageRipeness: 0, totalSpend: 0, pendingJobs: 0, approvalJobs: 0)
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

    public var pendingCloudPreview: PendingCloudPreview? {
        jobs.lazy
            .filter { $0.status == .needsApproval }
            .compactMap(makePendingCloudPreview)
            .first
    }

    let store: IdeaStore
    let captureServer: CaptureServer?
    private var schedulerTask: Task<Void, Never>?
    let inbox = InboxPageViewModel()
    let fermenting = FermentingPageViewModel()
    let ripening = RipeningPageViewModel()
    let ready = ReadyPageViewModel()
    let archive = ArchivePageViewModel()
    let sourcesPage = SourcesPageViewModel()
    let patterns = PatternsPageViewModel()

    public init(store: IdeaStore, captureServer: CaptureServer? = nil) {
        self.store = store
        self.captureServer = captureServer
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
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ideas = try store.listIdeas()
                sources = try store.listSources()
            } else {
                ideas = try store.searchIdeas(searchText)
                sources = try store.searchSources(searchText)
            }
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
            metrics = try makeMetrics()
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
            _ = try engine.queueLoop(maxJobs: 12)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func queueCritique(for idea: IdeaSeed) {
        queueIdeaJob(for: idea, taskClass: .critique, label: "Critique")
    }

    public func queuePrototypeBrief(for idea: IdeaSeed) {
        queueIdeaJob(for: idea, taskClass: .prototypeBrief, label: "Prototype brief")
    }

    public func runLocalFermentation() {
        do {
            let engine = makeEngine()
            _ = try engine.runLocalPass(maxIdeas: 50)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func queueIdeaJob(for idea: IdeaSeed, taskClass: ModelTaskClass, label: String) {
        do {
            let activeStatuses: Set<JobStatus> = [.pending, .running, .paused, .needsApproval]
            if jobs.contains(where: { $0.ideaID == idea.id && $0.taskClass == taskClass && activeStatuses.contains($0.status) }) {
                selectedPage = .costCenter
                errorMessage = "\(label) already queued for \(idea.title)."
                return
            }
            let input = "\(idea.title)\n\(idea.body)\n\(idea.manualTags.joined(separator: " "))"
            let route = makeRouter().route(
                taskClass: taskClass,
                inputTokens: CostEstimator.roughTokenCount(input),
                outputTokens: 800
            )
            let status: JobStatus = route.needsApproval ? .needsApproval : .pending
            try store.enqueue(FermentationJob(
                ideaID: idea.id,
                taskClass: taskClass,
                status: status,
                estimatedCostUSD: route.estimatedCostUSD ?? 0,
                modelRoute: route,
                inputHash: TextHashing.sha256("\(taskClass.rawValue)\n\(input)")
            ))
            selectedPage = .costCenter
            errorMessage = status == .needsApproval ? "\(label) needs approval before cloud use." : "\(label) queued for \(idea.title)."
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
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
            defer { Task { @MainActor in self.isRunningJob = false } }
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

    public func duplicateIdea(_ idea: IdeaSeed) {
        do {
            _ = try store.createIdea(title: "\(idea.title) Copy", body: idea.body, tags: idea.manualTags, status: .inbox, stage: .seed)
            selectedPage = .inbox
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createBuildPlan(for idea: IdeaSeed) {
        do {
            guard try store.prototypeBriefs(for: idea.id).isEmpty else {
                selectedPage = .ready
                reload()
                errorMessage = "Build plan already exists for \(idea.title)."
                return
            }
            let brief = buildPlanBrief(for: idea)
            try store.savePrototypeBrief(brief)
            reinforceTaste(with: idea, label: 1)
            selectedPage = .ready
            reload()
            errorMessage = "Build plan created for \(idea.title)."
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
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createIdea(from source: SourceItem) {
        do {
            _ = try store.createIdea(title: source.title, body: source.body.isEmpty ? "Imported from \(source.type.rawValue)." : source.body, tags: [source.type.rawValue])
            selectedPage = .inbox
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func queueSourceAnalysis(_ source: SourceItem) {
        do {
            try store.enqueue(FermentationJob(sourceID: source.id, taskClass: .summarize, inputHash: source.textHash))
            selectedPage = .costCenter
            reload()
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
                errorMessage = "Archive an idea before adding a lesson."
                return
            }
            _ = try store.createSource(SourceItem(type: .note, title: "Lesson: \(idea.title)", body: "Archived lesson from \(idea.title): \(idea.body)", extractionStatus: .captured))
            selectedPage = .sources
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startLaunchStep(_ title: String) {
        guard let idea = ready.items.first ?? ideas.sorted(by: { $0.ripeness > $1.ripeness }).first else {
            errorMessage = "Add or ripen an idea before starting \(title)."
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
            let shouldUseWeb = useWeb && autonomyProfile.allowWebScouting
            let webSignals = shouldUseWeb ? await scoutSignals(for: mission) : []
            let filteredWebSignals = AutonomousScout.filterSignals(webSignals, profile: autonomyProfile)
            let signals = filteredWebSignals.isEmpty ? AutonomousScout.fallbackSignals(profile: autonomyProfile, mission: mission) : filteredWebSignals
            let sourceIDs = try saveScoutSources(signals, mission: mission)
            let seed = AutonomousScout.draftIdea(profile: autonomyProfile, mission: mission, signals: signals)
            var idea = try store.createIdea(title: seed.title, body: seed.body, tags: seed.tags)
            idea.sourceIDs = sourceIDs
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
                promptVersion: shouldUseWeb ? "web-v1" : "local-v1",
                inputTrace: mission.id.uuidString,
                output: "Created \(idea.title) from \(signals.count) scout signal(s).",
                modelUsed: shouldUseWeb ? "Public web endpoints" : "Local/fallback"
            ))
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
        KeychainStore.load(key) != nil
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
        switch page {
        case .inbox: ideas.filter { $0.status == .inbox }.count
        case .fermenting: ideas.filter { $0.status == .fermenting }.count
        case .ripening: ideas.filter { $0.status == .ripening }.count
        case .ready: ideas.filter { $0.status == .ready }.count
        case .archive: ideas.filter { $0.status == .archived }.count
        case .sources: sources.count
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
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? day
        return try store.usageTotalUSD(since: day) + job.estimatedCostUSD <= schedulerSettings.dailySpendCapUSD
            && store.usageTotalUSD(since: month) + job.estimatedCostUSD <= schedulerSettings.monthlySpendCapUSD
    }

    private func ensureSpendCapsAllowNextJob() throws {
        guard let job = try store.nextRunnableJob(), job.estimatedCostUSD > 0 else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? day
        guard try store.usageTotalUSD(since: day) + job.estimatedCostUSD <= schedulerSettings.dailySpendCapUSD else {
            throw LLMProviderError.requestFailed("Daily spend cap reached.")
        }
        guard try store.usageTotalUSD(since: month) + job.estimatedCostUSD <= schedulerSettings.monthlySpendCapUSD else {
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
            connections: connections
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

    private func makeMetrics() throws -> AppMetrics {
        let tagCount = Set(ideas.flatMap(\.manualTags)).count
        let sourceTypes = Set(sources.map(\.type)).count
        let diversity = min(1, Double(tagCount + sourceTypes) / 12)
        let load = min(1, Double(jobs.filter { $0.status == .pending || $0.status == .running }.count) / 25)
        let avg = ideas.isEmpty ? 0 : ideas.reduce(0) { $0 + $1.ripeness } / Double(ideas.count)
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
        if provider == "Gemini" { return KeychainStore.load(.gemini) }
        if provider == "Z.ai" { return KeychainStore.load(.zai) }
        if provider == "Kimi" { return KeychainStore.load(.kimi) }
        if provider == "OpenAI" { return KeychainStore.load(.openAI) }
        if provider == "Claude" { return KeychainStore.load(.anthropic) }
        return KeychainStore.load(.openAICompatible)
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
        FermentationEngine(store: store, router: makeRouter(), taste: TasteSignals(profile: autonomyProfile, learned: tasteModel))
    }

    // MARK: Learning loop (Phase 6)

    /// Records a taste signal from one of the operator's decisions: +1 when they
    /// commit to an idea (mark Ready, build), −1 when they let an unripe idea die.
    /// The next local pass scores similar ideas accordingly — the taste profile
    /// tuning itself instead of being hand-edited.
    private func reinforceTaste(with idea: IdeaSeed, label: Double) {
        guard label != 0 else { return }
        do {
            let tokens = Tokenizer.vocabulary("\(idea.title) \(idea.body) \(idea.manualTags.joined(separator: " "))")
            guard !tokens.isEmpty else { return }
            let updated = try store.loadTasteModel().reinforced(with: tokens, label: label)
            try store.saveTasteModel(updated)
            tasteModel = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resetLearnedTaste() {
        do {
            try store.saveTasteModel(TasteModel())
            tasteModel = TasteModel()
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

    private func scoutSignals(for mission: ScoutMission) async -> [ScoutSignal] {
        var signals: [ScoutSignal] = []
        if let firecrawlKey = KeychainStore.load(.firecrawl) {
            let firecrawl = FirecrawlSearchProvider()
            signals += (try? await firecrawl.search(query: mission.query, limit: 5, apiKey: firecrawlKey)) ?? []
        }
        if signals.count < 2, let openAIKey = KeychainStore.load(.openAI) {
            let openAI = OpenAIWebSearchProvider()
            signals += (try? await openAI.search(query: mission.query, limit: 5, apiKey: openAIKey)) ?? []
        }
        if signals.isEmpty {
            signals = (try? await AutonomousScout.webSignals(for: mission, limit: 5)) ?? []
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
        return due ?? AutonomousScout.dueMissions(profile: autonomyProfile, missions: scoutMissions.map { mission in
            var copy = mission
            copy.lastRunAt = nil
            return copy
        }, now: now, limit: 1).first
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
