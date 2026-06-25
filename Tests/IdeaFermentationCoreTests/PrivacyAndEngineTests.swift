import Foundation
import Testing
@testable import IdeaFermentationCore

struct MockProvider: LLMProvider {
    let providerName = "Mock"
    let availableModels = [
        LLMModel(provider: "Mock", name: "mock-cheap", displayName: "Mock Cheap", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(text: "mock output for \(request.taskClass.rawValue)", inputTokens: 10, outputTokens: 10, provider: providerName, model: model.name)
    }
}

struct EchoInputProvider: LLMProvider {
    let providerName = "Echo"
    let availableModels = [
        LLMModel(provider: "Echo", name: "echo", displayName: "Echo", inputCostPerMillion: 0, outputCostPerMillion: 0, pricingURL: "local", verifiedOn: "test")
    ]

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(text: request.input, inputTokens: 10, outputTokens: 10, provider: providerName, model: model.name)
    }
}

@Suite("Privacy and engine")
@MainActor
struct PrivacyAndEngineTests {
    @Test func privacyPreviewExcludesBlockedSources() throws {
        let idea = IdeaSeed(title: "Private wiki", body: "Connect my notes.")
        let blocked = SourceItem(type: .note, title: "Secret", body: "do not send", neverSendToCloud: true)
        let allowed = SourceItem(type: .note, title: "Allowed", body: "ok")
        let preview = PrivacyPolicy.preview(idea: idea, sources: [blocked, allowed], taskClass: .connect)

        #expect(preview.maySend)
        #expect(preview.blockedSourceTitles == ["Secret"])
        #expect(!preview.payload.contains("do not send"))
        #expect(preview.payload.contains("Allowed"))
    }

    @Test func engineRunsPendingJobAndCachesOutput() async throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "AI Taste Layer", body: "Recommendations plus serendipity.")
        let model = MockProvider().availableModels[0]
        let router = ModelRouter(models: [model], budget: AppBudget(approvalThresholdUSD: 99), providerPriority: ["Mock"])
        let engine = FermentationEngine(store: store, router: router)
        _ = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .tag, modelRoute: router.route(taskClass: .tag, inputTokens: 10, outputTokens: 10), inputHash: "x"))

        let response = try await engine.runNext(provider: MockProvider(), apiKey: "test")
        #expect(response?.text.contains("mock output") == true)
        #expect(try store.listJobs(status: .complete).count == 1)
        #expect(try store.runLogs().count == 1)
    }

    @Test func localPassScoresAndMovesInboxIdeas() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Private local AI prototype", body: "Build an MVP workflow for a user to test private memory context.", tags: ["ai", "prototype"])
        let engine = FermentationEngine(store: store)
        let updated = try engine.runLocalPass(maxIdeas: 5)

        #expect(updated.count == 1)
        #expect(try store.idea(id: idea.id).status != .inbox)
        #expect(try store.runLogs().count == 1)
    }

    @Test func localPipelinePersistsConnectionsScoresAndBriefs() throws {
        let store = try makeStore()
        let sourceIDs = try (0..<6).map { index in
            try store.createSource(SourceItem(type: .note, title: "Evidence \(index)", body: "Private local AI prototype workflow evidence \(index).")).id
        }
        let idea = IdeaSeed(
            title: "Private local AI prototype",
            body: String(repeating: "Build a private local AI agent ambient memory context prototype workflow for real user tests. ", count: 20),
            status: .fermenting,
            stage: .brewing,
            sourceIDs: sourceIDs,
            manualTags: ["ai", "prototype", "workflow", "local", "memory"],
            textHash: TextHashing.sha256(UUID().uuidString),
            embedding: LocalEmbeddings.embed("private local ai prototype workflow")
        )
        try store.upsertIdea(idea)
        try store.upsertIdea(IdeaSeed(title: "Local workflow memory", body: "Private local AI workflow recall.", textHash: TextHashing.sha256(UUID().uuidString), embedding: LocalEmbeddings.embed("private local ai prototype workflow recall")))

        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 10)

        #expect(try store.ripenessScores(for: idea.id).isEmpty == false)
        #expect(try store.connections(for: idea.id).isEmpty == false)
        #expect(try store.prototypeBriefs(for: idea.id).isEmpty == false)
    }

    @Test func dueSourceJobLinksIdeasLocally() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Ambient memory", body: "Private local recall for daily context.")
        let source = try store.createSource(SourceItem(type: .note, title: "Memory note", body: "Private local recall for daily context and ambient memory."))
        _ = try store.enqueue(FermentationJob(sourceID: source.id, taskClass: .summarize))

        let engine = FermentationEngine(store: store)
        _ = try engine.runDueLocalJobs(maxJobs: 5)

        #expect(try store.source(id: source.id).linkedIdeaIDs.contains(idea.id))
        #expect(try store.listJobs(status: .complete).count == 1)
    }

    @Test func cloudRunsIncludeBoundedAgentLearningContext() async throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "Old CRM", body: "Paused because onboarding was too broad.", tags: ["onboarding"], status: .archived)
        let idea = try store.createIdea(title: "Focused CRM", body: "Try a narrow customer follow-up workflow.")
        let model = EchoInputProvider().availableModels[0]
        let router = ModelRouter(models: [model], budget: AppBudget(approvalThresholdUSD: 99), providerPriority: ["Echo"])
        _ = try store.enqueue(FermentationJob(
            ideaID: idea.id,
            taskClass: .tag,
            modelRoute: router.route(taskClass: .tag, inputTokens: 10, outputTokens: 10),
            inputHash: "x"
        ))

        let engine = FermentationEngine(store: store, router: router)
        _ = try await engine.runNext(provider: EchoInputProvider(), apiKey: "test")

        let output = try #require(store.runLogs().first?.output)
        #expect(output.contains("Local agent memory"))
        #expect(output.contains("Archive lesson: Old CRM"))
        #expect(output.count < 4_000)
    }
}
