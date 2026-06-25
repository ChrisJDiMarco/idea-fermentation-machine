import Foundation
import Testing
@testable import IdeaFermentationApp
@testable import IdeaFermentationCore

@MainActor
@Suite("ShellViewModel")
struct ShellViewModelTests {
    @Test func startsEmptyWithoutMockData() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)

        #expect(model.ideas.isEmpty)
        #expect(model.sources.isEmpty)
        #expect(model.jobs.isEmpty)
    }

    @Test func addIdeaUpdatesInbox() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        let before = model.count(for: IFMPage.inbox)
        model.addIdea(title: "Test seed", body: "hello", tags: "test")
        #expect(model.count(for: IFMPage.inbox) == before + 1)
    }

    @Test func duplicateIdeaCaptureSelectsExistingIdea() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)

        model.addIdea(title: "Same seed", body: "same body", tags: "same")
        model.addIdea(title: "Same seed", body: "same body", tags: "same")

        #expect(model.ideas.count == 1)
        #expect(model.selectedPage == .inbox)
        #expect(model.errorMessage?.contains("Already captured") == true)
    }

    @Test func localPassMovesRealIdeaForward() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.addIdea(title: "Local AI workflow", body: "Build a prototype workflow for users to test with local private context.", tags: "ai, prototype, workflow")
        model.runLocalFermentation()
        #expect(model.count(for: IFMPage.inbox) == 0)
        #expect(model.count(for: IFMPage.fermenting) + model.count(for: IFMPage.ripening) + model.count(for: IFMPage.ready) == 1)
        #expect(model.logs.count == 1)
    }

    @Test func schedulerSettingsUpdateViewModel() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.updateScheduler(SchedulerSettings(localCadenceMinutes: 15, maxLocalJobsPerPass: 3, cloudAutoRun: true))

        #expect(model.schedulerSettings.localCadenceMinutes == 15)
        #expect(model.schedulerSettings.maxLocalJobsPerPass == 3)
        #expect(model.schedulerSettings.cloudAutoRun)
    }

    @Test func spendCapUpdatesIgnoreInvalidNumbers() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)

        model.updateDailySpendCap("2.50")
        model.updateMonthlySpendCap("bad")

        #expect(model.schedulerSettings.dailySpendCapUSD == 2.5)
        #expect(model.schedulerSettings.monthlySpendCapUSD == SchedulerSettings().monthlySpendCapUSD)
    }

    @Test func providerKeyDraftOnlySavesNonBlankKeys() {
        var draft = ProviderKeyDraft()
        draft.gemini = "  gem-key  "
        draft.openAI = ""
        draft.firecrawl = "  "
        draft.anthropic = "claude-key"

        let updates = draft.nonEmptyKeyUpdates

        #expect(updates.map(\.key) == [.gemini, .anthropic])
        #expect(updates.map(\.value) == ["gem-key", "claude-key"])
    }

    @Test func ripeningChangesOnlyShowsToday() {
        let viewModel = RipeningPageViewModel()
        let oldDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let today = SourceItem(type: .note, title: "Today", body: "fresh")
        let old = SourceItem(type: .note, title: "Old", body: "stale", createdAt: oldDate)

        viewModel.configure(ideas: [], sources: [old, today])

        #expect(viewModel.changes.map(\.title) == ["Today"])
    }

    @Test func importingUnreadableImageStillCreatesVisibleSource() throws {
        let folder = try appTempFolder()
        let imageURL = folder.appendingPathComponent("whiteboard-capture.webp")
        try Data("not actually an image".utf8).write(to: imageURL)

        let store = try IdeaStore(databaseURL: folder.appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.importFile(url: imageURL)

        #expect(model.sources.count == 1)
        #expect(model.sources[0].type == .screenshot)
        #expect(model.sources[0].filePath != imageURL.path)
        #expect(model.sources[0].extractionStatus == .failed)
        #expect(model.jobs.count == 1)
        #expect(model.selectedPage == .sources)
        #expect(model.errorMessage?.contains("Imported") == true)
    }

    @Test func ideaActionsUpdateRecordsAndPersistBriefs() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.addIdea(title: "Launchable seed", body: "Small prototype with clear audience.", tags: "prototype")
        let idea = try #require(model.ideas.first)

        model.markIdeaReady(idea)
        #expect(model.count(for: .ready) == 1)

        model.createBuildPlan(for: model.ready.items[0])
        model.createBuildPlan(for: model.ready.items[0])
        #expect(model.briefs.count == 1)
        #expect(model.errorMessage?.contains("Build plan") == true)
        #expect(model.briefs[0].markdown.contains("## Build Handoff"))
        #expect(model.briefs[0].markdown.contains("## Acceptance Checks"))

        model.archiveIdea(model.ready.items[0])
        #expect(model.count(for: .archive) == 1)

        model.resurfaceIdea(model.archive.items[0])
        #expect(model.count(for: .inbox) == 1)
    }

    @Test func buildPlanIsASelfContainedImplementationPacket() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let source = try store.createSource(SourceItem(type: .note, title: "User pain note", body: "People keep losing context between meetings."))
        let model = ShellViewModel(store: store)
        model.addIdea(title: "Meeting memory", body: "Capture and recall meeting context locally and privately.", tags: "memory, ai")
        var idea = try #require(model.ideas.first)
        idea.sourceIDs = [source.id]
        try store.upsertIdea(idea)
        model.reload()
        model.runLocalFermentation() // produces a critique the handoff can cite
        model.markIdeaReady(try #require(model.ideas.first))

        model.createBuildPlan(for: try #require(model.ready.items.first))
        let markdown = try #require(model.briefs.first).markdown

        #expect(markdown.contains("## Build Handoff"))
        #expect(markdown.contains("## Evidence"))
        #expect(markdown.contains("User pain note"))
        #expect(markdown.contains("## Implementation Prompt"))
        #expect(markdown.contains("## Acceptance Checks"))
    }

    @Test func perIdeaAgentJobsQueueOnceAndRouteToCostCenter() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.addIdea(title: "Ripening workflow", body: "Needs critique and a prototype brief.", tags: "workflow")
        let idea = try #require(model.ideas.first)

        model.queueCritique(for: idea)
        model.queueCritique(for: idea)
        model.queuePrototypeBrief(for: idea)

        #expect(model.selectedPage == .costCenter)
        #expect(model.jobs.filter { $0.ideaID == idea.id && $0.taskClass == .critique }.count == 1)
        #expect(model.jobs.filter { $0.ideaID == idea.id && $0.taskClass == .prototypeBrief }.count == 1)
        #expect(model.errorMessage?.contains("queued") == true || model.errorMessage?.contains("needs approval") == true)
    }

    @Test func queueControlsPauseResumeAndRetrySafely() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let localJob = try store.enqueue(FermentationJob(taskClass: .summarize, status: .pending, inputHash: "local"))
        let route = ModelRoute(provider: "Claude", model: "claude-test", taskClass: .prototypeBrief, rationale: "test", estimatedCostUSD: 0.25, needsApproval: true)
        let cloudJob = try store.enqueue(FermentationJob(taskClass: .prototypeBrief, status: .failed, retryCount: 1, estimatedCostUSD: 0.25, modelRoute: route, inputHash: "cloud", lastError: "no key", retryAfter: Date()))
        let model = ShellViewModel(store: store)

        model.pauseJob(localJob)
        #expect(try store.job(id: localJob.id).status == .paused)

        model.resumeJob(try store.job(id: localJob.id))
        #expect(try store.job(id: localJob.id).status == .pending)

        model.retryJob(cloudJob)
        let retried = try store.job(id: cloudJob.id)
        #expect(retried.status == .needsApproval)
        #expect(retried.lastError == nil)
        #expect(retried.retryAfter == nil)
    }

    @Test func launchDashboardExportsBuildPlans() throws {
        let folder = try appTempFolder()
        let store = try IdeaStore(databaseURL: folder.appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.addIdea(title: "Exportable idea", body: "A brief worth opening.", tags: "prototype")
        model.markIdeaReady(try #require(model.ideas.first))
        model.createBuildPlan(for: try #require(model.ready.items.first))
        model.createBuildPlan(for: try #require(model.ready.items.first))

        let exported = try model.exportBuildPlans(to: folder.appendingPathComponent("briefs", isDirectory: true))

        #expect(exported.count == 1)
        #expect(FileManager.default.fileExists(atPath: exported[0].path))
        let markdown = try String(contentsOf: exported[0], encoding: .utf8)
        #expect(markdown.contains("Exportable idea"))
        #expect(markdown.contains("## Build Handoff"))
    }

    @Test func sourceActionsToggleCreateIdeaQueueAndDelete() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        let source = try store.createSource(SourceItem(type: .note, title: "Signal note", body: "A concrete source about a product idea."))
        model.reload()

        model.toggleNeverSend(source)
        #expect(model.sources[0].neverSendToCloud)

        model.createIdea(from: model.sources[0])
        #expect(model.ideas.count == 1)

        model.queueSourceAnalysis(model.sources[0])
        #expect(model.jobs.count == 1)

        model.deleteSource(model.sources[0])
        #expect(model.sources.isEmpty)
    }

    @Test func duplicateSourceCaptureSelectsExistingSourceWithoutQueueingWork() async throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.sourceDraft.title = "Same source"
        model.sourceDraft.body = "same material"

        await model.saveSourceDraftAsync()
        await model.saveSourceDraftAsync()

        #expect(model.sources.count == 1)
        #expect(model.jobs.count == 1)
        #expect(model.selectedPage == .sources)
        #expect(model.errorMessage?.contains("Already captured") == true)
    }

    @Test func pendingCloudPreviewExcludesBlockedSourcesAndApprovesOneJob() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let allowed = try store.createSource(SourceItem(type: .note, title: "Allowed", body: "ok to send"))
        let blocked = try store.createSource(SourceItem(type: .note, title: "Blocked", body: "do not send", neverSendToCloud: true))
        var idea = try store.createIdea(title: "Private agent", body: "Needs synthesis.")
        idea.sourceIDs = [allowed.id, blocked.id]
        try store.upsertIdea(idea)
        let route = ModelRoute(provider: "Gemini", model: "gemini-test", taskClass: .prototypeBrief, rationale: "test", estimatedCostUSD: 0.25, needsApproval: true)
        let first = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .prototypeBrief, status: .needsApproval, estimatedCostUSD: 0.25, modelRoute: route))
        _ = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .prototypeBrief, status: .needsApproval, estimatedCostUSD: 0.25, modelRoute: route))
        let model = ShellViewModel(store: store)

        let preview = try #require(model.pendingCloudPreview)

        #expect(preview.job.id == first.id)
        #expect(preview.payload.blockedSourceTitles == ["Blocked"])
        #expect(preview.payload.payload.contains("ok to send"))
        #expect(!preview.payload.payload.contains("do not send"))

        model.approveJob(preview.job)

        #expect(model.jobs.filter { $0.status == .needsApproval }.count == 1)
        #expect(model.jobs.contains { $0.id == first.id && $0.status == .pending })
    }

    @Test func blockedSourceApprovalWorksAfterPrivacyToggle() throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let blocked = try store.createSource(SourceItem(type: .note, title: "Blocked only", body: "private signal", neverSendToCloud: true))
        let route = ModelRoute(provider: "Gemini", model: "gemini-test", taskClass: .summarize, rationale: "test", estimatedCostUSD: 0.10, needsApproval: true)
        _ = try store.enqueue(FermentationJob(sourceID: blocked.id, taskClass: .summarize, status: .needsApproval, estimatedCostUSD: 0.10, modelRoute: route))
        let model = ShellViewModel(store: store)

        let blockedPreview = try #require(model.pendingCloudPreview)
        #expect(!blockedPreview.payload.maySend)
        model.approveJob(blockedPreview.job)
        #expect(model.jobs[0].status == .needsApproval)

        model.toggleNeverSend(model.sources[0])
        let allowedPreview = try #require(model.pendingCloudPreview)
        #expect(allowedPreview.payload.maySend)
        model.approveJob(allowedPreview.job)

        #expect(model.jobs[0].status == .pending)
    }

    @Test func autonomousScoutCreatesSourceBackedIdea() async throws {
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.autonomyProfile = AutonomyProfile(
            isEnabled: true,
            tasteNotes: "Local-first AI tools with a strong product hook.",
            goals: "Find small apps worth prototyping.",
            watchTopics: "macOS agents, ambient memory",
            preferredOutputs: "prototype brief"
        )
        model.scoutMissions = [
            ScoutMission(title: "Ambient app scout", query: "ambient AI memory apps")
        ]
        try model.saveAutonomyConfiguration()

        await model.runAutonomousScout(useWeb: false)

        #expect(model.sources.count == 1)
        #expect(model.ideas.count == 1)
        #expect(model.ideas[0].sourceIDs == [model.sources[0].id])
        #expect(model.jobs.isEmpty == false)
    }

    @Test func scheduledScoutOnlyRunsDueEligibleMissions() async throws {
        let now = Date()
        let store = try IdeaStore(databaseURL: appTempFolder().appendingPathComponent("ideas.sqlite"))
        let model = ShellViewModel(store: store)
        model.autonomyProfile = AutonomyProfile(isEnabled: true, watchTopics: "mac agents", allowWebScouting: false)
        model.scoutMissions = [
            ScoutMission(title: "Too soon", query: "ambient memory", cadenceHours: 24, lastRunAt: now),
            ScoutMission(title: "Due", query: "local AI tools", cadenceHours: 24, lastRunAt: now.addingTimeInterval(-25 * 60 * 60))
        ]
        try model.saveAutonomyConfiguration()

        let ran = await model.runAutonomousScout(useWeb: false, scheduledOnly: true, now: now)

        #expect(ran)
        #expect(model.sources.count == 1)
        #expect(model.ideas.first?.title == "Due")
        #expect(abs((model.scoutMissions.first { $0.title == "Too soon" }?.lastRunAt ?? .distantPast).timeIntervalSince(now)) < 1)
        #expect(model.scoutMissions.first { $0.title == "Due" }?.lastRunAt ?? .distantPast > now.addingTimeInterval(-5))
    }
}

private func appTempFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ifm-app-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
