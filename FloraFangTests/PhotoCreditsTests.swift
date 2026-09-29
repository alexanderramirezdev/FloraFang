import XCTest
@testable import FloraFang

final class PhotoCreditsTests: XCTestCase {
    func testEveryCreditHasValidLinks() {
        for credit in PhotoCredits.all {
            XCTAssertNotNil(credit.observationURL)
            XCTAssertNotNil(credit.photographerURL)
            XCTAssertFalse(credit.photographer.isEmpty)
        }
    }

    func testSubjectsAreUnique() {
        let subjects = PhotoCredits.all.map(\.subject)
        XCTAssertEqual(Set(subjects).count, subjects.count)
    }

    func testLicenseLinkExists() {
        XCTAssertNotNil(PhotoCredits.licenseURL)
    }
}
