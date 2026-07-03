import Foundation
import Testing
@testable import IdeaFermentationCore

/// Returns a fixed scripted reply regardless of input — used to drive a specific cloud
/// task result deterministically. The model name contains "pro" so the `.deepen` router
/// treats it as a capable judgment model.
private struct ScriptedProvider: LLMProvider {
    let providerName = "Scripted"
    let reply: String
    let availableModels = [
        LLMModel(provider: "Scripted", name: "scripted-pro", displayName: "Scripted", inputCostPerMillion: 0, outputCostPerMillion: 0, pricingURL: "local", verifiedOn: "test")
    ]
    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(text: reply, inputTokens: 10, outputTokens: 10, provider: providerName, model: model.name)
    }
}

@Suite("Growth and quality gate")
@MainActor
struct GrowthAndQualityGateTests {
    private func scriptedEngine(_ store: IdeaStore) -> (ModelRouter, LLMModel) {
        let model = LLMModel(provider: "Scripted", name: "scripted-pro", displayName: "Scripted", inputCostPerMillion: 0, outputCostPerMillion: 0, pricingURL: "local", verifiedOn: "test")
        return (ModelRouter(models: [model], budget: AppBudget(approvalThresholdUSD: 99), providerPriority: ["Scripted"]), model)
    }

    // MARK: - Ideas actually grow (.deepen)

    @Test func deepenGrowsBodyAndSnapshotsOriginalVersion() async throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Ambient recall", body: "A small note about ambient memory.")
        let (router, _) = scriptedEngine(store)
        let job = try store.enqueue(FermentationJob(
            ideaID: idea.id, taskClass: .deepen,
            modelRoute: router.route(taskClass: .deepen, inputTokens: 10, outputTokens: 10),
            inputHash: "deepen-1"
        ))
        let matured = "Ambient recall becomes a passive daily memory layer that resurfaces the right note at the right moment, grounded in your own captures. The smallest test: one week of self-use with a single trigger, measuring whether the right note appears unprompted."
        let reply = "{\"title\":\"Ambient recall\",\"body\":\"\(matured)\",\"tags\":[\"memory\",\"ambient\"]}"

        let engine = FermentationEngine(store: store, router: router)
        _ = try await engine.runJob(job, provider: ScriptedProvider(reply: reply), apiKey: "test")

        let grown = try store.idea(id: idea.id)
        #expect(grown.body == matured)              // the idea's actual CONTENT changed
        #expect(grown.body.count > idea.body.count) // and it grew
        #expect(grown.bodyVersion == 2)

        // The original text is preserved as a reversible snapshot.
        let versions = try store.bodyVersions(for: idea.id)
        #expect(versions.count == 1)
        #expect(versions.first?.body == "A small note about ambient memory.")
        #expect(versions.first?.source == "original")
    }

    @Test func deepenIgnoresUndecodableOutputAndLeavesIdeaUntouched() async throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Untouched", body: "The original body that must survive a garbage cloud reply.")
        let (router, _) = scriptedEngine(store)
        let job = try store.enqueue(FermentationJob(
            ideaID: idea.id, taskClass: .deepen,
            modelRoute: router.route(taskClass: .deepen, inputTokens: 10, outputTokens: 10),
            inputHash: "deepen-garbage"
        ))

        let engine = FermentationEngine(store: store, router: router)
        _ = try await engine.runJob(job, provider: ScriptedProvider(reply: "sorry, I can't help with that."), apiKey: "test")

        let after = try store.idea(id: idea.id)
        #expect(after.body == "The original body that must survive a garbage cloud reply.")
        #expect(after.bodyVersion == 1)
        #expect(try store.bodyVersions(for: idea.id).isEmpty) // nothing snapshotted, nothing clobbered
    }

    @Test func deepenRejectsSuspiciouslyShortRewrite() async throws {
        // A rewrite that collapses the idea to a fragment is treated as a bad pass, not growth.
        let store = try makeStore()
        let long = String(repeating: "A carefully developed idea about local-first ambient memory tooling. ", count: 6)
        let idea = try store.createIdea(title: "Keep it", body: long)
        let (router, _) = scriptedEngine(store)
        let job = try store.enqueue(FermentationJob(
            ideaID: idea.id, taskClass: .deepen,
            modelRoute: router.route(taskClass: .deepen, inputTokens: 10, outputTokens: 10),
            inputHash: "deepen-short"
        ))
        let reply = "{\"title\":\"Keep it\",\"body\":\"too short\",\"tags\":[]}"

        let engine = FermentationEngine(store: store, router: router)
        _ = try await engine.runJob(job, provider: ScriptedProvider(reply: reply), apiKey: "test")

        let after = try store.idea(id: idea.id)
        #expect(after.body == long)          // the substantial original was NOT replaced by a fragment
        #expect(after.bodyVersion == 1)
    }

    // MARK: - Quality gate on Ready

    @Test func promotionGateRequiresQualityVerificationForReady() {
        // A ready-scoring idea that has NOT been cloud-verified is held at Ripening…
        #expect(FermentationEngine.promotion(ripeness: 92, qualityVerified: false, current: .ripening)?.0 == .ripening)
        // …and the same score, once a real cloud pass verified it, is allowed to reach Ready.
        #expect(FermentationEngine.promotion(ripeness: 92, qualityVerified: true, current: .ripening)?.0 == .ready)
        // Mid-range scores land at Ripening regardless of verification.
        #expect(FermentationEngine.promotion(ripeness: 60, qualityVerified: false, current: .fermenting)?.0 == .ripening)
        // A fresh low-scoring inbox idea starts fermenting.
        #expect(FermentationEngine.promotion(ripeness: 10, qualityVerified: false, current: .inbox)?.0 == .fermenting)
    }

    @Test func localPassNeverPromotesUnverifiedBulkToReady() throws {
        // A verbose, heavily-tagged, source-stuffed idea — the exact "gameable" shape — must
        // not reach Ready on local arithmetic alone, and gets no build brief.
        let store = try makeStore()
        let sourceIDs = try (0..<6).map { i in
            try store.createSource(SourceItem(type: .note, title: "Evidence \(i)", body: "Local AI prototype workflow evidence \(i) for real user tests.")).id
        }
        let idea = IdeaSeed(
            title: "Bulky unverified idea",
            body: String(repeating: "Build a private local AI agent ambient memory context prototype workflow to ship and test with a real user. ", count: 22),
            status: .fermenting, stage: .brewing,
            sourceIDs: sourceIDs,
            manualTags: ["ai", "prototype", "workflow", "local", "memory"],
            textHash: TextHashing.sha256(UUID().uuidString),
            embedding: LocalEmbeddings.embed("private local ai prototype workflow")
            // qualityVerified defaults to false
        )
        try store.upsertIdea(idea)

        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 10)

        let scored = try store.idea(id: idea.id)
        #expect(scored.status != .ready)
        #expect(scored.qualityVerified == false)
        #expect(try store.prototypeBriefs(for: idea.id).isEmpty)
    }
}
