//
//  ClinicalQueryFilterTests.swift
//  FloraFangTests
//
//  The Field Naturalist chat must never answer a bite, symptom, treatment,
//  medication, or ingestion question. This filter is the only thing that
//  guarantees it, since the model's own instructions are a request, not a
//  guarantee. These tests pin both directions: medical questions blocked,
//  ordinary naturalist questions let through.
//

import XCTest
@testable import FloraFang

final class ClinicalQueryFilterTests: XCTestCase {

    private func blocked(_ q: String) -> Bool {
        ClinicalQueryFilter.isMedicalOrEmergencyQuery(q)
    }

    func testBlocksDirectBiteQuestions() {
        XCTAssertTrue(blocked("it bit my hand"))
        XCTAssertTrue(blocked("I got bitten, is that bad"))
        XCTAssertTrue(blocked("I think it stung me"))
    }

    func testBlocksPluralsAndInflectionsThatUsedToSlipThrough() {
        // Every one of these reached the model before the suffix fix.
        XCTAssertTrue(blocked("My dog has two bites, what should I give him"))
        XCTAssertTrue(blocked("what doses are safe"))
        XCTAssertTrue(blocked("any medications for this"))
        XCTAssertTrue(blocked("she has rashes on her arm"))
        XCTAssertTrue(blocked("my kid eats berries off this plant"))
        XCTAssertTrue(blocked("the wounds look red"))
    }

    func testBlocksSymptomTreatmentAndMedicationLanguage() {
        XCTAssertTrue(blocked("the swelling is spreading"))
        XCTAssertTrue(blocked("should I go to the hospital"))
        XCTAssertTrue(blocked("can I give benadryl"))
        XCTAssertTrue(blocked("is there an antivenom"))
    }

    func testBlocksIngestionLanguage() {
        XCTAssertTrue(blocked("my cat swallowed a leaf"))
        XCTAssertTrue(blocked("the baby chewed on it"))
        XCTAssertTrue(blocked("my dog ate some"))
    }

    func testBlocksEmergencyPhrasesRegardlessOfSpacingOrCase() {
        XCTAssertTrue(blocked("What   do I do if it crawls on me"))
        XCTAssertTrue(blocked("WHAT SHOULD I DO IF my toddler touched it"))
        XCTAssertTrue(blocked("is my dog going to die"))
        XCTAssertTrue(blocked("what do i do if\nit gets in my shoe"))
    }

    func testIsCaseInsensitive() {
        XCTAssertTrue(blocked("BITE"))
        XCTAssertTrue(blocked("Poison Control number?"))
    }

    func testLetsOrdinaryNaturalistQuestionsThrough() {
        // Over blocking is acceptable, but the chat has to stay useful for
        // what it's for: habitat, markings, photography, relocation.
        XCTAssertFalse(blocked("Where does this spider usually live?"))
        XCTAssertFalse(blocked("What angle should I photograph it from?"))
        XCTAssertFalse(blocked("Does it build a web?"))
        XCTAssertFalse(blocked("How do I move it outside safely?"))
        XCTAssertFalse(blocked("What time of year are they active?"))
        XCTAssertFalse(blocked("Tell me about its markings"))
    }

    func testWordBoundariesPreventFalseMatchesInsideOtherWords() {
        // "bit" must not fire on "habitat", "er" must not fire on "where",
        // "ice" must not fire on "notice".
        XCTAssertFalse(blocked("what is its habitat"))
        XCTAssertFalse(blocked("where is it found"))
        XCTAssertFalse(blocked("did you notice the pattern"))
    }

    func testEmptyQueryIsNotBlocked() {
        XCTAssertFalse(blocked(""))
        XCTAssertFalse(blocked("   "))
    }
}
