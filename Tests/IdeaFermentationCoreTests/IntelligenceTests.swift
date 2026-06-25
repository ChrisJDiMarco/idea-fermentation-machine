import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Intelligence layer")
struct IntelligenceTests {
    // MARK: Deterministic embeddings

    @Test func embeddingsAreDeterministic() {
        let text = "Ambient memory for private local AI agents"
        let first = LocalEmbeddings.embed(text)
        let second = LocalEmbeddings.embed(text)
        #expect(first == second)
        #expect(first.count == LocalEmbeddings.dimensions)
        #expect(first.contains { $0 != 0 })
    }

    @Test func cosineRewardsSharedVocabulary() {
        let base = LocalEmbeddings.embed("private local ai memory agent")
        let near = LocalEmbeddings.embed("a local private memory agent powered by ai")
        let far = LocalEmbeddings.embed("quarterly tax invoice spreadsheet accounting")
        #expect(LocalEmbeddings.cosine(base, near) > LocalEmbeddings.cosine(base, far))
        #expect(LocalEmbeddings.cosine(base, near) > 0.5)
        #expect(LocalEmbeddings.cosine(base, base) > 0.999)
    }

    /// The headline regression guard: a vector written to disk in one "process"
    /// must still be meaningful when read back in another. With `String.hashValue`
    /// this silently failed; with FNV-1a it holds.
    @Test func semanticSearchSurvivesStoreReopen() throws {
        let folder = try tempFolder()
        let url = folder.appendingPathComponent("ideas.sqlite")
        let store = try IdeaStore(databaseURL: url)
        let idea = try store.createIdea(
            title: "Ambient memory app",
            body: "Private local recall of daily context.",
            tags: ["memory", "ambient"]
        )

        let reopened = try IdeaStore(databaseURL: url)
        let hits = try reopened.semanticIdeas("private daily context recall")
        #expect(hits.contains { $0.id == idea.id })

        let stored = try reopened.idea(id: idea.id)
        let expected = LocalEmbeddings.embed("Ambient memory app\nPrivate local recall of daily context.\nmemory ambient")
        #expect(stored.embedding == expected)
    }

    @Test func migrationRecomputesLegacyEmbeddings() throws {
        let folder = try tempFolder()
        let url = folder.appendingPathComponent("ideas.sqlite")
        let store = try IdeaStore(databaseURL: url)
        let idea = try store.createIdea(title: "Ambient memory", body: "Private local recall.", tags: ["memory"])
        let good = try store.idea(id: idea.id).embedding

        // Simulate a database written by an older build: corrupt the persisted
        // vector and roll the schema version back so the next open re-embeds.
        do {
            let raw = try SQLiteDatabase(path: url.path)
            try raw.execute("UPDATE idea_seeds SET embedding = ? WHERE id = ?", [.text("[0,0,0]"), .text(idea.id.uuidString)])
            try raw.execute("PRAGMA user_version = 2")
        }

        let reopened = try IdeaStore(databaseURL: url)
        let fixed = try reopened.idea(id: idea.id).embedding
        #expect(fixed == good)
        #expect(fixed.contains { $0 != 0 })
    }

    // MARK: Connection de-duplication

    @Test func connectionsDedupeByUnorderedPair() throws {
        let store = try makeStore()
        let a = try store.createIdea(title: "A", body: "memory recall")
        let b = try store.createIdea(title: "B", body: "memory recall")

        try store.saveConnection(IdeaConnection(fromID: a.id, toID: b.id, explanation: "first", confidence: 0.4))
        try store.saveConnection(IdeaConnection(fromID: b.id, toID: a.id, explanation: "second", confidence: 0.9))

        let all = try store.connections()
        #expect(all.count == 1)
        #expect(all.first?.confidence == 0.9)
        #expect(all.first?.explanation == "second")
        #expect(try store.connections(for: a.id).count == 1)
    }

    // MARK: Privacy gate

    @Test func sourcelessIdeaIsStillSendable() {
        let idea = IdeaSeed(title: "Solo idea", body: "Worth exploring with a model.")
        #expect(PrivacyPolicy.preview(idea: idea, sources: [], taskClass: .critique).maySend)
    }

    @Test func allBlockedSourcesStillAllowsIdeaBody() {
        let idea = IdeaSeed(title: "Has body", body: "The idea text itself is fine to send.")
        let blocked = SourceItem(type: .note, title: "Secret", body: "do not send", neverSendToCloud: true)
        let preview = PrivacyPolicy.preview(idea: idea, sources: [blocked], taskClass: .connect)
        #expect(preview.maySend)
        #expect(!preview.payload.contains("do not send"))
        #expect(preview.blockedSourceTitles == ["Secret"])
    }

    @Test func emptyIdeaWithOnlyBlockedSourcesCannotSend() {
        let idea = IdeaSeed(title: "", body: "")
        let blocked = SourceItem(type: .note, title: "Secret", body: "private", neverSendToCloud: true)
        #expect(!PrivacyPolicy.preview(idea: idea, sources: [blocked], taskClass: .connect).maySend)
    }

    // MARK: Taste-aware local scoring

