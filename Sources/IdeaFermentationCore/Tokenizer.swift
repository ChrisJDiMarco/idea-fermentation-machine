import Foundation

/// Deterministic text tokenization shared by the local embedding model and the
/// taste profile. Everything here is intentionally pure and stable across
/// process launches — unlike `String.hashValue`, which Swift seeds randomly per
/// run and therefore must never be used for anything persisted to disk.
public enum Tokenizer {
    /// Common English function words that carry no thematic signal. Kept small on
    /// purpose: aggressive stoplists hurt recall on short idea notes.
    public static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
        "had", "her", "was", "one", "our", "out", "day", "get", "has", "him",
        "his", "how", "man", "new", "now", "old", "see", "two", "way", "who",
        "boy", "did", "its", "let", "put", "say", "she", "too", "use", "that",
        "this", "with", "have", "from", "they", "will", "would", "there", "their",
        "what", "about", "which", "when", "make", "like", "time", "just", "into",
        "than", "them", "then", "some", "could", "other", "also", "your", "more",
        "been", "were", "very", "want", "need", "over", "such", "only", "thing"
    ]

    /// Splits text into normalized, stemmed content tokens.
    /// Lowercased, alphanumeric-delimited, stopword-filtered, light-stemmed.
    public static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
            .filter { !stopwords.contains($0) }
            .map(stem)
            .filter { $0.count >= 2 }
    }

    /// The unique stemmed vocabulary of a piece of text.
    public static func vocabulary(_ text: String) -> Set<String> {
        Set(tokens(text))
    }

    /// A conservative suffix stripper. Not a full Porter stemmer — just enough to
    /// fold the most common inflections ("prototypes"/"prototyping" → "prototyp")
    /// so semantically identical ideas line up in the embedding space. Numeric
    /// tokens are left untouched.
    public static func stem(_ token: String) -> String {
        guard token.count > 4, token.contains(where: { $0.isLetter }) else { return token }
        var word = token
        for suffix in ["ization", "iveness", "ingly", "edly", "ing", "ned", "ed", "ly", "ies", "es", "s"] {
            if word.count > suffix.count + 2, word.hasSuffix(suffix) {
                word.removeLast(suffix.count)
                if suffix == "ies" { word.append("y") }
                break
            }
        }
        return word
    }

    /// FNV-1a 64-bit hash. Deterministic across launches, platforms, and builds —
    /// the property `String.hashValue` deliberately does not provide.
    public static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
