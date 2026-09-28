//
//  CalibrationMathTests.swift
//  FloraFangTests
//
//  Covers the temperature-scaling and entropy math shared by the spider and
//  plant classifiers. These numbers are the calibration story the whole
//  README leans on (T = 1.53, T = 1.62, T = 1.86, H > 2.35), so a silent
//  regression here is exactly the kind of bug that would not show up in a
//  simulator screenshot.
//

import XCTest
@testable import FloraFang

final class CalibrationMathTests: XCTestCase {

    // MARK: - temperatureScale

    func testTemperatureOfOneIsIdentity() {
        // T = 1 means pow(x, 1/1) = x, so scaling should reproduce the raw
        // (already-normalized) input untouched, just re-sorted.
        let raw: [(identifier: String, confidence: Double)] = [
            ("widow", 0.7), ("wolf_spider", 0.3)
        ]
        let result = CalibrationMath.temperatureScale(raw, temperature: 1.0)

        XCTAssertEqual(result[0].identifier, "widow")
        XCTAssertEqual(result[0].probability, 0.7, accuracy: 1e-9)
        XCTAssertEqual(result[1].identifier, "wolf_spider")
        XCTAssertEqual(result[1].probability, 0.3, accuracy: 1e-9)
    }

    func testTemperatureTwoOnTwoClassCaseHasAClosedFormAnswer() {
        // For a two-class distribution, sqrt(0.9)/sqrt(0.1) = sqrt(9) = 3
        // exactly, so renormalizing lands on exactly 0.75 / 0.25. This is a
        // real closed-form check, not a re-implementation of the code under
        // test disguised as a test.
        let raw: [(identifier: String, confidence: Double)] = [
            ("a", 0.9), ("b", 0.1)
        ]
        let result = CalibrationMath.temperatureScale(raw, temperature: 2.0)

        XCTAssertEqual(result[0].identifier, "a")
        XCTAssertEqual(result[0].probability, 0.75, accuracy: 1e-9)
        XCTAssertEqual(result[1].identifier, "b")
        XCTAssertEqual(result[1].probability, 0.25, accuracy: 1e-9)
    }

    func testTemperatureAboveOneSoftensAnOverconfidentPrediction() {
        // The whole point of T > 1: an overconfident raw softmax should come
        // out less confident after scaling, never more.
        let raw: [(identifier: String, confidence: Double)] = [
            ("widow", 0.99), ("recluse", 0.01)
        ]
        let result = CalibrationMath.temperatureScale(raw, temperature: 1.53)

        XCTAssertLessThan(result[0].probability, 0.99)
        XCTAssertGreaterThan(result[0].probability, 0.5)
    }

    func testOutputIsSortedDescendingRegardlessOfInputOrder() {
        let raw: [(identifier: String, confidence: Double)] = [
            ("c", 0.1), ("a", 0.6), ("b", 0.3)
        ]
        let result = CalibrationMath.temperatureScale(raw, temperature: 1.62)

        XCTAssertEqual(result.map(\.identifier), ["a", "b", "c"])
    }

    func testProbabilitiesAlwaysRenormalizeToOne() {
        let raw: [(identifier: String, confidence: Double)] = [
            ("a", 0.05), ("b", 0.05), ("c", 0.05), ("d", 0.85)
        ]
        for t in [0.5, 1.0, 1.53, 1.62, 1.86, 3.0] {
            let result = CalibrationMath.temperatureScale(raw, temperature: t)
            let total = result.reduce(0.0) { $0 + $1.probability }
            XCTAssertEqual(total, 1.0, accuracy: 1e-9, "sum should renormalize to 1 at T=\(t)")
        }
    }

    func testZeroConfidenceIsClampedNotNaN() {
        // A literal 0.0 raised to any positive power is 0, but the clamp to
        // 1e-6 exists specifically so this never produces NaN or a
        // divide-by-zero when every class reports 0.
        let raw: [(identifier: String, confidence: Double)] = [
            ("a", 0.0), ("b", 0.0)
        ]
        let result = CalibrationMath.temperatureScale(raw, temperature: 1.53)
        for entry in result {
            XCTAssertFalse(entry.probability.isNaN)
        }
    }

    // MARK: - shannonEntropyBits

    func testEntropyOfACertainPredictionIsZero() {
        XCTAssertEqual(CalibrationMath.shannonEntropyBits([1.0, 0.0, 0.0]), 0.0, accuracy: 1e-9)
    }

    func testEntropyOfAUniformDistributionIsLogBaseTwoOfClassCount() {
        // Uniform over 4 classes: H = log2(4) = 2.0 bits exactly.
        let uniform = [0.25, 0.25, 0.25, 0.25]
        XCTAssertEqual(CalibrationMath.shannonEntropyBits(uniform), 2.0, accuracy: 1e-9)
    }

    func testEntropyIncreasesAsDistributionSpreadsOut() {
        let peaked = CalibrationMath.shannonEntropyBits([0.97, 0.01, 0.01, 0.01])
        let spread = CalibrationMath.shannonEntropyBits([0.25, 0.25, 0.25, 0.25])
        XCTAssertLessThan(peaked, spread)
    }

    func testEntropyMatchesTheDocumentedOODThresholdOnANearUniformTenClassSpread() {
        // This is the shape of prediction the entropy filter exists to catch:
        // probability smeared thinly across all ten classes. It should clear
        // the documented H > 2.35 OOD bar used in HazardClassifier.
        let smeared = Array(repeating: 0.1, count: 10)
        XCTAssertGreaterThan(CalibrationMath.shannonEntropyBits(smeared), 2.35)
    }
}
