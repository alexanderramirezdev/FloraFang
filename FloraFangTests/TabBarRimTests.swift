//
//  TabBarRimTests.swift
//  FloraFangTests
//
//  Where the seasonal critters stand. The rim value came from measuring a
//  real iPhone 18 Pro Max screenshot; this keeps it from drifting and
//  documents the home button phone floor.
//

import XCTest
@testable import FloraFang

final class TabBarRimTests: XCTestCase {

    func testProMaxRimMatchesMeasuredScreenshot() {
        // 34pt home indicator inset, rim measured at 83pt from the bottom.
        XCTAssertEqual(SeasonalAtmosphereView.rimInset(forBottomSafeArea: 34), 83, accuracy: 0.5)
    }

    func testHomeButtonPhonesGetAFloorInsteadOfANegativePillBottom() {
        XCTAssertEqual(SeasonalAtmosphereView.rimInset(forBottomSafeArea: 0), 70, accuracy: 0.5)
    }

    func testRimRisesWithTheSafeArea() {
        let small = SeasonalAtmosphereView.rimInset(forBottomSafeArea: 21)
        let large = SeasonalAtmosphereView.rimInset(forBottomSafeArea: 34)
        XCTAssertLessThanOrEqual(small, large)
    }
}
