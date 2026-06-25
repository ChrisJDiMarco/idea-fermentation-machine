import Foundation

/// A compact, tokenized view of the operator's taste — derived from the
/// `AutonomyProfile` — that the local fermentation pass uses to score ideas the
/// way *this* person would, instead of against a fixed, generic word list.
///
/// This is the cheap, always-on half of the "Taste Agent" in the Hermes vision:
/// it nudges resonance and novelty toward what the operator actually watches for,
/// and pushes excluded topics down so they never ripen into noise.
public struct TasteSignals: Equatable, Sendable {
    /// Stemmed tokens the operator is actively interested in (watch topics, taste
    /// notes, goals).
    public var interests: Set<String>
    /// Stemmed tokens the operator has explicitly excluded.
    public var exclusions: Set<String>
    /// The self-tuning model learned from the operator's own decisions. Empty by
    /// default, so it never affects scoring until something has been learned.
    public var learned: TasteModel

    public var isActive: Bool { !interests.isEmpty || !exclusions.isEmpty }

    public init(interests: Set<String> = [], exclusions: Set<String> = [], learned: TasteModel = TasteModel()) {
        self.interests = interests
        self.exclusions = exclusions
        self.learned = learned
    }

    public init(profile: AutonomyProfile, learned: TasteModel = TasteModel()) {
        self.interests = Tokenizer.vocabulary("\(profile.watchTopics) \(profile.tasteNotes) \(profile.goals)")
        self.exclusions = Tokenizer.vocabulary(profile.excludedTopics)
        self.learned = learned
    }

    /// How many of the idea's tokens land in the operator's interest set.
    public func interestOverlap(_ tokens: Set<String>) -> Int {
        interests.isEmpty ? 0 : tokens.intersection(interests).count
    }

    /// Whether the idea touches an explicitly excluded topic.
    public func isExcluded(_ tokens: Set<String>) -> Bool {
        !exclusions.isEmpty && !tokens.isDisjoint(with: exclusions)
    }

    /// Bounded affinity from the self-tuning model — how much the operator's past
    /// decisions imply they'd like this idea. 0 when nothing has been learned.
    public func learnedAffinity(_ tokens: Set<String>) -> Double {
        learned.affinity(for: tokens)
    }
}
