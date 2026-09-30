//
//  PoisonResourcesTests.swift
//  FloraFangTests
//
//  A typo in one of these numbers is the worst bug this app could ship,
//  and it would never show up in a screenshot. Pin every digit.
//

import XCTest
@testable import FloraFang

@MainActor
final class PoisonResourcesTests: XCTestCase {

    private func resource(named name: String) -> PoisonResource? {
        PoisonResources.all.first { $0.name == name }
    }

    func testHumanPoisonControlNumberIsExact() {
        let r = resource(named: "Poison Control (people)")
        XCTAssertEqual(r?.dialString, "18002221222")
        XCTAssertEqual(r?.telURL?.absoluteString, "tel://18002221222")
        XCTAssertEqual(r?.audience, .human)
    }

    func testASPCANumberIsExact() {
        let r = resource(named: "ASPCA Animal Poison Control")
        XCTAssertEqual(r?.dialString, "8884264435")
        XCTAssertEqual(r?.telURL?.absoluteString, "tel://8884264435")
        XCTAssertEqual(r?.audience, .pet)
    }

    func testPetPoisonHelplineNumberIsExact() {
        let r = resource(named: "Pet Poison Helpline")
        XCTAssertEqual(r?.dialString, "8557647661")
        XCTAssertEqual(r?.telURL?.absoluteString, "tel://8557647661")
        XCTAssertEqual(r?.audience, .pet)
    }

    func testDialStringsAreDigitsOnly() {
        // The tel:// URL is built by interpolation; anything but digits
        // there could change what gets dialed.
        for r in PoisonResources.all {
            XCTAssertTrue(r.dialString.allSatisfy(\.isNumber), "\(r.name) dial string has non digits")
            XCTAssertNotNil(r.telURL, "\(r.name) did not produce a valid tel URL")
        }
    }

    func testDisplayedNumberMatchesDialedNumber() {
        // What the person reads on screen must be what the phone dials.
        for r in PoisonResources.all {
            let displayedDigits = r.phone.filter(\.isNumber)
            XCTAssertTrue(r.dialString.hasSuffix(displayedDigits), "\(r.name): shows \(r.phone) but dials \(r.dialString)")
        }
    }

    func testPetLinesDiscloseTheConsultationFee() {
        for r in PoisonResources.forAudience(.pet) {
            XCTAssertTrue(r.detail.lowercased().contains("fee"), "\(r.name) should mention its fee")
        }
    }

    func testAudienceFilterSplitsCorrectly() {
        XCTAssertEqual(PoisonResources.forAudience(.human).count, 1)
        XCTAssertEqual(PoisonResources.forAudience(.pet).count, 2)
    }
}

@MainActor
final class PoisonResourcesSingleSourceTests: XCTestCase {

    func testNamedResourcesAreTheSameEntriesAsTheList() {
        // Screens dial PoisonResources.human / .aspca / .petPoisonHelpline
        // directly; this ties those to the list the other tests pin.
        let dials = PoisonResources.all.map(\.dialString)
        XCTAssertTrue(dials.contains(PoisonResources.human.dialString))
        XCTAssertTrue(dials.contains(PoisonResources.aspca.dialString))
        XCTAssertTrue(dials.contains(PoisonResources.petPoisonHelpline.dialString))
    }

    func testCallURLMatchesTelURL() {
        for r in PoisonResources.all {
            XCTAssertEqual(r.callURL, r.telURL)
        }
    }
}
