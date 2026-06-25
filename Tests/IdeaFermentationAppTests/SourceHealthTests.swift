import Foundation
import Testing
@testable import IdeaFermentationApp
@testable import IdeaFermentationCore

@Suite("Source health")
struct SourceHealthTests {
    @Test func failedSourcesScoreBelowConnectedSources() {
        let failed = SourceItem(type: .screenshot, title: "Capture", body: "", extractionStatus: .failed)
        let connected = SourceItem(type: .note, title: "Note", body: "Useful extracted text", extractionStatus: .connected, linkedIdeaIDs: [UUID()])

        #expect(SourceHealth.score(failed) < SourceHealth.score(connected))
        #expect(SourceHealth.label(SourceHealth.score(connected)) == "Excellent")
    }

    @Test func emptyOverallHealthIsZero() {
        #expect(SourceHealth.overall([]) == 0)
    }

    @Test func linkedProcessedSourcesCapAtOneHundred() {
        let source = SourceItem(type: .article, title: "Signal", body: "Dense material", extractionStatus: .connected, linkedIdeaIDs: [UUID(), UUID()])

        #expect(SourceHealth.score(source) == 100)
    }
}
