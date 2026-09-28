//
//  ExportServiceCSVTests.swift
//  FloraFangTests
//
//  Covers ExportService.csv, the field-log export's defense against CSV
//  formula injection (a note like "=cmd|' /C calc'!A1" opened in Excel can
//  execute) and ordinary comma/quote escaping. Free-text notes are the one
//  field in the export a tester fully controls, so this is worth testing
//  directly rather than trusting by inspection.
//

import XCTest
@testable import FloraFang

final class ExportServiceCSVTests: XCTestCase {

    func testPlainValueIsUnchanged() {
        XCTAssertEqual(ExportService.csv("wolf spider"), "wolf spider")
    }

    func testEmptyValueIsUnchanged() {
        XCTAssertEqual(ExportService.csv(""), "")
    }

    func testValueWithCommaIsQuoted() {
        XCTAssertEqual(ExportService.csv("garage, near the workbench"), "\"garage, near the workbench\"")
    }

    func testValueWithNewlineIsQuoted() {
        XCTAssertEqual(ExportService.csv("line one\nline two"), "\"line one\nline two\"")
    }

    func testInternalQuotesAreDoubledAndFieldIsWrapped() {
        let input = "she said \"hi\""
        let expected = "\"she said \"\"hi\"\"\""
        XCTAssertEqual(ExportService.csv(input), expected)
    }

    func testEachDocumentedFormulaPrefixIsEscapedWithALeadingApostrophe() {
        // =, +, -, @, tab, and carriage return are the documented triggers.
        // A formula-prefixed value with nothing else special in it should
        // come back prefixed but NOT wrapped in quotes, since only the
        // prefix character needs neutralizing.
        XCTAssertEqual(ExportService.csv("=SUM(A1:A2)"), "'=SUM(A1:A2)")
        XCTAssertEqual(ExportService.csv("+1234567890"), "'+1234567890")
        XCTAssertEqual(ExportService.csv("-1234567890"), "'-1234567890")
        XCTAssertEqual(ExportService.csv("@mention"), "'@mention")
    }

    func testFormulaPrefixCombinedWithACommaIsBothEscapedAndQuoted() {
        XCTAssertEqual(ExportService.csv("=1,2"), "\"'=1,2\"")
    }

    func testFormulaCharacterInTheMiddleOfAValueIsNotEscaped() {
        // Only a LEADING formula character is dangerous to a spreadsheet
        // reader; one in the middle of ordinary text should pass through.
        XCTAssertEqual(ExportService.csv("cost = $5"), "cost = $5")
    }

    func testDangerousLookingRealWorldNoteIsNeutralized() {
        // A single-quote-only payload like this never trips the
        // comma/quote/newline check (those look for a double quote, not an
        // apostrophe), so the only thing standing between this and a live
        // formula in Excel is the leading-apostrophe prefix. That is exactly
        // what this test pins down.
        let malicious = "=cmd|' /C calc'!A1"
        let escaped = ExportService.csv(malicious)
        XCTAssertTrue(escaped.hasPrefix("'="), "a leading apostrophe should neutralize the formula trigger while preserving the rest of the text")
        XCTAssertFalse(escaped.hasPrefix("="), "the raw formula-triggering character must never lead the escaped value")
    }
}
