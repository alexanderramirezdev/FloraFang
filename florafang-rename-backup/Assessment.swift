//
//  Assessment.swift
//  FloraFang
//
//  The single result type every tier of the cascade produces.
//
//  Design note: this deliberately separates "what we determined" from
//  "what we ruled out." For a safety question, ruling out widow and recluse
//  is often more valuable than naming the species — and it's a claim we can
//  actually support. Most competitor apps only model the first half.
//

import Foundation

/// Which tier produced the answer. Surfaced in the UI so the user can tell
/// an offline guess from a network call, and so you can debug the cascade.
enum ResolutionTier: String {
    case coarse   = "on-device category"
    case hazard   = "on-device hazard model"
    case remote   = "remote model"
    case refusal  = "insufficient confidence"
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

    let tier: ResolutionTier

    /// Groups we can affirmatively exclude. Empty is honest; don't fabricate.
    let ruledOut: [String]

    let fieldNotes: [String]
    let nextStep: String

    /// The raw label from whatever model spoke last, kept for auditing.
    let rawLabel: String

    /// Catalog key for persistence.
    let categoryKey: String

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
