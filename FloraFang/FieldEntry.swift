//
//  FieldEntry.swift
//  FloraFang
//

import Foundation
import SwiftData

/// One saved observation. @Model is SwiftData's equivalent of an EF entity class —
/// the macro generates the persistence plumbing so you just declare properties.
@Model
final class FieldEntry {
    var id: UUID
    var capturedAt: Date

    /// The catalog category we matched (e.g. "spider", "flower").
    var categoryKey: String

    /// The headline the assessment actually produced. Stored separately from
    /// the catalog name because a refusal reads "Spider — group not determined"
    /// while the catalog name is just "Spider" — showing the latter in the log
    /// makes a refusal look like a successful ID.
    /// Defaulted so existing stores migrate without a schema version.
    var headline: String = ""

    /// Which tier resolved it, so the log can flag refusals.
    var tierRaw: String = ""

    // The guidance text, stored rather than regenerated. A refusal's wording is
    // built at runtime and can't be reconstructed from the catalog, and catalog
    // text may change between app versions — a log entry should show what the
    // app actually told you at the time, not what it would say today.
    var group: String = ""
    var hazardNote: String = ""
    var fieldNotes: [String] = []
    var nextStep: String = ""
    var ruledOut: [String] = []

    // Tester feedback. This is what turns a field log into calibration data.
    //
    // A confidence score is uninterpretable on its own. Setting a threshold
    // requires pairs of "the model said 0.72" and "the model was right or
    // wrong," and only the person who was standing there can supply the
    // second half. Without this, more testers means more unlabelled photos
    // rather than a faster calibration.
    var verdictRaw: String = ""

    /// What it actually was, when the app got it wrong. Free text on purpose:
    /// a picker would constrain people to the classes the model already
    /// knows, and the useful corrections are often outside them.
    var actualIdentity: String = ""

    /// The raw Vision label, kept so you can audit what the classifier actually said.
    var rawLabel: String
    var confidence: Double

    /// Hazard level at time of capture, stored as a raw string so schema
    /// migrations stay simple if the enum changes later.
    var hazardRaw: String

    /// Photo stored as external data — SwiftData keeps large blobs out of the
    /// main store file automatically with this attribute.
    @Attribute(.externalStorage) var imageData: Data?

    var latitude: Double?
    var longitude: Double?
    var note: String

    init(
        categoryKey: String,
        headline: String = "",
        tierRaw: String = "",
        rawLabel: String,
        confidence: Double,
        hazardRaw: String,
        imageData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        note: String = ""
    ) {
        self.id = UUID()
        self.capturedAt = .now
        self.categoryKey = categoryKey
        self.headline = headline
        self.tierRaw = tierRaw
        self.rawLabel = rawLabel
        self.confidence = confidence
        self.hazardRaw = hazardRaw
        self.imageData = imageData
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
    }

    var hazard: Hazard { Hazard(rawValue: hazardRaw) ?? .unknown }

    var category: CatalogEntry? { Catalog.entry(forKey: categoryKey) }

    /// What to show in the log. Falls back to the catalog name for rows saved
    /// before headline existed.
    var displayTitle: String {
        headline.isEmpty ? (category?.displayName ?? "Unknown") : headline
    }

    var wasRefusal: Bool { tierRaw == ResolutionTier.refusal.rawValue }

    var verdict: Verdict? {
        get { Verdict(rawValue: verdictRaw) }
        set { verdictRaw = newValue?.rawValue ?? "" }
    }

    /// Falls back to catalog content for rows saved before these fields existed.
    var displayGroup: String {
        group.isEmpty ? (category?.group ?? "—") : group
    }

    var displayHazardNote: String {
        hazardNote.isEmpty ? (category?.hazardNote ?? "") : hazardNote
    }

    var displayFieldNotes: [String] {
        fieldNotes.isEmpty ? (category?.fieldNotes ?? []) : fieldNotes
    }

    var displayNextStep: String {
        nextStep.isEmpty ? (category?.nextStep ?? "") : nextStep
    }
}

extension FieldEntry {
    /// Preferred way to build an entry — keeps every call site from having to
    /// remember which of the dozen fields map to which part of the assessment.
    convenience init(assessment: Assessment, imageData: Data?, note: String) {
        self.init(
            categoryKey: assessment.categoryKey,
            headline: assessment.headline,
            tierRaw: assessment.tier.rawValue,
            rawLabel: assessment.rawLabel,
            confidence: assessment.confidence,
            hazardRaw: assessment.hazard.rawValue,
            imageData: imageData,
            note: note
        )
        self.group = assessment.group
        self.hazardNote = assessment.hazardNote
        self.fieldNotes = assessment.fieldNotes
        self.nextStep = assessment.nextStep
        self.ruledOut = assessment.ruledOut
    }
}

/// Whether the app got it right, as judged by the person who was there.
///
/// "Not sure" is a deliberate option rather than a cop out. Forcing a binary
/// would produce guesses, and a guessed label is worse than a missing one
/// because it looks like data.
nonisolated enum Verdict: String, CaseIterable, Identifiable {
    case correct
    case wrong
    case unsure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .correct: return "Got it right"
        case .wrong:   return "Got it wrong"
        case .unsure:  return "Not sure"
        }
    }

    var symbol: String {
        switch self {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        case .unsure:  return "questionmark.circle.fill"
        }
    }
}
