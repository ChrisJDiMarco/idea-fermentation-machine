import Foundation

/// A tiny, fully local, dependency-free embedding model.
///
/// It hashes stemmed unigrams and bigrams into a fixed-width vector using
/// sublinear term-frequency weighting, then L2-normalizes. This is a hashed
/// bag-of-words ("hashing trick") — not a neural embedding — but it is
/// deterministic, instant, and private, which is exactly what the local-first
/// fermentation loop needs.
///
/// History: the original implementation hashed with `String.hashValue`, which
/// Swift randomly seeds per process. That meant a vector written to SQLite in one
/// launch was gibberish when compared against a vector computed in the next
/// launch, silently breaking connection-finding and semantic search across
/// sessions. `Tokenizer.stableHash` (FNV-1a) fixes that — embeddings are now
/// reproducible forever.
public enum LocalEmbeddings {
    public static let dimensions = 128

    /// Bumped whenever the embedding math changes in a way that invalidates
    /// previously persisted vectors. `IdeaStore` re-embeds on a version bump.
    public static let version = 2

    public static func embed(_ text: String) -> [Double] {
        let tokens = Tokenizer.tokens(text)
        guard !tokens.isEmpty else { return Array(repeating: 0.0, count: dimensions) }

        // Count raw term frequencies for unigrams and adjacent bigrams. Bigrams
        // give the model a little phrase sensitivity ("ambient memory" reads
        // differently from two unrelated mentions of those words).
        var counts: [Int: Double] = [:]
        for token in tokens {
            accumulate(&counts, key: token, weight: 1.0)
        }
        for index in tokens.indices.dropLast() {
            accumulate(&counts, key: "\(tokens[index]) \(tokens[index + 1])", weight: 0.5)
        }

        var vector = Array(repeating: 0.0, count: dimensions)
        for (bucket, rawCount) in counts {
            // Sublinear scaling damps the influence of repeated words so a long
            // rant about one topic does not drown out everything else.
            vector[bucket] += 1.0 + log(rawCount)
        }

        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    /// True cosine similarity in `[-1, 1]` (≥ 0 in practice for these non-negative
    /// vectors). Normalizes by both magnitudes so it stays correct even if an
    /// input was not pre-normalized.
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

    private static func accumulate(_ counts: inout [Int: Double], key: String, weight: Double) {
        let bucket = Int(Tokenizer.stableHash(key) % UInt64(dimensions))
        counts[bucket, default: 0] += weight
    }
}
