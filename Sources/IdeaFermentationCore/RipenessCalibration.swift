import Foundation

/// A learned re-weighting of the six ripeness axes, fit from the operator's real build
/// outcomes. The default (no outcomes) is exactly the equal-weight mean the app has
/// always used, so scoring is unchanged until reality has taught it something. As
/// outcomes accumulate, the axes that actually separated the operator's wins from their
/// flops get more weight — so "ready" starts to mean what it has historically meant
/// *for them*, not a generic average.
///
/// Pure local statistics: deterministic, explainable, private, zero-cost. No LLM.
public struct RipenessCalibration: Codable, Equatable, Sendable {
    /// Per-axis multiplier, centered on 1.0 (equal weight). Missing axis ⇒ 1.0.
    public private(set) var weights: [String: Double]
    /// How many labeled build outcomes this was fit from.
    public private(set) var observations: Int

    public static let axes = ["novelty", "clarity", "evidence", "resonance", "feasibility", "timing"]

    /// Bounds on a single axis weight so no axis is fully ignored or allowed to dominate.
    static let minWeight = 0.3
    static let maxWeight = 2.0
    /// A score gap (positives vs negatives) of this many points counts as full signal.
    static let fullSignalGap = 40.0
    /// How far a fully-confident, fully-separated axis can move off equal weight.
    static let maxShift = 0.7

    public init(weights: [String: Double] = [:], observations: Int = 0) {
        self.weights = weights
        self.observations = observations
    }

    /// True once the fit actually diverged from equal weights (enough signal in both
    /// classes). An equal-weight calibration reports false even if it has observations.
    public var isCalibrated: Bool {
        !weights.isEmpty && weights.values.contains { abs($0 - 1.0) > 0.001 }
    }

    public func weight(_ axis: String) -> Double { weights[axis] ?? 1.0 }

    /// Combine the six axes into a ripeness score using the learned weights. With the
    /// default (empty) weights this is identical to the plain six-axis mean.
    public func ripeness(novelty: Double, clarity: Double, evidence: Double, resonance: Double, feasibility: Double, timing: Double) -> Double {
        let values: [(String, Double)] = [
            ("novelty", novelty), ("clarity", clarity), ("evidence", evidence),
            ("resonance", resonance), ("feasibility", feasibility), ("timing", timing)
        ]
        var weighted = 0.0
        var total = 0.0
        for (axis, value) in values {
            let w = weight(axis)
            weighted += w * value
            total += w
        }
        guard total > 0 else { return 0 }
        // Clamp BOTH ends: cloud-decoded axis values aren't guaranteed to be in 0–100,
        // so a malformed negative could otherwise yield a negative ripeness.
        return max(0, min(100, weighted / total))
    }

    /// Axes ordered by how much they currently drive the score, strongest first.
    public func drivers() -> [(axis: String, weight: Double)] {
        Self.axes.map { (axis: $0, weight: weight($0)) }.sorted { $0.weight > $1.weight }
    }

    /// One labeled training example: an idea's six axis scores at build time and whether
    /// the build went well.
    public struct Sample: Equatable, Sendable {
        public var novelty: Double
        public var clarity: Double
        public var evidence: Double
        public var resonance: Double
        public var feasibility: Double
        public var timing: Double
        public var positive: Bool

        public init(novelty: Double, clarity: Double, evidence: Double, resonance: Double, feasibility: Double, timing: Double, positive: Bool) {
            self.novelty = novelty
            self.clarity = clarity
            self.evidence = evidence
            self.resonance = resonance
            self.feasibility = feasibility
            self.timing = timing
            self.positive = positive
        }
    }

    /// Fit axis weights from labeled outcomes. Each axis gets more weight the more it
    /// separated wins from flops; the result is regularized toward equal weights by both
    /// a confidence ramp (few outcomes ⇒ barely moves) and a per-axis clamp, then
    /// renormalized so the mean weight stays 1.0 (keeping ripeness on the same scale).
    /// Returns equal weights until there are at least two wins AND two flops to compare.
    public static func fit(samples: [Sample]) -> RipenessCalibration {
        let positives = samples.filter(\.positive)
        let negatives = samples.filter { !$0.positive }
        let observations = samples.count

        guard positives.count >= 2, negatives.count >= 2 else {
            return RipenessCalibration(weights: [:], observations: observations)
        }

        // Confidence ramps to full once there are 4 of each — below that the move is damped.
        let strength = min(1.0, Double(min(positives.count, negatives.count)) / 4.0)

        var weights: [String: Double] = [:]
        for axis in axes {
            let positiveMean = mean(positives.map { value($0, axis) })
            let negativeMean = mean(negatives.map { value($0, axis) })
            let separation = max(-1.0, min(1.0, (positiveMean - negativeMean) / fullSignalGap))
            let raw = 1.0 + maxShift * strength * separation
            weights[axis] = max(minWeight, min(maxWeight, raw))
        }

        // Renormalize toward mean 1.0 so the weighted ripeness stays comparable to the
        // old mean, then re-clamp: asymmetric clamping can drop the post-clamp mean below
        // 1.0, and dividing by it could otherwise push the top axis past maxWeight. The
        // cap matters more than exact normalization, so the mean may drift slightly.
        let meanWeight = weights.values.reduce(0, +) / Double(weights.count)
        if meanWeight > 0 {
            for axis in axes {
                weights[axis] = max(minWeight, min(maxWeight, (weights[axis] ?? 1.0) / meanWeight))
            }
        }
        return RipenessCalibration(weights: weights, observations: observations)
    }

    private static func value(_ sample: Sample, _ axis: String) -> Double {
        switch axis {
        case "novelty": sample.novelty
        case "clarity": sample.clarity
        case "evidence": sample.evidence
        case "resonance": sample.resonance
        case "feasibility": sample.feasibility
        case "timing": sample.timing
        default: 0
        }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
