import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Ripeness calibration")
struct RipenessCalibrationTests {
    private func sample(_ evidence: Double, positive: Bool, base: Double = 50) -> RipenessCalibration.Sample {
        RipenessCalibration.Sample(novelty: base, clarity: base, evidence: evidence, resonance: base, feasibility: base, timing: base, positive: positive)
    }

    @Test func defaultIsEqualWeightMean() {
        let calibration = RipenessCalibration()
        #expect(!calibration.isCalibrated)
        // With no learning, ripeness equals the plain six-axis mean.
        let r = calibration.ripeness(novelty: 60, clarity: 40, evidence: 80, resonance: 20, feasibility: 100, timing: 0)
        #expect(abs(r - (60 + 40 + 80 + 20 + 100 + 0) / 6) < 0.0001)
    }

    @Test func tooFewOutcomesStayEqualWeight() {
        let calibration = RipenessCalibration.fit(samples: [sample(90, positive: true), sample(10, positive: false)])
        #expect(!calibration.isCalibrated)        // need ≥2 of each class
        #expect(calibration.observations == 2)    // but it still counts what it has seen
    }

    @Test func anAxisThatSeparatesWinsGetsMoreWeight() {
        // Evidence is high in every win and low in every flop; nothing else varies.
        let samples = [
            sample(95, positive: true), sample(90, positive: true), sample(88, positive: true),
            sample(10, positive: false), sample(15, positive: false), sample(5, positive: false)
        ]
        let calibration = RipenessCalibration.fit(samples: samples)

        #expect(calibration.isCalibrated)
        #expect(calibration.weight("evidence") > 1.0)              // the predictive axis is up-weighted
        #expect(calibration.weight("novelty") < calibration.weight("evidence")) // a flat axis is relatively lower
        #expect(calibration.drivers().first?.axis == "evidence")  // and leads the drivers list
    }

    @Test func weightsStayBoundedAndMeanNormalized() {
        let samples = [
            sample(100, positive: true), sample(100, positive: true), sample(100, positive: true), sample(100, positive: true),
            sample(0, positive: false), sample(0, positive: false), sample(0, positive: false), sample(0, positive: false)
        ]
        let calibration = RipenessCalibration.fit(samples: samples)
        for axis in RipenessCalibration.axes {
            #expect(calibration.weight(axis) >= RipenessCalibration.minWeight - 0.001)
            #expect(calibration.weight(axis) <= RipenessCalibration.maxWeight + 0.001)
        }
        // Mean weight is renormalized to ~1.0 so ripeness stays on the same scale.
        let mean = RipenessCalibration.axes.map(calibration.weight).reduce(0, +) / Double(RipenessCalibration.axes.count)
        #expect(abs(mean - 1.0) < 0.0001)
    }

    @Test func asymmetricSeparationStillRespectsTheWeightCap() {
        // Evidence predicts wins; every OTHER axis is inversely correlated (high in
        // flops). This drops the post-clamp mean below 1.0, and renormalizing could push
        // evidence past the 2.0 cap unless we re-clamp after normalizing.
        func s(evidenceHigh: Bool, positive: Bool) -> RipenessCalibration.Sample {
            RipenessCalibration.Sample(
                novelty: positive ? 40 : 70, clarity: positive ? 40 : 70, evidence: evidenceHigh ? 85 : 25,
                resonance: positive ? 40 : 70, feasibility: positive ? 40 : 70, timing: positive ? 40 : 70,
                positive: positive
            )
        }
        let samples = [
            s(evidenceHigh: true, positive: true), s(evidenceHigh: true, positive: true),
            s(evidenceHigh: true, positive: true), s(evidenceHigh: true, positive: true),
            s(evidenceHigh: false, positive: false), s(evidenceHigh: false, positive: false),
            s(evidenceHigh: false, positive: false), s(evidenceHigh: false, positive: false)
        ]
        let calibration = RipenessCalibration.fit(samples: samples)
        for axis in RipenessCalibration.axes {
            #expect(calibration.weight(axis) <= RipenessCalibration.maxWeight + 0.001)
            #expect(calibration.weight(axis) >= RipenessCalibration.minWeight - 0.001)
        }
    }

    @Test func ripenessNeverGoesNegativeOnOutOfRangeInput() {
        // Cloud-decoded axis values aren't guaranteed to be 0–100; a negative must not
        // produce a negative ripeness.
        let calibration = RipenessCalibration()
        let r = calibration.ripeness(novelty: -50, clarity: -50, evidence: -50, resonance: -50, feasibility: -50, timing: -50)
        #expect(r == 0)
    }

    @Test func reweightingChangesRipenessTowardThePredictiveAxis() {
        let samples = [
            sample(95, positive: true), sample(92, positive: true), sample(90, positive: true),
            sample(8, positive: false), sample(12, positive: false), sample(5, positive: false)
        ]
        let calibration = RipenessCalibration.fit(samples: samples)
        // An idea strong on evidence but weak elsewhere now scores higher than the plain
        // mean, because evidence is what predicts this operator's wins.
        let plainMean = (10.0 + 10 + 90 + 10 + 10 + 10) / 6
        let calibrated = calibration.ripeness(novelty: 10, clarity: 10, evidence: 90, resonance: 10, feasibility: 10, timing: 10)
        #expect(calibrated > plainMean)
    }
}
