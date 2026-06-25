import Foundation
import Testing
@testable import IdeaFermentationApp
import IdeaFermentationCore

@Suite("Pattern analytics")
struct PatternAnalyticsTests {
    @Test func emptyInputsStayEmpty() {
        let analytics = PatternAnalytics(ideas: [], sources: [], logs: [], connections: [])

        #expect(analytics.hasData == false)
        #expect(analytics.themes.isEmpty)
        #expect(analytics.patternCount == 0)
    }

    @Test func realIdeasProduceThemesAndCombinations() {
        let now = Date()
        let ideas = [
            IdeaSeed(title: "Local memory app", body: "Capture private memories", createdAt: now, updatedAt: now, manualTags: ["memory", "local ai"], ripeness: 80, novelty: 75, feasibility: 70, personalResonance: 90),
            IdeaSeed(title: "Private memory utility", body: "Search local notes", createdAt: now, updatedAt: now, manualTags: ["memory", "privacy"], ripeness: 55, novelty: 60, feasibility: 65, personalResonance: 75)
        ]
        let source = SourceItem(type: .article, title: "Memory tools", body: "Local-first memory utilities", createdAt: now)

        let analytics = PatternAnalytics(ideas: ideas, sources: [source], logs: [], connections: [], now: now)

        #expect(analytics.hasData)
        #expect(analytics.themes.contains { $0.name == "memory" && $0.count >= 2 })
        #expect(!analytics.combinations.isEmpty)
        #expect(analytics.signalStrength == 67.5)
    }

    @Test func dnaHeaderStacksBeforeControlsCanCrushTheTitle() {
        #expect(PatternLayout.shouldStackDNAHeader(width: 420))
        #expect(!PatternLayout.shouldStackDNAHeader(width: 560))
    }
}
