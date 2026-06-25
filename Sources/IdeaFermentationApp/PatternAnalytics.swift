import Foundation
import IdeaFermentationCore

struct PatternAnalytics: Equatable {
    struct Theme: Identifiable, Equatable {
        var id: String { name }
        var name: String
        var count: Int
        var ideaCount: Int
        var sourceCount: Int
        var momentum: Double
        var trend: [Double]
    }

    struct Row: Identifiable, Equatable {
        var id: String { title + detail }
        var title: String
        var detail: String
        var value: String
        var score: Double
    }

    struct Fingerprint: Equatable {
        var integration: Double
        var originality: Double
        var technicalLean: Double
        var executionBias: Double
        var humanImpact: Double
        var curiosity: Double

        static let empty = Fingerprint(integration: 0, originality: 0, technicalLean: 0, executionBias: 0, humanImpact: 0, curiosity: 0)
    }

    var themes: [Theme]
    var loops: [Row]
    var combinations: [Row]
    var blindSpots: [Row]
    var alerts: [Row]
    var fingerprint: Fingerprint
    var connectionCount: Int
    var patternCount: Int
    var averageCrossPollination: Double
    var signalStrength: Double
    var hasData: Bool

    init(ideas: [IdeaSeed], sources: [SourceItem], logs: [AgentRunLog], connections: [IdeaConnection], days: Int = 90, now: Date = Date()) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let activeIdeas = ideas.filter { $0.createdAt >= cutoff || $0.updatedAt >= cutoff }
        let activeSources = sources.filter { $0.createdAt >= cutoff }
        let themeStats = Self.themeStats(ideas: activeIdeas, sources: activeSources, cutoff: cutoff, now: now)
        themes = Array(themeStats.prefix(8))
        loops = Self.loopRows(ideas: activeIdeas)
        combinations = Self.combinationRows(ideas: activeIdeas)
        blindSpots = Self.blindSpotRows(ideas: activeIdeas, sources: activeSources)
        alerts = Self.alertRows(themes: themes, logs: logs, connections: connections)
        fingerprint = Self.fingerprint(ideas: activeIdeas, sources: activeSources)
        connectionCount = connections.count
        patternCount = themes.count + combinations.count
        averageCrossPollination = activeIdeas.isEmpty ? 0 : Double(activeIdeas.reduce(0) { $0 + $1.sourceIDs.count }) / Double(activeIdeas.count)
        signalStrength = activeIdeas.isEmpty ? 0 : activeIdeas.reduce(0) { $0 + $1.ripeness } / Double(activeIdeas.count)
        hasData = !activeIdeas.isEmpty || !activeSources.isEmpty || !connections.isEmpty || !logs.isEmpty
    }

    func markdownReport() -> String {
        """
        # Pattern Report

        Patterns found: \(patternCount)
        Connections: \(connectionCount)
        Average cross-pollination: \(String(format: "%.1f", averageCrossPollination))
        Signal strength: \(Int(signalStrength))%

        ## Themes
        \(themes.map { "- \($0.name): \($0.count) mentions" }.joined(separator: "\n"))

        ## Unusual Combinations
        \(combinations.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n"))

        ## Blind Spots
        \(blindSpots.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n"))
        """
    }

    private static func themeStats(ideas: [IdeaSeed], sources: [SourceItem], cutoff: Date, now: Date) -> [Theme] {
        let midpoint = cutoff.addingTimeInterval(now.timeIntervalSince(cutoff) / 2)
        var counts: [String: (total: Int, ideas: Set<UUID>, sources: Set<UUID>, recent: Int, older: Int, buckets: [Double])] = [:]

        for idea in ideas {
            let terms = terms(tags: idea.manualTags, text: "\(idea.title) \(idea.body)")
            add(terms: terms, id: idea.id, isIdea: true, date: idea.updatedAt, midpoint: midpoint, cutoff: cutoff, now: now, counts: &counts)
        }
        for source in sources {
            let terms = terms(tags: [], text: "\(source.title) \(source.body)")
            add(terms: terms, id: source.id, isIdea: false, date: source.createdAt, midpoint: midpoint, cutoff: cutoff, now: now, counts: &counts)
        }

        return counts.map { name, stat in
            let older = max(1, stat.older)
            return Theme(
                name: name,
                count: stat.total,
                ideaCount: stat.ideas.count,
                sourceCount: stat.sources.count,
                momentum: Double(stat.recent - stat.older) / Double(older),
                trend: stat.buckets
            )
        }
        .sorted {
            if $0.count == $1.count { return $0.momentum > $1.momentum }
            return $0.count > $1.count
        }
    }

    private static func add(terms: [String], id: UUID, isIdea: Bool, date: Date, midpoint: Date, cutoff: Date, now: Date, counts: inout [String: (total: Int, ideas: Set<UUID>, sources: Set<UUID>, recent: Int, older: Int, buckets: [Double])]) {
        let bucket = min(7, max(0, Int(date.timeIntervalSince(cutoff) / max(1, now.timeIntervalSince(cutoff)) * 8)))
        for term in Set(terms) {
            var stat = counts[term] ?? (0, [], [], 0, 0, Array(repeating: 0, count: 8))
            stat.total += 1
            if isIdea { stat.ideas.insert(id) } else { stat.sources.insert(id) }
            if date >= midpoint { stat.recent += 1 } else { stat.older += 1 }
            stat.buckets[bucket] += 1
            counts[term] = stat
        }
    }

    private static func loopRows(ideas: [IdeaSeed]) -> [Row] {
        let grouped = Dictionary(grouping: ideas) { "\($0.stage.title) / \($0.status.rawValue.capitalized)" }
        return grouped
            .filter { $0.value.count > 1 }
            .map { key, rows in
                Row(title: key, detail: "\(rows.count) ideas are moving through the same lane.", value: "\(rows.count)", score: min(1, Double(rows.count) / Double(max(1, ideas.count))))
            }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0 }
    }

    private static func combinationRows(ideas: [IdeaSeed]) -> [Row] {
        var pairs: [String: Int] = [:]
        for idea in ideas {
            let tags = Array(Set(terms(tags: idea.manualTags, text: "\(idea.title) \(idea.body)").prefix(5))).sorted()
            guard tags.count > 1 else { continue }
            for left in 0..<(tags.count - 1) {
                for right in (left + 1)..<tags.count {
                    pairs["\(tags[left]) + \(tags[right])", default: 0] += 1
                }
            }
        }
        return pairs
            .map { Row(title: $0.key, detail: $0.value == 1 ? "Rare pairing in your library." : "Appears across \($0.value) ideas.", value: $0.value == 1 ? "Rare" : "\($0.value)x", score: 1 / Double(max(1, $0.value))) }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0 }
    }

    private static func blindSpotRows(ideas: [IdeaSeed], sources: [SourceItem]) -> [Row] {
        var rows: [Row] = []
        if ideas.allSatisfy({ $0.sourceIDs.isEmpty }) {
            rows.append(Row(title: "Evidence", detail: "Ideas have no linked sources yet.", value: "High", score: 1))
        }
        if !ideas.isEmpty && ideas.allSatisfy({ $0.ripeness < 70 }) {
            rows.append(Row(title: "Validation", detail: "No idea has crossed the ready threshold.", value: "Medium", score: 0.66))
        }
        if !sources.isEmpty && Set(sources.map(\.type)).count < 3 {
            rows.append(Row(title: "Source diversity", detail: "Most inputs come from the same source type.", value: "Medium", score: 0.66))
        }
        if ideas.contains(where: { $0.manualTags.isEmpty }) {
            rows.append(Row(title: "Tagging", detail: "Some ideas need themes before strong patterns emerge.", value: "Low", score: 0.33))
        }
        return rows
    }

    private static func alertRows(themes: [Theme], logs: [AgentRunLog], connections: [IdeaConnection]) -> [Row] {
        let themeAlerts = themes.filter { $0.momentum > 0 }.prefix(3).map {
            Row(title: "\($0.name.capitalized) is rising", detail: "\($0.count) real mentions in the selected range.", value: momentumText($0.momentum), score: min(1, $0.momentum))
        }
        let connectionAlerts = connections.prefix(2).map {
            Row(title: "Connection found", detail: $0.explanation, value: "\(Int($0.confidence * 100))%", score: $0.confidence)
        }
        return Array((themeAlerts + connectionAlerts).prefix(5))
    }

    private static func fingerprint(ideas: [IdeaSeed], sources: [SourceItem]) -> Fingerprint {
        guard !ideas.isEmpty || !sources.isEmpty else { return .empty }
        let ideaCount = Double(max(1, ideas.count))
        return Fingerprint(
            integration: min(1, Double(ideas.reduce(0) { $0 + $1.sourceIDs.count }) / max(1, ideaCount * 3)),
            originality: min(1, ideas.reduce(0) { $0 + $1.novelty } / max(1, ideaCount * 100)),
            technicalLean: min(1, ideas.reduce(0) { $0 + $1.feasibility } / max(1, ideaCount * 100)),
            executionBias: min(1, Double(ideas.filter { $0.status == .ready || $0.status == .archived }.count) / ideaCount),
            humanImpact: min(1, ideas.reduce(0) { $0 + $1.personalResonance } / max(1, ideaCount * 100)),
            curiosity: min(1, Double(Set(ideas.flatMap(\.manualTags)).count + Set(sources.map(\.type)).count) / 12)
        )
    }

    private static func terms(tags: [String], text: String) -> [String] {
        let tagged = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        if !tagged.isEmpty { return tagged }
        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopwords.contains($0) }
            .prefix(8)
            .map { $0 }
    }

    static func momentumText(_ value: Double) -> String {
        let pct = Int(abs(value) * 100)
        return value >= 0 ? "+\(pct)%" : "-\(pct)%"
    }

    private static let stopwords: Set<String> = [
        "about", "after", "again", "also", "because", "build", "could", "from", "have", "idea", "into", "like", "more", "need", "notes", "only", "over", "that", "their", "them", "there", "this", "with", "what", "when", "where", "which", "will", "your"
    ]
}
