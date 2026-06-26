import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Forecast accuracy")
struct ForecastTests {
    @Test func probabilityMapsRipenessToCalibratedOdds() {
        #expect(abs(ForecastLog.probability(forRipeness: 78) - 0.5) < 0.001)   // threshold = coin flip
        #expect(ForecastLog.probability(forRipeness: 100) > 0.95)               // perfect ≈ near-certain
        #expect(ForecastLog.probability(forRipeness: 50) == 0.5)                // clamped below threshold
        let mid = ForecastLog.probability(forRipeness: 89)
        #expect(mid > 0.5 && mid < 0.8)
    }

    @Test func accuracyComputesHitRateAndBrier() {
        func log(_ prob: Double, _ positive: Bool?) -> ForecastLog {
            ForecastLog(ideaID: UUID(), ripenessAtPrediction: 80, predictedProbability: prob,
                        resolvedAt: positive == nil ? nil : Date(), actualPositive: positive)
        }
        let logs = [log(0.9, true), log(0.9, true), log(0.6, false), log(0.7, true), log(0.8, false), log(0.7, nil)]
        let acc = ForecastAccuracy(from: logs)
        #expect(acc.resolvedCount == 5)
        #expect(acc.openCount == 1)
        #expect(acc.correctCount == 3)
        #expect(abs(acc.hitRate - 0.6) < 0.001)
        #expect(acc.isReliable)
        // (0.01 + 0.01 + 0.36 + 0.09 + 0.64) / 5 = 0.222
        #expect(abs(acc.brier - 0.222) < 0.001)
    }

    @Test func belowFiveResolvedIsNotReliable() {
        let logs = (0..<4).map { _ in
            ForecastLog(ideaID: UUID(), ripenessAtPrediction: 80, predictedProbability: 0.8, resolvedAt: Date(), actualPositive: true)
        }
        #expect(!ForecastAccuracy(from: logs).isReliable)
    }

    @Test func storeRoundTripsAndResolvesInPlace() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Idea", body: "x")
        var log = ForecastLog(ideaID: idea.id, ripenessAtPrediction: 82, predictedProbability: 0.6, novelty: 70)
        try store.saveForecastLog(log)
        #expect(try store.forecastLogs().count == 1)
        #expect(try store.latestForecast(for: idea.id)?.isResolved == false)
        #expect(try store.latestForecast(for: idea.id)?.novelty == 70)

        log.resolvedAt = Date()
        log.actualPositive = true
        log.outcomeResult = .shipped
        try store.saveForecastLog(log)

        #expect(try store.forecastLogs().count == 1) // upsert by id, not a second row
        #expect(try store.latestForecast(for: idea.id)?.actualPositive == true)
        #expect(try store.latestForecast(for: idea.id)?.outcomeResult == .shipped)
    }
}
