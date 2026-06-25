import Foundation
import Testing
@testable import IdeaFermentationCore

@MainActor
@Suite("Taste learning")
struct TasteModelTests {
    @Test func untrainedModelIsANeutralNoOp() {
        let model = TasteModel()
        #expect(model.isEmpty)
        #expect(model.affinity(for: Tokenizer.vocabulary("ambient memory app")) == 0)
    }

    @Test func reinforcingIsImmutableAndDirectional() {
        let tokens = Tokenizer.vocabulary("ambient memory privacy recall")
        let base = TasteModel()

        let liked = base.reinforced(with: tokens, label: 1)
        #expect(base.isEmpty)                       // original untouched — immutability
        #expect(liked.observations == 1)
        #expect(liked.affinity(for: tokens) > 0)

        let disliked = base.reinforced(with: tokens, label: -1)
        #expect(disliked.affinity(for: tokens) < 0)

        #expect(base.reinforced(with: tokens, label: 0) == base)   // zero label is a no-op
        #expect(base.reinforced(with: [], label: 1) == base)        // empty tokens is a no-op
    }

    @Test func weightsSaturateAtTheCap() {
        let tokens = Tokenizer.vocabulary("ambient memory")
        var model = TasteModel()
        for _ in 0..<50 { model = model.reinforced(with: tokens, label: 1) }
        #expect(model.weights.values.allSatisfy { $0 <= TasteModel.weightCap + 0.0001 })
        #expect(model.affinity(for: tokens) <= 1.0)
        #expect(model.affinity(for: tokens) > 0.9)
    }

    @Test func topThemesSeparatesLikedFromDisliked() {
        var model = TasteModel()
        model = model.reinforced(with: Tokenizer.vocabulary("ambient memory recall"), label: 1)
        model = model.reinforced(with: Tokenizer.vocabulary("crypto trading bots"), label: -1)
        let themes = model.topThemes(limit: 5)
        #expect(themes.liked.isEmpty == false)
        #expect(themes.disliked.isEmpty == false)
        #expect(themes.liked.allSatisfy { $0.weight > 0 })
        #expect(themes.disliked.allSatisfy { $0.weight < 0 })
    }

    @Test func genericFillerNeverBecomesATheme() {
        let terms = TasteModel.themeTerms(title: "A simple new AI app for the industry", tags: ["app", "ai", "productivity"])
        #expect(terms.contains("productivity"))   // the one real theme survives
        #expect(!terms.contains("app"))            // generic product words filtered
        #expect(!terms.contains("ai"))
        #expect(!terms.contains("simple"))
        #expect(!terms.contains("new"))
        #expect(!terms.contains("industry"))
        #expect(!terms.contains("for"))            // function words filtered
        #expect(!terms.contains("the"))
    }

    @Test func reinforcementOnlyLearnsAndDisplaysRealThemes() {
        var model = TasteModel()
        let terms = TasteModel.themeTerms(title: "Ambient memory recall app", tags: ["memory", "app"])
        model = model.reinforced(with: terms, label: -1)
        let disliked = model.topThemes().disliked.map(\.token)
        #expect(disliked.contains("memory"))
        #expect(disliked.contains("ambient"))
        #expect(!disliked.contains("app"))         // never learned → never shown
    }

    @Test func learnedTasteShiftsLocalRipenessBothWays() throws {
        func ripeness(with taste: TasteSignals) throws -> Double {
            let store = try makeStore()
            let idea = try store.createIdea(
                title: "Ambient memory recall",
                body: "A private local app that helps you recall ambient memory and context across your day.",
                tags: ["memory", "privacy"]
            )
            let engine = FermentationEngine(store: store, taste: taste)
            _ = try engine.runLocalPass(maxIdeas: 5)
            return try store.idea(id: idea.id).ripeness
        }

        let tokens = Tokenizer.vocabulary("ambient memory recall context private local")
        var liked = TasteModel()
        var disliked = TasteModel()
        for _ in 0..<4 {
            liked = liked.reinforced(with: tokens, label: 1)
            disliked = disliked.reinforced(with: tokens, label: -1)
        }

        let baseline = try ripeness(with: TasteSignals())
        let boosted = try ripeness(with: TasteSignals(learned: liked))
        let suppressed = try ripeness(with: TasteSignals(learned: disliked))

        // Learning what the operator commits to raises a matching idea's score;
        // learning what they reject lowers it. An empty model sits exactly between.
        #expect(boosted > baseline)
        #expect(suppressed < baseline)
    }
}
