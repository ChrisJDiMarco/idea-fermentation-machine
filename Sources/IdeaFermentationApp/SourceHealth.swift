import Foundation
import IdeaFermentationCore

enum SourceHealth {
    static func score(_ source: SourceItem) -> Double {
        let base: Double = switch source.extractionStatus {
        case .captured: 45
        case .summarized: 65
        case .tagged: 75
        case .connected: 88
        case .revisitScheduled: 70
        case .failed: 20
        }
        let textBoost: Double = source.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 8
        let linkBoost: Double = source.linkedIdeaIDs.isEmpty ? 0 : 10
        return min(100, base + textBoost + linkBoost)
    }

    static func overall(_ sources: [SourceItem]) -> Double {
        guard !sources.isEmpty else { return 0 }
        return sources.reduce(0) { $0 + score($1) } / Double(sources.count)
    }

    static func label(_ score: Double) -> String {
        switch score {
        case 85...: "Excellent"
        case 65...: "Good"
        case 40...: "Needs Work"
        default: "Needs Review"
        }
    }
}
