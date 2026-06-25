import Foundation
import NaturalLanguage

/// Local, private text embeddings for semantic search, idea connections, and
/// source auto-linking.
///
/// Primary backend: Apple's on-device `NLEmbedding` sentence model — a real
/// *semantic* embedding, so "ambient memory" and "passive recall" land near each
/// other even though they share no words. That's the whole point: the lexical
/// hashed-bag-of-words it replaced could only ever connect ideas that reused the
/// same vocabulary, which misses exactly the non-obvious connections worth
/// surfacing.
///
/// Fallback backend: the original deterministic hashed bag-of-words, used when the
/// system sentence model is unavailable. The active backend is chosen once and
/// fixed for the process, and every embedding it produces has the same dimension,
/// so vectors are always comparable. A schema-version bump re-embeds the whole
/// store when the backend (and therefore the vector space) changes.
///
/// Both backends are deterministic for a given OS, so a vector written to disk
/// reads back meaningfully — the property `String.hashValue` famously did not have.
public enum LocalEmbeddings {
    /// Dimension of the hashed bag-of-words fallback.
    private static let fallbackDimensions = 128

    /// Bumped whenever the embedding math changes in a way that invalidates
    /// previously persisted vectors. v3 introduces the NLEmbedding semantic space.
    public static let version = 3

    /// The system sentence embedder, resolved once. `nil` when the OS can't provide
    /// it, in which case we fall back to the hashed bag-of-words.
    nonisolated(unsafe) private static let sentenceEmbedder: NLEmbedding? = NLEmbedding.sentenceEmbedding(for: .english)

    /// `NLEmbedding.vector(for:)` is a read-only query but is NOT thread-safe —
    /// concurrent calls (e.g. parallel scoring, or the parallel test runner)
    /// segfault. Embedding is infrequent enough that serializing it is free.
    nonisolated(unsafe) private static let embedderLock = NSLock()

    /// Whether the semantic (neural) backend is active. Drives the connection /
    /// link tuning, which differs between the two cosine distributions.
    public static var usesNeuralEmbeddings: Bool { sentenceEmbedder != nil }

    /// The active vector dimension — the sentence model's when available, otherwise
    /// the fallback's. Every `embed` call returns exactly this many components.
    public static var dimensions: Int { sentenceEmbedder?.dimension ?? fallbackDimensions }

    public static func embed(_ text: String) -> [Double] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let embedder = sentenceEmbedder {
            // Sentence models work best on bounded input; long bodies are capped so
            // the vector reflects the gist, not noise from a wall of text.
            let input = String(cleaned.prefix(1_200))
            if !input.isEmpty {
                embedderLock.lock()
                let vector = embedder.vector(for: input)
                embedderLock.unlock()
                if let vector, vector.count == embedder.dimension { return vector }
            }
            // Keep the dimension consistent even when the model returns nothing.
            return Array(repeating: 0.0, count: embedder.dimension)
        }
        return hashedBagOfWords(cleaned)
    }

    /// True cosine similarity in `[-1, 1]`. Normalizes by both magnitudes so it is
    /// correct whether or not the inputs are unit vectors (NLEmbedding vectors are
    /// not pre-normalized).
    public static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return 0 }
        var dot = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0
        for index in 0..<count {
            dot += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }
        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return dot / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }

    /// The nearest neighbors of `query` among `items`, gated by a *scale-free*
    /// rule: keep the top-K whose similarity is within `retentionFraction` of the
    /// single best match (and above a tiny absolute floor). This adapts to whatever
    /// cosine distribution the active backend produces — the sparse hashed space
    /// (low similarities, real signal) and the dense neural space (high baseline
    /// similarities) both work without a hand-tuned absolute threshold that would
    /// over-connect everything in one and nothing in the other.
    public static func related<T>(
        _ items: [T],
        to query: [Double],
        embedding: (T) -> [Double],
        topK: Int,
        retentionFraction: Double = 0.62,
        floor: Double = 0.05
    ) -> [(item: T, score: Double)] {
        let scored = items
            .map { (item: $0, score: cosine(query, embedding($0))) }
            .filter { $0.score > floor }
        guard let best = scored.map(\.score).max(), best > floor else { return [] }
        let cutoff = max(floor, best * retentionFraction)
        return scored
            .filter { $0.score >= cutoff }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    /// "Same topic" decision for routing — a deliberately high bar, since attaching
    /// new material to the wrong idea is worse than starting a fresh one. Scaled to
    /// the active backend's distribution.
    public static var strongMatchFloor: Double { usesNeuralEmbeddings ? 0.55 : 0.30 }

    // MARK: - Hashed bag-of-words fallback

    /// The original deterministic embedding: hashes stemmed unigrams and bigrams
    /// into a fixed-width vector with sublinear term-frequency weighting, then
    /// L2-normalizes. Lexical, not semantic — but instant, private, and dependency
    /// free, which is exactly what's needed when the system model is unavailable.
    private static func hashedBagOfWords(_ text: String) -> [Double] {
        let tokens = Tokenizer.tokens(text)
        guard !tokens.isEmpty else { return Array(repeating: 0.0, count: fallbackDimensions) }

        var counts: [Int: Double] = [:]
        for token in tokens {
            accumulate(&counts, key: token, weight: 1.0)
        }
        for index in tokens.indices.dropLast() {
            accumulate(&counts, key: "\(tokens[index]) \(tokens[index + 1])", weight: 0.5)
        }

        var vector = Array(repeating: 0.0, count: fallbackDimensions)
        for (bucket, rawCount) in counts {
            vector[bucket] += 1.0 + log(rawCount)
        }

        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    private static func accumulate(_ counts: inout [Int: Double], key: String, weight: Double) {
        let bucket = Int(Tokenizer.stableHash(key) % UInt64(fallbackDimensions))
        counts[bucket, default: 0] += weight
    }
}
