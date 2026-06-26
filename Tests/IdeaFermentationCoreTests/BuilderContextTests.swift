import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Builder context")
struct BuilderContextTests {
    @Test func emptyWhenNothingIsKnown() {
        #expect(BuilderContext.promptBlock(profile: nil, taste: nil).isEmpty)
        #expect(BuilderContext.promptBlock(profile: AutonomyProfile(), taste: nil).isEmpty)
        #expect(BuilderContext.promptPrefix(profile: nil, taste: nil).isEmpty)
    }

    @Test func composesDeclaredProfileAndDistilledPortrait() {
        let profile = AutonomyProfile(tasteNotes: "calm, local-first tools", goals: "ship one app a quarter", excludedTopics: "crypto")
        let taste = TasteProfile(
            portrait: "Drawn to ambient, low-friction capture.",
            criteria: [TasteCriterion(name: "ambient UX", direction: 1, note: ""),
                       TasteCriterion(name: "growth hacks", direction: -1, note: "")],
            generatedAt: Date(timeIntervalSince1970: 0), source: "cloud · test", decisionCount: 8
        )

        let block = BuilderContext.promptBlock(profile: profile, taste: taste)
        #expect(block.contains("ship one app a quarter"))   // goals
        #expect(block.contains("calm, local-first tools"))  // taste notes
        #expect(block.contains("crypto"))                   // avoid
        #expect(block.contains("ambient"))                  // distilled portrait
        #expect(block.hasPrefix("The builder you are advising:"))
    }

    /// The whole point of the composer: every cloud agent reasons about the SAME builder.
    /// Scout, portfolio synthesis, and the deep critique must all embed the identical block.
    @Test func everyCloudAgentEmbedsTheSameBuilderBlock() {
        let profile = AutonomyProfile(tasteNotes: "calm tools", goals: "ship quarterly", excludedTopics: "crypto")
        let taste = TasteProfile(portrait: "Ambient capture.", criteria: [], generatedAt: Date(timeIntervalSince1970: 0), source: "cloud · test", decisionCount: 5)
        let block = BuilderContext.promptBlock(profile: profile, taste: taste)

        let scout = AutonomousScout.synthesisPrompt(profile: profile, tasteProfile: taste)
        let portfolio = PortfolioReasoner.prompt(profile: profile, tasteProfile: taste)

        #expect(scout.contains(block))
        #expect(portfolio.contains(block))
    }
}
