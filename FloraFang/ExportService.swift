//
//  ExportService.swift
//  FloraFang
//
//  Exports the field log as a zip: every photo, plus a CSV of what the app
//  said about each one.
//
//  WHY THIS SHAPE AND NOT AN UPLOAD:
//
//  The app currently makes zero network calls, and the privacy policy says so
//  in those words. Adding a "help improve the model" upload would break that
//  promise, require a server, require a privacy policy rewrite, and require
//  disclosing data collection in App Store Connect. For five TestFlight
//  testers that is a large amount of machinery and a permanent architectural
//  concession to solve a temporary problem.
//
//  A share sheet solves the same problem with none of it. The tester exports,
//  AirDrops or emails the file, and the app stays exactly as private as it
//  claims to be. The data arrives labelled with what the model predicted,
//  which is the part that makes it useful as training input.
//
//  If this ever becomes a real ongoing pipeline rather than a test period
//  convenience, revisit it then, deliberately, with the privacy policy open.
//

import Foundation
import UIKit
import SwiftData

enum ExportError: Error, LocalizedError {
    case noEntries
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noEntries:
            return "Nothing in the field log to export yet."
        case .writeFailed(let detail):
            return "Couldn't build the export: \(detail)"
        }
    }
}

enum ExportService {

    /// Builds a zip in the temp directory and returns its URL for sharing.
    static func exportFieldLog(_ entries: [FieldEntry]) throws -> URL {
        guard !entries.isEmpty else { throw ExportError.noEntries }

        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let folderName = "florafang-export-\(stamp)"
        let workDir = fm.temporaryDirectory.appendingPathComponent(folderName)

        try? fm.removeItem(at: workDir)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        var rows: [String] = [
            "filename,captured_at,headline,category,raw_label,confidence,hazard,tier,verdict,actual_identity,latitude,longitude,note"
        ]

        for (index, entry) in entries.enumerated() {
            let base = String(format: "%03d_%@", index + 1, entry.categoryKey)
            var filename = ""

            if let data = entry.imageData {
                filename = "\(base).jpg"
                try data.write(to: workDir.appendingPathComponent(filename))
            }

            rows.append([
                csv(filename),
                csv(ISO8601DateFormatter().string(from: entry.capturedAt)),
                csv(entry.displayTitle),
                csv(entry.categoryKey),
                csv(entry.rawLabel),
                csv(String(format: "%.4f", entry.confidence)),
                csv(entry.hazardRaw),
                csv(entry.tierRaw),
                csv(entry.verdictRaw),
                csv(entry.actualIdentity),
                csv(entry.latitude.map { String($0) } ?? ""),
                csv(entry.longitude.map { String($0) } ?? ""),
                csv(entry.note)
            ].joined(separator: ","))
        }

        let csvURL = workDir.appendingPathComponent("field-log.csv")
        try rows.joined(separator: "\n").write(to: csvURL, atomically: true, encoding: .utf8)

        try readme().write(
            to: workDir.appendingPathComponent("README.txt"),
            atomically: true,
            encoding: .utf8
        )

        return try zip(workDir, named: folderName)
    }

    /// Foundation has no direct zip API, but NSFileCoordinator's
    /// forUploading option produces one for a directory. Standard trick and
    /// avoids pulling in a dependency for one feature.
    private static func zip(_ directory: URL, named name: String) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var result: URL?
        var copyError: Error?

        coordinator.coordinate(
            readingItemAt: directory,
            options: [.forUploading],
            error: &coordError
        ) { zippedURL in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(name).zip")
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: zippedURL, to: dest)
                result = dest
            } catch {
                copyError = error
            }
        }

        if let coordError { throw ExportError.writeFailed(coordError.localizedDescription) }
        if let copyError { throw ExportError.writeFailed(copyError.localizedDescription) }
        guard let result else { throw ExportError.writeFailed("no archive produced") }
        return result
    }

    /// Escapes a field for CSV. Notes are free text and will contain commas.
    private static func csv(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func readme() -> String {
        """
        FloraFang field log export

        WHAT IS IN HERE
        Every photo you saved, plus field-log.csv describing what the app
        said about each one at the time.

        CSV COLUMNS
        filename      matching image in this folder, blank if no photo
        captured_at   when the scan happened
        headline      what the app told you
        category      coarse category the cascade routed to
        raw_label     what the model actually emitted, before interpretation
        confidence    model confidence, 0 to 1
        hazard        safe, caution, avoid, or unknown
        tier          which tier of the cascade answered
        verdict       correct, wrong, or unsure, if you marked it
        actual_identity  what it really was, when you marked it wrong
        latitude      blank unless location capture was enabled
        longitude     blank unless location capture was enabled
        note          whatever you typed

        WHAT IT IS FOR
        Real photos taken on real phones in real conditions are the thing
        that improves the models. Training data comes from people with good
        cameras and good light; a spider on a baseboard at 11pm is a
        different problem, and only real use produces it.

        WHERE IT GOES
        Nowhere, unless you send it. This file was created on your device by
        you. The app has no server and makes no network calls.

        THE MOST USEFUL THING YOU CAN DO
        Open an entry and mark whether the app got it right. A confidence
        score on its own says nothing; pairing it with whether the answer was
        actually correct is what shows where the app is overconfident, and
        that is the whole reason for this test period.

        Marking "not sure" is genuinely useful. A guessed label looks like
        data and is worse than a blank one.
        """
    }
}
