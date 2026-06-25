import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Autonomous scout")
struct AutonomousScoutTests {
    @Test func dueMissionsRespectCadenceAndExcludedTopics() {
        let now = Date()
        let profile = AutonomyProfile(isEnabled: true, excludedTopics: "crypto games")
        let due = ScoutMission(title: "Mac AI", query: "AI-native macOS utilities", cadenceHours: 24, lastRunAt: now.addingTimeInterval(-25 * 60 * 60))
        let tooSoon = ScoutMission(title: "Memory", query: "ambient memory", cadenceHours: 24, lastRunAt: now.addingTimeInterval(-2 * 60 * 60))
        let excluded = ScoutMission(title: "Crypto", query: "crypto games for kids", cadenceHours: 24, lastRunAt: nil)
        let paused = ScoutMission(title: "Paused", query: "local tools", isEnabled: false)

        let missions = AutonomousScout.dueMissions(profile: profile, missions: [tooSoon, excluded, paused, due], now: now)

        #expect(missions.map(\.id) == [due.id])
    }

    @Test func filtersSignalsUsingExcludedTopics() {
        let profile = AutonomyProfile(excludedTopics: "crypto games")
        let allowed = ScoutSignal(title: "Local memory app", summary: "Private recall utility")
        let blocked = ScoutSignal(title: "Crypto games tracker", summary: "Wallet game ideas")

        #expect(AutonomousScout.filterSignals([allowed, blocked], profile: profile) == [allowed])
    }
}
