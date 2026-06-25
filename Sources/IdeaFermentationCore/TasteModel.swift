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

    /// The readable theme words that represent an idea for taste learning — its tags
    /// plus distinctive title words. Deliberately NOT the whole body and NOT stemmed:
    /// learning over every body word let high-frequency filler ("yet", "app", "ai")
    /// and stemming fragments ("ful") accumulate weight and masquerade as themes.
    /// Tags are curated; titles are concise; the stoplist removes generic product and
    /// function words. The result is meaningful, human-readable themes.
    public static func themeTerms(title: String, tags: [String]) -> Set<String> {
        var terms = Set<String>()
        for tag in tags {
            let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if isThemeWord(cleaned) { terms.insert(cleaned) }
        }
        for word in title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            if isThemeWord(word) { terms.insert(word) }
        }
        return terms
    }

    /// A theme is a content word that actually distinguishes one idea from another:
    /// not a stopword, not a generic product/function word, not a fragment.
    public static func isThemeWord(_ word: String) -> Bool {
        word.count >= 3 && !Tokenizer.stopwords.contains(word) && !genericThemeStoplist.contains(word)
    }

    /// Words that appear across many ideas and therefore carry no taste signal —
    /// generic product vocabulary plus common function words the base tokenizer's
    /// (intentionally small) stoplist lets through.
    public static let genericThemeStoplist: Set<String> = [
        // generic product / idea vocabulary
        "app", "apps", "application", "applications", "idea", "ideas", "tool", "tools",
        "platform", "platforms", "system", "systems", "product", "products", "feature",
        "features", "service", "services", "software", "website", "site", "api", "apis",
        "data", "user", "users", "thing", "things", "stuff", "way", "ways", "use", "used",
        "uses", "build", "builds", "building", "make", "makes", "making", "create",
        "creates", "creating", "based", "powered", "using", "new", "simple", "easy",
        "project", "projects", "concept", "concepts", "version", "approach", "solution",
        "solutions", "ai", "llm", "llms", "gpt", "model", "models", "focus", "industry",
        "general", "various", "different", "particular", "stack", "startup",
        // common function words the base stoplist misses
        "by", "with", "from", "into", "onto", "upon", "via", "per", "and", "but", "for",
        "yet", "also", "just", "very", "much", "many", "most", "more", "less", "then",
        "than", "once", "ever", "even", "still", "about", "over", "under", "after",
        "before", "while", "during", "around", "across", "toward", "your", "our", "its",
        "this", "that", "these", "those", "here", "there", "where", "what", "when",
        "which", "who", "why", "how", "each", "every", "both", "few", "some", "any", "all"
    ]

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
