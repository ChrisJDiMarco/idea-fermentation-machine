import Foundation

/// Taste represented in CONCEPT space rather than as a bag of words. Two centroids — the
/// mean embedding of the ideas the operator committed to vs. the ones they dropped —
/// define a region of meaning. A new idea's affinity is simply how much closer it sits
/// to the liked region than the disliked one.
///
/// This is what lets the always-on, no-key local pass score resonance by *meaning*
/// ("this is the kind of thing you build") instead of by literal token overlap. Like
/// the rest of the learning loop it is deterministic, private, zero-cost, and a strict
/// no-op until there is real signal on both sides.
public struct TasteManifold: Equatable, Sendable {
    public let likedCentroid: [Double]
    public let dislikedCentroid: [Double]
    public let likedCount: Int
    public let dislikedCount: Int

    /// Minimum liked AND disliked examples (with usable embeddings) before the manifold
    /// influences scoring. Set to 2 (down from 3) so a solo builder actually reaches
    /// activation within a realistic amount of use — the `blendWeight` ramp keeps the
    /// first activation a mere sliver (0.125), so an early, noisier centroid can only
    /// nudge scoring, never swing it. The app's own decisions feed both sides now
    /// (quality-verified Ready → liked; auto-archived stale ideas → disliked), so the bar
    /// is reached by using the app, not only by manually recording build outcomes.
    public static let minPerSide = 2

    public init(likedCentroid: [Double] = [], dislikedCentroid: [Double] = [], likedCount: Int = 0, dislikedCount: Int = 0) {
        self.likedCentroid = likedCentroid
        self.dislikedCentroid = dislikedCentroid
        self.likedCount = likedCount
        self.dislikedCount = dislikedCount
    }

    public var isActive: Bool {
        likedCount >= Self.minPerSide
            && dislikedCount >= Self.minPerSide
            && !likedCentroid.isEmpty
            && !dislikedCentroid.isEmpty
    }

    /// How much weight the concept signal should take in the blend, ramping from a
    /// sliver at first activation toward 0.5 as more examples accumulate. This avoids a
    /// step change in scoring the instant the manifold turns on (which could otherwise
    /// yank an idea across a status threshold). 0 when inactive.
    public var blendWeight: Double {
        guard isActive else { return 0 }
        let n = min(likedCount, dislikedCount)
        let ramp = min(1.0, Double(n - Self.minPerSide + 1) / 4.0)
        return 0.5 * ramp
    }

    /// Concept-space affinity in [-1, 1]: positive when the idea sits closer to the
    /// liked region, negative when closer to the disliked region. 0 when the manifold is
    /// inactive or the embedding carries no signal — so it never moves scoring until it
    /// has earned the right to.
    public func affinity(for embedding: [Double]) -> Double {
        guard isActive, embedding.contains(where: { $0 != 0 }) else { return 0 }
        let toLiked = LocalEmbeddings.cosine(embedding, likedCentroid)
        let toDisliked = LocalEmbeddings.cosine(embedding, dislikedCentroid)
        return max(-1, min(1, toLiked - toDisliked))
    }

    /// Build the manifold from the corpus and outcomes. Liked = ideas committed to
    /// (marked Ready) or with a positive build outcome; disliked = ideas with a negative
    /// outcome, or archived without ever having a positive one — the same decision signal
    /// the rest of the learning loop uses.
    /// `excluding` drops one idea (the one being scored) from both sides, so an idea is
    /// never measured against a centroid it helped define — mirroring the self-exclusion
    /// the novelty scorer already uses.
    public static func build(ideas: [IdeaSeed], outcomes: [BuildOutcome], excluding excludedID: UUID? = nil) -> TasteManifold {
        let positiveIDs = Set(outcomes.filter { $0.result.isPositive }.map(\.ideaID))
        let negativeIDs = Set(outcomes.filter { !$0.result.isPositive }.map(\.ideaID))

        let likedVectors = ideas
            .filter { $0.id != excludedID && ($0.status == .ready || positiveIDs.contains($0.id)) }
            .map(\.embedding)
            .filter { $0.contains { $0 != 0 } }
        let dislikedVectors = ideas
            .filter { $0.id != excludedID && (negativeIDs.contains($0.id) || ($0.status == .archived && !positiveIDs.contains($0.id))) }
            .map(\.embedding)
            .filter { $0.contains { $0 != 0 } }

        return TasteManifold(
            likedCentroid: centroid(likedVectors),
            dislikedCentroid: centroid(dislikedVectors),
            likedCount: likedVectors.count,
            dislikedCount: dislikedVectors.count
        )
    }

    static func centroid(_ vectors: [[Double]]) -> [Double] {
        guard let dimension = vectors.first?.count, dimension > 0 else { return [] }
        var sum = [Double](repeating: 0, count: dimension)
        var counted = 0
        for vector in vectors where vector.count == dimension {
            for index in 0..<dimension { sum[index] += vector[index] }
            counted += 1
        }
        guard counted > 0 else { return [] }
        return sum.map { $0 / Double(counted) }
    }
}
