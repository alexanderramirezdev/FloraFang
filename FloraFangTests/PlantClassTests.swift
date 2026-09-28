//
//  PlantClassTests.swift
//  FloraFangTests
//

import XCTest
@testable import FloraFang

final class PlantClassTests: XCTestCase {

    func testEveryCaseRoundTripsThroughItsTrainingLabel() {
        for plantClass in PlantClass.allCases {
            XCTAssertEqual(PlantClass.from(label: plantClass.trainingLabel), plantClass)
        }
    }

    func testFromLabelIsCaseInsensitive() {
        XCTAssertEqual(PlantClass.from(label: "OLEANDER"), .oleander)
        XCTAssertEqual(PlantClass.from(label: "Not_Known_Toxic"), .notKnownToxic)
    }

    func testFromLabelReturnsNilForUnknownInput() {
        XCTAssertNil(PlantClass.from(label: "not_a_real_plant"))
        XCTAssertNil(PlantClass.from(label: ""))
    }

    func testTrainingLabelsAreAllUniqueForCoreMLFolderMapping() {
        let labels = PlantClass.allCases.map(\.trainingLabel)
        XCTAssertEqual(labels.count, Set(labels).count, "duplicate training labels found")
    }

    func testNotKnownToxicIsNeverGivenAToxicSoundingDisplayName() {
        // This is the class the app leans on to never assert safety. If its
        // display copy ever drifted toward sounding like a clean bill of
        // health ("Safe", "Not toxic"), that would contradict the app's own
        // "never say something is safe to eat" premise.
        let name = PlantClass.notKnownToxic.displayName.lowercased()
        XCTAssertFalse(name.contains("safe"))
    }
}
