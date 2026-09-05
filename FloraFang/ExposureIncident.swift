//
//  ExposureIncident.swift
//  FloraFang
//
//  SwiftData persistent record of an accidental exposure incident.
//  Kept so a user, doctor, or emergency vet can review past intake reports,
//  symptoms, and timestamps without losing data across emergency calls.
//

import Foundation
import SwiftData
import UIKit

@Model
final class ExposureIncident {
    var id: UUID
    var timestamp: Date

    /// Subject category: "child", "adult", "dog", "cat", "otherAnimal"
    var subjectRaw: String

    /// Subject detail: e.g. "60 lb lab mix, 4 years" or "35 lbs, 3 years old"
    var subjectDetail: String

    /// Suspected plant or spider, if identified or photographed
    var plantName: String
    var scientificName: String
    var rawLabel: String
    var confidence: Double

    /// Intake details
    var partEatenRaw: String
    var amount: String
    var timeOfExposure: Date
    var symptomsRaw: [String]
    var otherNotes: String

    /// Formatted relay summary ready for dispatch or medical staff
    var relaySummaryText: String

    /// Plant photo external storage blob
    @Attribute(.externalStorage) var imageData: Data?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        subjectRaw: String,
        subjectDetail: String = "",
        plantName: String = "",
        scientificName: String = "",
        rawLabel: String = "",
        confidence: Double = 0,
        partEatenRaw: String = "unknown",
        amount: String = "",
        timeOfExposure: Date = .now,
        symptomsRaw: [String] = [],
        otherNotes: String = "",
        relaySummaryText: String = "",
        imageData: Data? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.subjectRaw = subjectRaw
        self.subjectDetail = subjectDetail
        self.plantName = plantName
        self.scientificName = scientificName
        self.rawLabel = rawLabel
        self.confidence = confidence
        self.partEatenRaw = partEatenRaw
        self.amount = amount
        self.timeOfExposure = timeOfExposure
        self.symptomsRaw = symptomsRaw
        self.otherNotes = otherNotes
        self.relaySummaryText = relaySummaryText
        self.imageData = imageData
    }

    var subject: ExposureSubject {
        ExposureSubject(rawValue: subjectRaw) ?? .dog
    }

    var partEaten: ExposureReport.PlantPart {
        ExposureReport.PlantPart(rawValue: partEatenRaw) ?? .unknown
    }

    var displaySubject: String {
        subject.label
    }

    var displayPlant: String {
        plantName.isEmpty ? "Unidentified plant" : plantName
    }
}