    @Test @MainActor func tasteProfileLiftsResonanceForWatchedTopics() throws {
        let store = try makeStore()
        let onTaste = try store.createIdea(title: "Ambient memory agent", body: "A private local AI memory agent that recalls context.", tags: ["ai"])
        let offTaste = try store.createIdea(title: "Garden hose reel", body: "A spring-loaded reel for coiling a garden hose in the yard.", tags: ["garden"])
        let taste = TasteSignals(profile: AutonomyProfile(
            isEnabled: true,
            tasteNotes: "private context recall",
            watchTopics: "ambient memory, local AI agents"
        ))

        let engine = FermentationEngine(store: store, taste: taste)
        _ = try engine.runLocalPass(maxIdeas: 10)

        let scoredOn = try store.idea(id: onTaste.id)
        let scoredOff = try store.idea(id: offTaste.id)
        #expect(scoredOn.personalResonance > scoredOff.personalResonance)
        #expect(scoredOn.ripeness > scoredOff.ripeness)
    }

    @Test @MainActor func excludedTopicsAreDamped() throws {
        let store = try makeStore()
        let excluded = try store.createIdea(title: "Crypto casino game", body: "A crypto gambling casino game with tokens.", tags: ["crypto"])
        let taste = TasteSignals(profile: AutonomyProfile(excludedTopics: "crypto, casino, gambling"))

        let engine = FermentationEngine(store: store, taste: taste)
        _ = try engine.runLocalPass(maxIdeas: 10)

        #expect(try store.idea(id: excluded.id).personalResonance <= 12)
    }

    @Test @MainActor func ripenessMatchesPersistedSixAxisScore() throws {
        let store = try makeStore()
        let idea = try store.createIdea(
            title: "Private local AI prototype",
            body: String(repeating: "Build a private local AI memory prototype workflow for real user tests. ", count: 8),
            tags: ["ai", "prototype", "workflow"]
        )
        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 5)

        let scored = try store.idea(id: idea.id)
        let persisted = try #require(store.ripenessScores(for: idea.id).first)
        // The idea's ripeness field is the mean of the same six axes the persisted
        // score records, so the two surfaces never disagree.
        #expect(abs(scored.ripeness - persisted.average) < 0.001)
    }

    // MARK: Critique persistence

    @Test @MainActor func localPassPersistsIdeaSpecificCritique() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Sparse idea", body: "short", tags: [])
        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 5)

        let critique = try #require(try store.critique(for: idea.id))
        #expect(critique.source == "local")
        #expect(!critique.isEmpty)
        // A sparse idea (no sources, no tags, tiny body) yields specific objections.
        #expect(critique.risks.contains { $0.contains("source") || $0.contains("themes") || $0.contains("under-described") })
    }

    @Test @MainActor func cloudCritiqueReplacesLocalKeepingOnePerIdea() async throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Idea", body: "A reasonably described idea body worth critiquing carefully before any build.")
        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 5)
        #expect(try store.critique(for: idea.id)?.source == "local")

        let model = EchoInputProvider().availableModels[0]
        let router = ModelRouter(models: [model], budget: AppBudget(approvalThresholdUSD: 99), providerPriority: ["Echo"])
        _ = try store.enqueue(FermentationJob(ideaID: idea.id, taskClass: .critique, modelRoute: router.route(taskClass: .critique, inputTokens: 10, outputTokens: 10), inputHash: "x"))
        let cloudEngine = FermentationEngine(store: store, router: router)
        _ = try await cloudEngine.runNext(provider: EchoInputProvider(), apiKey: "test")

        let stored = try store.critiques().filter { $0.ideaID == idea.id }
        #expect(stored.count == 1)
        #expect(stored.first?.source.contains("Echo") == true)
    }

    // MARK: Robust search

    @Test func searchSanitizesPunctuationAndFallsBackToSemantic() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Ambient memory recorder", body: "Private local capture of meetings.", tags: ["memory"])

        // FTS-hostile input must never throw a syntax error.
        _ = try store.searchIdeas("c++")
        _ = try store.searchIdeas("\"unterminated")
        _ = try store.searchSources("a OR b AND (")

        // Direct keyword hit.
        #expect(try store.searchIdeas("memory").contains { $0.id == idea.id })
        // No literal keyword overlap → semantic fallback still surfaces it.
        #expect(try store.searchIdeas("ambient recall of private meetings").contains { $0.id == idea.id })
    }

    // MARK: Connection insight

    @Test @MainActor func connectionExplanationNamesSharedThemes() throws {
        let store = try makeStore()
        let a = try store.createIdea(title: "Ambient memory agent", body: "Local AI recall of context.", tags: ["memory", "ai"])
        _ = try store.createIdea(title: "Memory companion", body: "An AI that recalls your day.", tags: ["memory", "ai"])
        let engine = FermentationEngine(store: store)
        _ = try engine.runLocalPass(maxIdeas: 10)

        let connections = try store.connections(for: a.id)
        let explanation = try #require(connections.first).explanation
        #expect(explanation.contains("memory") || explanation.contains("ai"))
        #expect(!explanation.contains("local signal"))
    }

    // MARK: Key-aware routing

    @Test func routingPrefersProvidersWithKeys() {
        let claudeOnly = ModelRouter(availableProviders: ["Claude"])
            .route(taskClass: .prototypeBrief, inputTokens: 1_000, outputTokens: 1_000)
        #expect(claudeOnly.provider == "Claude")

        // An unmatched key set must still produce a runnable catalog route.
        let fallback = ModelRouter(availableProviders: ["Nonexistent"])
            .route(taskClass: .tag, inputTokens: 1_000, outputTokens: 1_000)
        #expect(["Z.ai", "Gemini", "Kimi", "OpenAI", "Claude"].contains(fallback.provider))

        // No key information → unchanged global-cheapest behavior.
        let unrestricted = ModelRouter().route(taskClass: .tag, inputTokens: 1_000, outputTokens: 1_000)
        #expect(unrestricted.model == "glm-4.5-flash")
    }
}
