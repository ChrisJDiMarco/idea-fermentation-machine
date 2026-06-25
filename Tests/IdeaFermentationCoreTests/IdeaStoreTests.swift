import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("IdeaStore")
struct IdeaStoreTests {
    @Test func storesSearchesAndDedupesIdeas() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Ambient Memory App", body: "Capture life context privately.", tags: ["memory", "privacy"])

        #expect(try store.idea(id: idea.id).title == "Ambient Memory App")
        #expect(try store.searchIdeas("Ambient").map(\.id).contains(idea.id))
        #expect(try store.semanticIdeas("private life recall").contains { $0.id == idea.id })
        #expect(try store.idea(textHash: idea.textHash)?.id == idea.id)
        #expect(throws: IdeaStoreError.duplicate) {
            _ = try store.createIdea(title: "Ambient Memory App", body: "Capture life context privately.", tags: ["memory", "privacy"])
        }
    }

    @Test func queuesJobsAndSurvivesReopen() throws {
        let folder = try tempFolder()
        let url = folder.appendingPathComponent("ideas.sqlite")
        let store = try IdeaStore(databaseURL: url)
        let idea = try store.createIdea(title: "Taste engine", body: "Learn preferences from sources.")
        let job = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .tag, inputHash: "abc"))

        let reopened = try IdeaStore(databaseURL: url)
        #expect(try reopened.nextRunnableJob()?.id == job.id)
        try reopened.setJobStatus(job.id, status: .complete)
        #expect(try reopened.listJobs(status: .complete).count == 1)
    }

    @Test func storesSourcesCacheAndUsage() throws {
        let store = try makeStore()
        let source = try store.createSource(SourceItem(type: .note, title: "Focus", body: "Best focus happens in 90-minute blocks."))
        #expect(try store.searchSources("focus").first?.id == source.id)
        #expect(try store.source(textHash: source.textHash)?.id == source.id)

        let response = LLMResponse(text: "Tagged as focus.", inputTokens: 10, outputTokens: 4, provider: "mock", model: "cheap")
        try store.saveCache(key: "k", response: response)
        #expect(try store.cachedOutput(for: "k")?.text == "Tagged as focus.")

        try store.saveUsage(LLMUsageRecord(provider: "mock", model: "cheap", taskClass: .tag, inputTokens: 10, outputTokens: 4, estimatedCostUSD: 0.001))
        #expect(try store.usageRecords().count == 1)
    }

    @Test func v2JobLifecycleAndSettingsPersist() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Scheduler", body: "Run local passes on a cadence.")
        let future = Date(timeIntervalSinceNow: 600)
        let job = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .scoreRipeness, scheduledAt: future))

        #expect(try store.dueJobs(now: Date()).isEmpty)
        #expect(try store.dueJobs(now: future.addingTimeInterval(1)).first?.id == job.id)

        try store.markRunning(job.id)
        try store.resumeInterruptedJobs()
        #expect(try store.job(id: job.id).status == .pending)

        try store.markFailed(job.id, error: "provider down", retryAfter: future)
        #expect(try store.job(id: job.id).lastError == "provider down")

        try store.saveSchedulerSettings(SchedulerSettings(localCadenceMinutes: 15, cloudAutoRun: true))
        #expect(try store.loadSchedulerSettings().localCadenceMinutes == 15)

        try store.saveProviderSettings(ProviderSettings(fallbackProviderLabel: "Local Gateway", fallbackBaseURL: "http://localhost:11434/v1/", fallbackModelName: "local-model"))
        #expect(try store.loadProviderSettings().fallbackProviderLabel == "Local Gateway")
    }

    @Test func storesStructuredArtifacts() throws {
        let store = try makeStore()
        let one = try store.createIdea(title: "Memory", body: "Private local memory.")
        let two = try store.createIdea(title: "Recall", body: "Private local recall.")

        try store.saveConnection(IdeaConnection(fromID: one.id, toID: two.id, explanation: "Shared memory surface.", confidence: 0.8))
        try store.saveRipenessScore(RipenessScore(ideaID: one.id, novelty: 70, clarity: 60, evidence: 50, personalResonance: 80, feasibility: 75, timing: 65))
        try store.savePrototypeBrief(PrototypeBrief(ideaID: one.id, audience: "Solo builders", mvpScope: "Small app", risks: "Scope", nextActions: ["Ship"], markdown: "# Brief"))
        try store.saveRun(FermentationRun(status: .complete, jobIDs: [], totalEstimatedCostUSD: 0))

        #expect(try store.connections(for: one.id).count == 1)
        #expect(try store.ripenessScores(for: one.id).isEmpty == false)
        #expect(try store.prototypeBriefs(for: one.id).first?.nextActions == ["Ship"])
        #expect(try store.runs().count == 1)
    }

    @Test func deletingIdeaCascadesToChildRows() throws {
        let store = try makeStore()
        let one = try store.createIdea(title: "Primary idea", body: "Body for primary.", tags: ["alpha"])
        let two = try store.createIdea(title: "Secondary idea", body: "Body for secondary.", tags: ["beta"])
        try store.saveConnection(IdeaConnection(fromID: one.id, toID: two.id, explanation: "Linked.", confidence: 0.7))
        try store.saveRipenessScore(RipenessScore(ideaID: one.id, novelty: 50, clarity: 50, evidence: 50, personalResonance: 50, feasibility: 50, timing: 50))
        try store.saveCritique(IdeaCritique(ideaID: one.id, assumptions: ["a"], risks: ["r"], contradictions: ["c"]))
        try store.savePrototypeBrief(PrototypeBrief(ideaID: one.id, audience: "x", mvpScope: "y", risks: "z", nextActions: ["n"], markdown: "# m"))

        try store.deleteIdea(one.id)

        #expect(try store.connections().isEmpty)
        #expect(try store.ripenessScores(for: one.id).isEmpty)
        #expect(try store.critique(for: one.id) == nil)
        #expect(try store.prototypeBriefs(for: one.id).isEmpty)
        #expect(try store.searchIdeas("Primary").contains { $0.id == one.id } == false)
        // A sibling idea must be left completely untouched by the cascade.
        #expect(try store.idea(id: two.id).title == "Secondary idea")
    }

    @Test func deletingSourceScrubsLinkedIdeaReferences() throws {
        let store = try makeStore()
        let source = try store.createSource(SourceItem(type: .note, title: "Linked source", body: "Evidence body."))
        var idea = try store.createIdea(title: "Idea with source", body: "Has one linked source.")
        idea.sourceIDs = [source.id]
        try store.upsertIdea(idea)

        try store.deleteSource(source.id)

        #expect(try store.idea(id: idea.id).sourceIDs.isEmpty)
        #expect(try store.source(textHash: source.textHash) == nil)
    }

    @Test func autonomyProfileAndScoutMissionsPersist() throws {
        let folder = try tempFolder()
        let url = folder.appendingPathComponent("ideas.sqlite")
        let store = try IdeaStore(databaseURL: url)
        let profile = AutonomyProfile(
            isEnabled: true,
            tasteNotes: "AI-native macOS utilities with local-first defaults.",
            goals: "Find app ideas Chris would actually build.",
            watchTopics: "agents, macOS, ambient memory",
            excludedTopics: "crypto games",
            preferredOutputs: "idea brief, mockup prompt"
        )
        let mission = ScoutMission(title: "Mac AI utility scout", query: "AI-native macOS productivity apps")

        try store.saveAutonomyProfile(profile)
        try store.saveScoutMissions([mission])

        let reopened = try IdeaStore(databaseURL: url)
        #expect(try reopened.loadAutonomyProfile() == profile)
        #expect(try reopened.loadScoutMissions().first?.query == mission.query)
    }
}

func makeStore() throws -> IdeaStore {
    try IdeaStore(databaseURL: tempFolder().appendingPathComponent("ideas.sqlite"))
}

func tempFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ifm-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
