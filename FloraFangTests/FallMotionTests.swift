//
//  FallMotionTests.swift
//  FloraFangTests
//
//  Leaves, petals, and snow all run on FallMotion. The bug this replaced
//  was particles never reaching the bottom, so these pin that they do.
//

import XCTest
@testable import FloraFang

final class FallMotionTests: XCTestCase {

    private let leaf = FallMotion(
        topY: -30, bottomY: 900,
        fallDuration: 8, restDuration: 3,
        swayAmplitude: 18, swayPeriod: 4.4,
        baseRotation: 0, spin: 160, maxOpacity: 0.6
    )

    func testStartsAtTheTop() {
        XCTAssertEqual(leaf.sample(at: 0).y, -30, accuracy: 0.001)
    }

    func testReachesTheBottomAtTheEndOfTheFall() {
        XCTAssertEqual(leaf.sample(at: 7.999).y, 900, accuracy: 1)
    }

    func testRestsAtTheBottomWithoutDrifting() {
        let landed = leaf.sample(at: 8.5)
        let later = leaf.sample(at: 10.0)
        XCTAssertEqual(landed.y, 900, accuracy: 0.001)
        XCTAssertEqual(later.y, 900, accuracy: 0.001)
        XCTAssertEqual(landed.xOffset, later.xOffset, accuracy: 0.001, "a resting leaf shouldn't keep sliding sideways")
    }

    func testFallsMonotonicallyDownward() {
        var previous = leaf.sample(at: 0).y
        for step in stride(from: 0.1, to: 8.0, by: 0.1) {
            let y = leaf.sample(at: step).y
            XCTAssertGreaterThanOrEqual(y, previous)
            previous = y
        }
    }

    func testRecyclesToTheTopAfterOneCycle() {
        XCTAssertEqual(leaf.sample(at: leaf.cycle + 0.001).y, -30, accuracy: 1)
    }

    func testFadesInAndOutAtTheEdgesOfTheCycle() {
        XCTAssertEqual(leaf.sample(at: 0).opacity, 0, accuracy: 0.001)
        XCTAssertEqual(leaf.sample(at: 4).opacity, 0.6, accuracy: 0.001)
        XCTAssertLessThan(leaf.sample(at: leaf.cycle - 0.05).opacity, 0.1)
    }

    func testWrappingParticlesFallPastTheBottomEdge() {
        // Petals and snow have no rest; they fall off screen and wrap.
        let snow = FallMotion(
            topY: -20, bottomY: 986,
            fallDuration: 10,
            swayAmplitude: 12, swayPeriod: 8,
            baseRotation: 0, spin: 120, maxOpacity: 0.3
        )
        XCTAssertGreaterThan(snow.sample(at: 9.99).y, 950)
    }

    func testNegativeTimeStillProducesAValidPosition() {
        let y = leaf.sample(at: -3).y
        XCTAssertTrue((-30...900).contains(y))
    }
}

final class CandleFlickerTests: XCTestCase {

    func testIntensityStaysWithinItsBounds() {
        for step in stride(from: 0.0, to: 60.0, by: 0.05) {
            let v = CandleFlicker.intensity(at: step)
            XCTAssertGreaterThanOrEqual(v, 0.55)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }

    func testIntensityActuallyVaries() {
        let samples = stride(from: 0.0, to: 5.0, by: 0.1).map(CandleFlicker.intensity(at:))
        XCTAssertGreaterThan((samples.max() ?? 0) - (samples.min() ?? 0), 0.15, "a candle that doesn't change isn't flickering")
    }
}
