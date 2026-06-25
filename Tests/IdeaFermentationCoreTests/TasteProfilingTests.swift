import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Taste profiling")
struct TasteProfilingTests {
    @Test func localProfileDescribesLikedAndDislikedThemes() {
        let taste = TasteModel()
            .reinforced(with: ["memory", "ambient"], label: 1)
            .reinforced(with: ["crypto"], label: -1)

        let profile = TasteDistiller.localProfile(taste: taste, decisionCount: 2, now: Date())

        #expect(!profile.portrait.isEmpty)
        #expect(profile.source == "local heuristics")
        #expect(profile.likes.contains { $0.name.lowercased().contains("memory") })
        #expect(profile.avoids.contains { $0.name.lowercased().contains("crypto") })
    }

    @Test func localProfileIsHonestWhenUntaught() {
        let profile = TasteDistiller.localProfile(taste: TasteModel(), decisionCount: 0, now: Date())
        #expect(profile.portrait.contains("Not enough decisions"))
        #expect(profile.criteria.isEmpty)
    }

    @Test func decodeParsesPortraitAndDirectionedCriteria() throws {
        let json = """
        ```json
        {"portrait":"You favor single-purpose tools that remove a step from a workflow.",
         "criteria":[
           {"name":"Removes a step","direction":"like","note":"strips friction"},
           {"name":"Needs ongoing content","direction":"avoid","note":"you drop these"}
         ]}
        ```
        """
        let profile = try #require(TasteDistiller.decode(json, source: "cloud · Test", decisionCount: 5, now: Date()))

        #expect(profile.portrait.contains("single-purpose"))
        #expect(profile.likes.count == 1)
        #expect(profile.avoids.count == 1)
        #expect(profile.likes.first?.name == "Removes a step")
        #expect(profile.decisionCount == 5)
    }

    @Test func decodeRejectsEmptyOutput() {
        #expect(TasteDistiller.decode("no json here", source: "cloud", decisionCount: 0, now: Date()) == nil)
        #expect(TasteDistiller.decode(#"{"portrait":"","criteria":[]}"#, source: "cloud", decisionCount: 0, now: Date()) == nil)
    }

    @Test func digestWithholdsNeverSendDerivedTitleTagsAndBody() throws {
        // An idea derived from a never-send source can have a title and tags taken from
        // the protected source, so the WHOLE line is withheld, not just the body.
        let store = try makeStore()
        let secret = try store.createSource(SourceItem(type: .note, title: "SECRET-PAGE-TITLE", body: "z", neverSendToCloud: true))
        var liked = try store.createIdea(title: "SECRET-PAGE-TITLE", body: "TASTE-SECRET-BODY", tags: ["secrettag"])
        liked.sourceIDs = [secret.id]
        try store.upsertIdea(liked)

        let digest = TasteDistiller.digest(liked: try store.listIdeas(), disliked: [], outcomes: [], sources: [secret])

        #expect(!digest.contains("SECRET-PAGE-TITLE")) // title withheld
        #expect(!digest.contains("secrettag"))         // tags withheld
        #expect(!digest.contains("TASTE-SECRET-BODY"))  // body withheld
        #expect(digest.contains("[private idea"))       // placeholder instead
    }

    @Test func promptContextRendersTasteForOtherAgents() {
        let profile = TasteProfile(
            portrait: "Drawn to small utilities.",
            criteria: [
                TasteCriterion(name: "Single-purpose", direction: 1),
                TasteCriterion(name: "Requires a community", direction: -1)
            ],
            generatedAt: Date(), source: "cloud", decisionCount: 3
        )
        let context = profile.promptContext
        #expect(context.contains("Drawn to small utilities"))
        #expect(context.contains("Single-purpose"))
        #expect(context.contains("Requires a community"))
    }
}
