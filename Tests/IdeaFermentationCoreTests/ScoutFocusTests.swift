import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Scout focus")
struct ScoutFocusTests {
    @Test func emptyStateProducesNoFocus() {
        let focus = ScoutFocus.derive(taste: TasteModel(), outcomes: [], ideas: [], profile: AutonomyProfile())
        #expect(focus.isEmpty)
        #expect(focus.augment(query: "AI tools") == "AI tools")   // no-op until something is learned
    }

    @Test func leansTowardShippedThemesAndAwayFromAbandoned() {
        let shipped = IdeaSeed(title: "Memory app", body: "x", status: .archived, manualTags: ["memory", "ambient"])
        let abandoned = IdeaSeed(title: "Crypto thing", body: "y", status: .archived, manualTags: ["crypto"])
        let outcomes = [
            BuildOutcome(ideaID: shipped.id, result: .shipped),
            BuildOutcome(ideaID: abandoned.id, result: .abandoned)
        ]
        let focus = ScoutFocus.derive(taste: TasteModel(), outcomes: outcomes, ideas: [shipped, abandoned], profile: AutonomyProfile())
        #expect(focus.focusTerms.contains("memory"))
        #expect(focus.focusTerms.contains("ambient"))
        #expect(focus.avoidTerms.contains("crypto"))
        #expect(!focus.focusTerms.contains("crypto"))
        #expect(!focus.rationale.isEmpty)
    }

    @Test func explicitExclusionsAreAlwaysAvoided() {
        let profile = AutonomyProfile(excludedTopics: "gambling, nft")
        let focus = ScoutFocus.derive(taste: TasteModel(), outcomes: [], ideas: [], profile: profile)
        #expect(focus.avoidTerms.contains("gambling"))
        #expect(focus.avoidTerms.contains("nft"))
    }

    @Test func augmentAddsFocusTermsAndFilterDropsAvoided() {
        let focus = ScoutFocus(focusTerms: ["ambient memory", "on-device"], avoidTerms: ["crypto"], rationale: "")
        let augmented = focus.augment(query: "AI productivity tools")
        #expect(augmented.contains("AI productivity tools"))
        #expect(augmented.contains("ambient memory"))
        // A term already in the query is not duplicated.
        #expect(focus.augment(query: "ambient memory apps") == "ambient memory apps on-device")

        let signals = [
            ScoutSignal(title: "Ambient memory tool", summary: "A private memory app."),
            ScoutSignal(title: "Crypto casino", summary: "A crypto gambling app.")
        ]
        let kept = focus.filter(signals)
        #expect(kept.count == 1)
        #expect(kept.first?.title == "Ambient memory tool")
    }
}
