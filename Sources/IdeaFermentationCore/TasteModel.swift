import Foundation

/// A small, fully local, online-learned model of the operator's taste — tuned from
/// their own decisions rather than only from the profile they hand-edit. Marking an
/// idea Ready or building it pushes that idea's themes up; archiving or deleting an
/// idea that never ripened pushes them down. The local fermentation pass folds the
/// resulting affinity into resonance, so scoring drifts toward what the operator
/// actually commits to.
///
/// This is the "learning loop" half of the Hermes vision — self-*tuning*, not just
/// self-*remembering* (which `AgentLearning` already does). It is a tiny signed
/// bag-of-words classifier: deterministic, explainable, private, and zero-cost. An
/// untrained model is a strict no-op on scoring, so it never changes behavior until
/// the operator has actually taught it something.
public struct TasteModel: Codable, Equatable, Sendable {
    /// Per-token learned weight, clamped to `[-weightCap, weightCap]`. Keys are the
    /// same stemmed vocabulary the scorer matches against (see `Tokenizer`), so an
    /// entry here lines up exactly with the tokens of a future idea.
    public private(set) var weights: [String: Double]

    /// How many feedback events have shaped this model. Surfaced in the UI as a
    /// rough confidence cue.
    public private(set) var observations: Int

    /// The most a single token's weight can reach in either direction. Bounds the
    /// model so no one theme can dominate and so repeated reinforcement saturates
    /// instead of exploding.
    public static let weightCap = 4.0

    /// How far each feedback event moves a token's weight.
    public static let defaultLearningRate = 0.6

    public init(weights: [String: Double] = [:], observations: Int = 0) {
        self.weights = weights
        self.observations = observations
    }

    public var isEmpty: Bool { weights.isEmpty }

    /// Returns a NEW model with `tokens` reinforced toward `label` (+1 liked, −1
    /// disliked). Immutable by design — never mutates the receiver.
    public func reinforced(with tokens: Set<String>, label: Double, rate: Double = defaultLearningRate) -> TasteModel {
        guard !tokens.isEmpty, label != 0 else { return self }
        var next = weights
        for token in tokens {
            let updated = (next[token] ?? 0) + rate * label
            next[token] = min(Self.weightCap, max(-Self.weightCap, updated))
        }
        return TasteModel(weights: next, observations: observations + 1)
    }

    /// A bounded affinity in (−1, 1): how much the learned model likes or dislikes
    /// this material. Exactly 0 when nothing has been learned or nothing overlaps —
    /// that zero is what makes an untrained model invisible to scoring.
    public func affinity(for tokens: Set<String>) -> Double {
        guard !weights.isEmpty, !tokens.isEmpty else { return 0 }
        let matched = tokens.compactMap { weights[$0] }
        guard !matched.isEmpty else { return 0 }
        let total = matched.reduce(0, +)
        // tanh keeps the result in (−1, 1) and saturates gracefully, so a handful of
        // strong matches can't push affinity past ±1.
        return tanh(total / 3.0)
    }

    /// Strongest liked and disliked themes for display, each strongest-first.
    public func topThemes(limit: Int = 6) -> (liked: [(token: String, weight: Double)], disliked: [(token: String, weight: Double)]) {
        let liked = weights
            .filter { $0.value > 0.05 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (token: $0.key, weight: $0.value) }
        let disliked = weights
            .filter { $0.value < -0.05 }
            .sorted { $0.value < $1.value }
            .prefix(limit)
            .map { (token: $0.key, weight: $0.value) }
        return (Array(liked), Array(disliked))
    }
}
