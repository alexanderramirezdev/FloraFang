//
//  ConfidenceGateTests.swift
//  FloraFangTests
//
//  This is the single most safety critical piece of logic in the app: the
//  asymmetric thresholds that decide whether an identification gets shown,
//  shown as a warning, or refused. A silent change to any of these numbers
//  changes the app's real world safety behavior without changing a single
//  pixel on screen, so it needs a test more than almost anything else here.
//

import XCTest
@testable import FloraFang

final class ConfidenceGateTests: XCTestCase {

    // MARK: - Guard the documented calibrated constants themselves.
    //
    // These exact numbers came from a 1,946-image holdout sweep (see
    // TRAINING.md / README.md). If one of these ever drifts, whether from a
    // fat-fingered edit or a well-meaning "let me just bump this a bit," this
    // test fails loudly instead of shipping a silently different safety
    // profile.

    func testCalibratedThresholdsMatchDocumentedValues() {
        let gate = ConfidenceGate.calibrated
        XCTAssertEqual(gate.dangerousFloor, 0.22)
        XCTAssertEqual(gate.benignFloor, 0.86)
        XCTAssertEqual(gate.escalationFloor, 0.22)
        XCTAssertEqual(gate.minimumMargin, 0.06)
    }

    // MARK: - Dangerous classes (widow, recluse): low bar to at least warn.

    func testDangerousClassAboveBenignFloorWithMarginAccepts() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.widow, 0.90), runnerUp: 0.05)
        XCTAssertEqual(verdict, .accept)
    }

    func testDangerousClassAboveBenignFloorButInsufficientMarginOnlyWarns() {
        // High confidence alone is not enough to fully accept: the runner-up
        // has to be far enough behind. This is what keeps a genuinely
        // ambiguous call from being presented as a confident answer.
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.widow, 0.90), runnerUp: 0.87)
        XCTAssertEqual(verdict, .acceptAsWarning)
    }

    func testDangerousClassAtModerateConfidenceIsWarnedNotAccepted() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.recluse, 0.50), runnerUp: 0.30)
        XCTAssertEqual(verdict, .acceptAsWarning)
    }

    func testDangerousClassBelowDangerousFloorEscalates() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.widow, 0.10), runnerUp: 0.05)
        XCTAssertEqual(verdict, .escalate)
    }

    func testDangerousClassRightAtDangerousFloorIsWarned() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.recluse, 0.22), runnerUp: nil)
        XCTAssertEqual(verdict, .acceptAsWarning)
    }

    // MARK: - Benign classes: high bar to accept outright, nothing below the
    // dangerous asymmetry gets a free pass.

    func testBenignClassAboveBenignFloorWithMarginAccepts() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.wolfSpider, 0.95), runnerUp: 0.02)
        XCTAssertEqual(verdict, .accept)
    }

    func testBenignClassInWarningBandIsWarnedNotAccepted() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.orbWeaver, 0.50), runnerUp: 0.10)
        XCTAssertEqual(verdict, .acceptAsWarning)
    }

    func testBenignClassBelowWarningFloorEscalates() {
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.jumpingSpider, 0.30), runnerUp: 0.10)
        XCTAssertEqual(verdict, .escalate)
    }

    func testBenignClassWithNarrowMarginEscalatesEvenAtHighConfidence() {
        // Unlike a dangerous class, a benign class gets no benefit of the
        // doubt without a clear margin: both the accept AND the warning
        // bands require it here, so a close call escalates instead of
        // showing as a soft benign warning.
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.cellarSpider, 0.90), runnerUp: 0.88)
        XCTAssertEqual(verdict, .escalate)
    }

    // MARK: - Cross-cutting behavior

    func testHighEntropyAlwaysEscalatesRegardlessOfConfidence() {
        // Layer 1 (OOD / entropy filter) wins outright, even over an
        // otherwise slam-dunk confident widow call.
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.widow, 0.99), runnerUp: 0.01, isHighEntropy: true)
        XCTAssertEqual(verdict, .escalate)
    }

    func testMissingRunnerUpDefaultsToAFullMargin() {
        // No second-place class at all should behave like the largest
        // possible margin, not like a missing/zero value that could
        // accidentally fail the margin check.
        let gate = ConfidenceGate.calibrated
        let verdict = gate.evaluate(top: (.notMedicallySignificant, 0.90), runnerUp: nil)
        XCTAssertEqual(verdict, .accept)
    }

    func testDangerousAndBenignClassesAreNotTreatedSymmetrically() {
        // The whole design point of this file: the same confidence value
        // should NOT produce the same verdict for a dangerous vs. benign
        // class at the boundary the README calls out.
        let gate = ConfidenceGate.calibrated
        let dangerousVerdict = gate.evaluate(top: (.widow, 0.30), runnerUp: 0.10)
        let benignVerdict = gate.evaluate(top: (.tarantula, 0.30), runnerUp: 0.10)

        XCTAssertEqual(dangerousVerdict, .acceptAsWarning, "a dangerous class at 0.30 must still surface as a warning")
        XCTAssertEqual(benignVerdict, .escalate, "a benign class at 0.30 should not be shown at all")
    }
}
