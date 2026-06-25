import Foundation
import Testing
@testable import IdeaFermentationCore

@MainActor
@Suite("Semantic v2 upgrades")
struct SemanticUpgradeTests {
    /// Novelty now means "unlike anything you've already captured", not "uses a
    /// buzzword". An idea distant from the corpus must out-score a near-duplicate —
    /// even though both are written in the same on-taste vocabulary.
    @Test func noveltyRewardsDistanceFromCorpus() throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "Memory app one", body: "A private local AI memory agent that recalls your daily context.", tags: ["memory"])
        _ = try store.createIdea(title: "Memory app two", body: "A private local AI memory agent that recalls your daily context, varied.", tags: ["memory"])
        let derivative = try store.createIdea(title: "Memory app three", body: "A private local AI memory agent that recalls your daily context once more.", tags: ["memory"])
        // Same on-taste vocabulary (ai/agent/ambient/local) but a completely different domain.
        let novel = try store.createIdea(title: "Weather music agent", body: "An autonomous local AI agent that turns ambient weather sensor data into generative music.", tags: ["music"])

        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 10)

        let novelNovelty = try store.idea(id: novel.id).novelty
        let derivativeNovelty = try store.idea(id: derivative.id).novelty
        #expect(novelNovelty > derivativeNovelty)
    }

    /// A failed/empty embedding (all zeros) must NOT read as "maximally distant" and
    /// win full novelty — it carries no signal, so novelty falls back to the lexical
    /// score regardless of the corpus.
    @Test func zeroVectorEmbeddingDoesNotInflateNovelty() {
        let blank = IdeaSeed(title: "ai agent", body: "x", manualTags: ["ai"], embedding: Array(repeating: 0.0, count: 8))
        let real = IdeaSeed(title: "weather music", body: "y", embedding: [0.1, 0.2, 0.3, 0, 0, 0, 0, 0])
        let tokens = Tokenizer.vocabulary("ai agent")

        let withCorpus = FermentationEngine.noveltyScore(for: blank, tokens: tokens, interestOverlap: 0, tagBoost: 3, corpus: [blank, real])
        let aloneInCorpus = FermentationEngine.noveltyScore(for: blank, tokens: tokens, interestOverlap: 0, tagBoost: 3, corpus: [blank])

        // A zero-vector idea scores the same whether or not a corpus exists — the
        // meaningless "distance" never moves the score. (Pre-fix, withCorpus inflated.)
        #expect(withCorpus == aloneInCorpus)
        #expect(withCorpus < 100)
    }

    /// Calibration guard for scout routing: two same-topic phrasings must clear the
    /// strong-match floor (so the scout attaches), and an unrelated one must fall
    /// below it (so the scout starts a fresh idea). Locks the floor to the active
    /// embedding backend's distribution.
    @Test func strongMatchFloorSeparatesSameTopicFromUnrelated() {
        let a = LocalEmbeddings.embed("ambient memory apps for macOS that recall your daily context")
        let b = LocalEmbeddings.embed("a macOS app for ambient memory that recalls your daily context")
        let c = LocalEmbeddings.embed("quarterly tax accounting spreadsheet for small business invoices")
        #expect(LocalEmbeddings.cosine(a, b) >= LocalEmbeddings.strongMatchFloor)
        #expect(LocalEmbeddings.cosine(a, c) < LocalEmbeddings.strongMatchFloor)
    }

    /// The synthesis JSON extractor survives a chatty model reply (fences + prose)
    /// and rejects junk / empty seeds.
    @Test func decodesSeedFromChattyModelReply() {
        let fenced = "Sure! Here it is:\n```json\n{\"title\":\"Ambient recall\",\"body\":\"An idea body.\",\"tags\":[\"memory\",\"ai\"]}\n```\nHope it helps."
        let seed = AutonomousScout.decodeSeed(from: fenced)
        #expect(seed?.title == "Ambient recall")
        #expect(seed?.tags == ["memory", "ai"])

        #expect(AutonomousScout.decodeSeed(from: "{\"title\":\"X\",\"body\":\"Y\",\"tags\":[]}")?.title == "X")
        #expect(AutonomousScout.decodeSeed(from: "no json here at all") == nil)
        #expect(AutonomousScout.decodeSeed(from: "{\"title\":\"\",\"body\":\"\",\"tags\":[]}") == nil)
    }

    /// The scout synthesis path calls the provider and decodes an original seed.
    @Test func synthesizeCallsProviderAndReturnsSeed() async throws {
        let provider = SeedProvider()
        let seed = try await AutonomousScout.synthesize(
            profile: AutonomyProfile(tasteNotes: "local-first AI tools"),
            mission: ScoutMission(title: "m", query: "ambient memory"),
            signals: [ScoutSignal(title: "Signal", summary: "A trend worth noting.")],
            provider: provider,
            model: provider.availableModels[0],
            apiKey: "test"
        )
        #expect(seed?.title == "Synthesized idea")
        #expect(seed?.body.contains("from the signals") == true)
    }
}

private struct SeedProvider: LLMProvider {
    let providerName = "Seed"
    let availableModels = [
        LLMModel(provider: "Seed", name: "seed-1", displayName: "Seed", inputCostPerMillion: 0, outputCostPerMillion: 0, pricingURL: "local", verifiedOn: "test")
    ]
    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(
            text: "{\"title\":\"Synthesized idea\",\"body\":\"Built from the signals.\",\"tags\":[\"memory\"]}",
            inputTokens: 1, outputTokens: 1, provider: providerName, model: model.name
        )
    }
}
