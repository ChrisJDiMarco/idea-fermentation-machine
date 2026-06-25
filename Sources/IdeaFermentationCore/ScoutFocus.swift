import Foundation

/// A derived, never-stored "brief adjustment" for the autonomous scout: which
/// themes to hunt harder for, and which to steer away from, computed from what the
/// operator has actually *done* rather than only what they typed.
///
/// This is the last turn of the learning loop. The taste model already tunes how
/// ideas are *scored* and the build-outcome loop records what *worked*; ScoutFocus
/// closes the circle by letting those same signals reshape what the scout goes
/// *looking* for. Build outcomes carry the most weight (shipping something is the
/// strongest possible statement of taste), then explicit ready/archive decisions,
/// then the learned per-theme weights.
///
/// Empty by construction until there is real signal, so it never changes scout
/// behavior on a fresh install.
public struct ScoutFocus: Equatable, Sendable {
    /// Themes to emphasize in searches and synthesis, strongest first. Readable,
    /// unstemmed tag words — usable directly in a search query.
    public var focusTerms: [String]
    /// Themes to steer away from (abandoned/flopped lanes + explicit exclusions).
    public var avoidTerms: [String]
    /// One-line human explanation for the UI.
    public var rationale: String

    public var isEmpty: Bool { focusTerms.isEmpty && avoidTerms.isEmpty }

    public init(focusTerms: [String] = [], avoidTerms: [String] = [], rationale: String = "") {
        self.focusTerms = focusTerms
        self.avoidTerms = avoidTerms
        self.rationale = rationale
    }

    /// Appends the strongest focus terms to a mission query, skipping any already
    /// present, so a generic mission drifts toward the operator's proven lanes.
    public func augment(query: String, maxTerms: Int = 3) -> String {
        let lowerQuery = query.lowercased()
        let additions = focusTerms.prefix(maxTerms).filter { !lowerQuery.contains($0.lowercased()) }
        guard !additions.isEmpty else { return query }
        return "\(query) \(additions.joined(separator: " "))"
    }

    /// Drops signals that match an avoid theme — a learned complement to the
    /// operator's explicit excluded topics.
    public func filter(_ signals: [ScoutSignal]) -> [ScoutSignal] {
        guard !avoidTerms.isEmpty else { return signals }
        return signals.filter { signal in
            let text = "\(signal.title) \(signal.summary)".lowercased()
            return !avoidTerms.contains { text.contains($0) }
        }
    }

    public static func derive(
        taste: TasteModel,
        outcomes: [BuildOutcome],
        ideas: [IdeaSeed],
        profile: AutonomyProfile,
        limit: Int = 5
    ) -> ScoutFocus {
        let outcomeByIdea = Dictionary(outcomes.map { ($0.ideaID, $0) }, uniquingKeysWith: { first, _ in first })

        // Net signal per readable theme — restricted to real theme words (drops
        // generic product/function filler like "app", "ai", "industry").
        var scores: [String: Double] = [:]
        for idea in ideas {
            let weight = signalWeight(for: idea, outcome: outcomeByIdea[idea.id])
            guard weight != 0 else { continue }
            for tag in idea.manualTags.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) where TasteModel.isThemeWord(tag) {
                scores[tag, default: 0] += weight
            }
        }

        // Blend in the learned taste model (keyed on the same readable terms), so
        // explicit decisions and accumulated micro-signals agree.
        for tag in scores.keys {
            scores[tag, default: 0] += (taste.weights[tag] ?? 0) * 0.5
        }

        let excluded = terms(profile.excludedTopics)

        let positives = scores
            .filter { $0.value > 0.2 && !excluded.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)

        let learnedNegatives = scores
            .filter { $0.value < -0.2 }
            .sorted { $0.value < $1.value }
            .prefix(limit)
            .map(\.key)
        // Explicit exclusions are always avoided, even with no idea history.
        let negatives = orderedUnique(Array(learnedNegatives) + excluded)

        return ScoutFocus(
            focusTerms: Array(positives),
            avoidTerms: Array(negatives.prefix(limit)),
            rationale: rationale(focus: Array(positives), avoid: Array(negatives))
        )
    }

    // MARK: - Internals

    /// How strongly an idea's themes should pull the scout. Build outcomes dominate;
    /// a clean ready/archive decision is next; a parked idea leans slightly negative.
    private static func signalWeight(for idea: IdeaSeed, outcome: BuildOutcome?) -> Double {
        if let outcome { return outcome.result.tasteLabel * (outcome.result.tasteRate * 2) }
        switch idea.status {
        case .ready: return 1.0
        case .ripening: return 0.5
        case .archived: return -0.4
        default: return 0.1
        }
    }

    private static func terms(_ raw: String) -> Set<String> {
        Set(raw.split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func rationale(focus: [String], avoid: [String]) -> String {
        var parts: [String] = []
        if !focus.isEmpty { parts.append("leaning toward \(focus.prefix(3).joined(separator: ", "))") }
        if !avoid.isEmpty { parts.append("steering clear of \(avoid.prefix(2).joined(separator: ", "))") }
        guard !parts.isEmpty else { return "" }
        return "Based on what you've built and kept, the scout is \(parts.joined(separator: " and "))."
    }
}
