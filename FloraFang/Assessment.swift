//
//  Assessment.swift
//  FloraFang
//
//  The single result type every tier of the cascade produces.
//
//  Design note: `ruledOut` exists but is permanently empty, and that is the
//  point. It used to carry "widow and recluse ruled out" whenever a benign
//  class cleared the confidence floor, which meant the exclusion came from
//  the same prediction that was wrong. A screen photo of an obvious black
//  widow classified as huntsman at 86% displayed an affirmative claim that it
//  was not a widow.
//
//  The reasoning was unsound even when the prediction is right. Ruling out a
//  widow means observing the absence of a ventral hourglass, and absence
//  cannot be established from a photo that may not show the underside. The
//  same principle governs FeatureRules: evidence escalates, never downgrades.
//
//  The field is kept rather than deleted so the constraint stays visible. If
//  an exclusion is ever reinstated it needs independent positive evidence of
//  a different group, not the absence of evidence for this one, and it should
//  never be reachable from a single classifier.
//

import Foundation

/// Which tier produced the answer. Surfaced in the UI so the user can tell
/// an offline guess from a network call, and so you can debug the cascade.
enum ResolutionTier: String {
    case coarse       = "on-device category"
    case hazard       = "on-device hazard model"
    case corroborated = "model and visible markings agree"
    case features     = "visible markings"
    case remote       = "remote model"
    case refusal      = "insufficient confidence"
}

struct Assessment {
    /// Unique per scan. Without this, two scans producing the identical result
    /// (very common with refusals — same headline, same label, same tier) share
    /// an identity, and SwiftUI's item-based presentation treats the second one
    /// as already-shown and silently skips it.
    let scanID = UUID()

    /// What we're calling it. May be a group ("Widow spider") rather than a species.
    let headline: String

    /// Taxonomic framing: "Arachnid — Latrodectus", "Plant", etc.
    let group: String

    let hazard: Hazard
    let hazardNote: String

    /// 0...1. Meaningful only relative to the tier that produced it.
    let confidence: Double

    var tier: ResolutionTier

    /// Groups we can affirmatively exclude. Empty is honest; don't fabricate.
    let ruledOut: [String]

    let fieldNotes: [String]
    let nextStep: String

    /// The raw label from whatever model spoke last, kept for auditing.
    let rawLabel: String

    /// Catalog key for persistence.
    let categoryKey: String

    /// Set when the plant model produced a named toxic match. Lets the result
    /// screen offer the exposure flow for things that are dangerous if eaten,
    /// and prefill the suspected plant when it opens.
    var plantClass: PlantClass? = nil

    /// True when this is something an animal or child could be poisoned by.
    var warrantsExposureFlow: Bool {
        plantClass?.isSevereIfEaten ?? false
    }

    /// Markings the language model reported seeing, when that tier ran.
    /// Shown to the user for confirmation rather than presented as fact,
    /// which is the whole point of extracting features instead of a species.
    var observedFeatures: [DiagnosticFeature] = []

    /// Set when the Core ML classifier and the visible markings point at
    /// different groups. Surfaced rather than resolved silently: two models
    /// disagreeing is information the user should have.
    var disagreementNote: String? = nil

    /// True when we stopped short of an identification on purpose.
    var isRefusal: Bool { tier == .refusal }
}

extension Assessment {
    /// Build from a coarse catalog match (Tier 1 outcome for non-spiders).
    static func fromCatalog(
        _ entry: CatalogEntry,
        rawLabel: String,
        confidence: Double
    ) -> Assessment {
        Assessment(
            headline: entry.displayName,
            group: entry.group,
            hazard: entry.hazard,
            hazardNote: entry.hazardNote,
            confidence: confidence,
            tier: .coarse,
            ruledOut: [],
            fieldNotes: entry.fieldNotes,
            nextStep: entry.nextStep,
            rawLabel: rawLabel,
            categoryKey: entry.id
        )
    }
}
