//
//  SpiderClassTests.swift
//  FloraFangTests
//

import XCTest
@testable import FloraFang

final class SpiderClassTests: XCTestCase {

    func testOnlyWidowAndRecluseAreMedicallySignificant() {
        let significant = SpiderClass.allCases.filter { $0.isMedicallySignificant }
        XCTAssertEqual(Set(significant), [.widow, .recluse])
    }

    func testHazardMappingMatchesTheDesignedTiers() {
        XCTAssertEqual(SpiderClass.widow.hazard, .avoid)
        XCTAssertEqual(SpiderClass.recluse.hazard, .avoid)

        XCTAssertEqual(SpiderClass.tarantula.hazard, .caution)
        XCTAssertEqual(SpiderClass.huntsman.hazard, .caution)
        XCTAssertEqual(SpiderClass.wolfSpider.hazard, .caution)
        XCTAssertEqual(SpiderClass.otherSpider.hazard, .caution)

        XCTAssertEqual(SpiderClass.orbWeaver.hazard, .safe)
        XCTAssertEqual(SpiderClass.jumpingSpider.hazard, .safe)
        XCTAssertEqual(SpiderClass.cellarSpider.hazard, .safe)
        XCTAssertEqual(SpiderClass.notMedicallySignificant.hazard, .safe)

        XCTAssertEqual(SpiderClass.notASpider.hazard, .unknown)
    }

    func testNoAvoidClassIsMissingFromMedicallySignificant() {
        // The inverse check of the hazard test above: nothing should ever be
        // able to carry .avoid hazard without also being flagged as
        // medically significant, since that flag is what drives the
        // asymmetric ConfidenceGate thresholds. If a future class breaks
        // this invariant, it would silently get the lenient benign gate
        // while still being labelled a class to avoid.
        for spiderClass in SpiderClass.allCases where spiderClass.hazard == .avoid {
            XCTAssertTrue(
                spiderClass.isMedicallySignificant,
                "\(spiderClass) has .avoid hazard but is not flagged medically significant"
            )
        }
    }

    func testEveryCaseRoundTripsThroughItsTrainingLabel() {
        for spiderClass in SpiderClass.allCases {
            XCTAssertEqual(SpiderClass.from(label: spiderClass.trainingLabel), spiderClass)
        }
    }

    func testFromLabelIsCaseInsensitive() {
        XCTAssertEqual(SpiderClass.from(label: "WIDOW"), .widow)
        XCTAssertEqual(SpiderClass.from(label: "Wolf_Spider"), .wolfSpider)
    }

    func testFromLabelReturnsNilForUnknownInput() {
        XCTAssertNil(SpiderClass.from(label: "definitely_not_a_real_class"))
        XCTAssertNil(SpiderClass.from(label: ""))
    }

    func testTrainingLabelsAreAllUniqueForCoreMLFolderMapping() {
        // Core ML maps a folder name straight to a label string. A collision
        // here would mean two classes silently resolving to the same
        // SpiderClass.
        let labels = SpiderClass.allCases.map(\.trainingLabel)
        XCTAssertEqual(labels.count, Set(labels).count, "duplicate training labels found")
    }
}
