//
//  LocationCoarseningTests.swift
//  FloraFangTests
//
//  Covers LocationService.coarsen, the privacy guarantee behind "coordinates
//  are rounded to about a kilometre, never precise enough to find a house."
//  That claim is in the App Store privacy policy in those words, so this
//  math is worth pinning down with a real test rather than trusting it by
//  reading the code once.
//

import XCTest
@testable import FloraFang

final class LocationCoarseningTests: XCTestCase {

    func testRoundsToTwoDecimalPlaces() {
        let result = LocationService.coarsen(latitude: 35.084386, longitude: -106.651138)
        XCTAssertEqual(result.latitude, 35.08, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -106.65, accuracy: 1e-9)
    }

    func testRoundsAnotherRealWorldCoordinatePair() {
        // New York City. Picked because the longitude's rounding direction
        // (away from zero, since it's negative) is worth pinning down
        // explicitly rather than only ever testing positive values.
        let result = LocationService.coarsen(latitude: 40.7128, longitude: -74.0060)
        XCTAssertEqual(result.latitude, 40.71, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -74.01, accuracy: 1e-9)
    }

    func testResultNeverDiffersFromRawByMoreThanHalfAHundredthOfADegree() {
        // Structural version of "about a kilometre": rounding to 2 decimal
        // places can never move a coordinate by more than 0.005 degrees in
        // either direction.
        let samples: [(Double, Double)] = [
            (35.084386, -106.651138),
            (0.0, 0.0),
            (-33.8688, 151.2093),
            (89.9999, 179.9999)
        ]
        for (lat, lon) in samples {
            let result = LocationService.coarsen(latitude: lat, longitude: lon)
            XCTAssertLessThanOrEqual(abs(result.latitude - lat), 0.005 + 1e-9)
            XCTAssertLessThanOrEqual(abs(result.longitude - lon), 0.005 + 1e-9)
        }
    }

    func testAlreadyRoundedCoordinateIsUnchanged() {
        let result = LocationService.coarsen(latitude: 35.08, longitude: -106.65)
        XCTAssertEqual(result.latitude, 35.08, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, -106.65, accuracy: 1e-9)
    }

    func testZeroCoordinateStaysZero() {
        let result = LocationService.coarsen(latitude: 0.0, longitude: 0.0)
        XCTAssertEqual(result.latitude, 0.0, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, 0.0, accuracy: 1e-9)
    }
}
