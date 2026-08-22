//
//  IdentificationCascade.swift
//  FloraFang
//
//  Runs the tiers in order, stopping at the first one confident enough to
//  answer. Tier 4 always answers, so this function never fails to produce
//  something honest.
//
//    1. Vision coarse category   — offline, free, ~50ms
//    2. Core ML hazard model     — offline, free, ~100ms   (skipped if absent)
//    3. Remote model             — network, costs money     (off by default)
//    4. Structured refusal       — always available
//

import Foundation
import Vision
import UIKit

@MainActor
@Observable
final class IdentificationCascade {

    private let classifier = HazardClassifier()
    private let gate = ConfidenceGate.calibrated
    private let remote: RemoteIdentifying

    /// Trace of which tiers ran, for debugging and for the Action Lab-style
    /// evaluation you'll want later.
    private(set) var lastTrace: [String] = []

    init(remote: RemoteIdentifying = DisabledRemoteIdentifier()) {
        self.remote = remote
    }

    func assess(_ image: UIImage) async throws -> Assessment {
        lastTrace = []

        // ---- Tier 1: coarse category ------------------------------------
        let coarse = try await coarseCategory(image)
        lastTrace.append("tier1: \(coarse.rawLabel) @ \(pct(coarse.confidence))")

        // Anything that isn't a spider is fully answered by the catalog —
        // unless we're not confident enough to make a claim at all.
        guard coarse.entry.id == "spider" else {
            if coarse.isLowConfidence {
                lastTrace.append("tier1: below \(pct(lowConfidenceFloor)) floor, hedging")
                return uncertainCategory(coarse)
            }
            return .fromCatalog(
                coarse.entry,
                rawLabel: coarse.rawLabel,
                confidence: coarse.confidence
            )
        }

        // ---- Tier 2: hazard model ---------------------------------------
        if await classifier.isAvailable {
            if let prediction = try await classifier.classify(image) {
                lastTrace.append("tier2: \(prediction.rawLabel) @ \(pct(prediction.confidence))")

                let verdict = gate.evaluate(
                    top: (prediction.spiderClass, prediction.confidence),
                    runnerUp: prediction.runnerUpConfidence
                )
                lastTrace.append("gate: \(verdict)")

                switch verdict {
                case .accept:
                    return assessment(from: prediction, asWarning: false)
                case .acceptAsWarning:
                    return assessment(from: prediction, asWarning: true)
                case .escalate:
                    break // fall through
                }
            }
        } else {
            lastTrace.append("tier2: no model in bundle, skipped")
        }

        // ---- Tier 3: remote ---------------------------------------------
        if remote.isEnabled {
            if let remoteResult = try? await remote.identify(image) {
                lastTrace.append("tier3: resolved")
                return remoteResult
            }
            lastTrace.append("tier3: no result")
        } else {
            lastTrace.append("tier3: disabled")
        }

        // ---- Tier 4: refuse, usefully -----------------------------------
        lastTrace.append("tier4: refusal")
        return refusal(rawLabel: coarse.rawLabel, confidence: coarse.confidence)
    }

    // MARK: - Tier 1

    private struct Coarse {
        let entry: CatalogEntry
        let rawLabel: String
        let confidence: Double
        let isLowConfidence: Bool
    }

    private func coarseCategory(_ image: UIImage) async throws -> Coarse {
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = ClassifyImageRequest()
        // The image arriving here is ALREADY cropped to the capture square, so
        // don't crop again — that would throw away the framing the user chose.
        request.cropAndScaleAction = .scaleToFit
        let observations = try await request.perform(on: cgImage)

        guard !observations.isEmpty else { throw IdentificationError.noResults }

        // Gather every catalog match in the ranked list, not just the first.
        var candidates: [(entry: CatalogEntry, label: String, confidence: Double)] = []
        for observation in observations.prefix(25) where observation.confidence >= 0.05 {
            if let match = Catalog.match(rawLabel: observation.identifier) {
                candidates.append((match, observation.identifier, Double(observation.confidence)))
            }
        }

        guard let top = candidates.first else {
            return Coarse(
                entry: Catalog.unknownEntry,
                rawLabel: observations[0].identifier,
                confidence: Double(observations[0].confidence),
                isLowConfidence: true
            )
        }

        // SAFETY ROUTING. Taking the highest-ranked match is wrong here.
        //
        // Vision confuses spiders with insects constantly — small dark body,
        // many legs, similar context. If "insect" scores 0.25 and "spider"
        // scores 0.20, first-match-wins sends it down the insect path and the
        // hazard classifier never runs. After the model is trained, that means
        // a widow gets reported as "Insect — most are harmless."
        //
        // So: if a higher-hazard category appears anywhere in the plausible
        // range, prefer it. Being wrong toward caution costs a user nothing.
        let chosen = preferHazardous(candidates, topConfidence: top.confidence)

        return Coarse(
            entry: chosen.entry,
            rawLabel: chosen.label,
            confidence: chosen.confidence,
            isLowConfidence: chosen.confidence < lowConfidenceFloor
        )
    }

    /// Categories where a miss is dangerous, in priority order.
    private static let hazardPriority = ["spider", "snake", "mushroom"]

    private func preferHazardous(
        _ candidates: [(entry: CatalogEntry, label: String, confidence: Double)],
        topConfidence: Double
    ) -> (entry: CatalogEntry, label: String, confidence: Double) {

        // A hazardous category wins if it's within a reasonable margin of the
        // leader. Half the top score is deliberately generous.
        let threshold = max(topConfidence * 0.5, 0.04)

        for key in Self.hazardPriority {
            if let hit = candidates.first(where: { $0.entry.id == key && $0.confidence >= threshold }) {
                return hit
            }
        }
        return candidates[0]
    }

    /// Below this, we don't present the category as a finding.
    private let lowConfidenceFloor: Double = 0.30

    // MARK: - Debug

    /// Vision's full ranked label list, unfiltered by the catalog.
    /// Development tool — this is how you find labels your matchTerms miss.
    func rawLabels(_ image: UIImage, limit: Int = 20) async throws -> [RankedLabel] {
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = ClassifyImageRequest()
        request.cropAndScaleAction = .centerCrop
        let observations = try await request.perform(on: cgImage)

        return observations.prefix(limit).map {
            RankedLabel(identifier: $0.identifier, confidence: Double($0.confidence))
        }
    }

    // MARK: - Building assessments

    private func assessment(from prediction: HazardPrediction, asWarning: Bool) -> Assessment {
        let sc = prediction.spiderClass

        // When we're only warning, don't claim an identification. Say what the
        // evidence supports and no more.
        let headline = asWarning
            ? "Possibly a \(sc.displayName.lowercased())"
            : sc.displayName

        let note = asWarning
            ? "Evidence is weak, but consistent with a \(sc.displayName.lowercased()). Treat it as one until you know otherwise. \(sc.hazardNote)"
            : sc.hazardNote

        return Assessment(
            headline: headline,
            group: sc.genus,
            hazard: sc.hazard,
            hazardNote: note,
            confidence: prediction.confidence,
            tier: .hazard,
            ruledOut: ruledOutGroups(given: sc, confidence: prediction.confidence),
            fieldNotes: sc.fieldNotes,
            nextStep: sc.nextStep,
            rawLabel: prediction.rawLabel,
            categoryKey: "spider"
        )
    }

    /// Only claim an exclusion when the evidence actually supports it.
    /// An empty list is an honest answer.
    private func ruledOutGroups(given sc: SpiderClass, confidence: Double) -> [String] {
        guard !sc.isMedicallySignificant, confidence >= gate.benignFloor else { return [] }
        return ["Widow (Latrodectus)", "Recluse (Loxosceles)"]
    }

    /// A weak Tier 1 result. "Insect" in large type at 16% confidence reads as
    /// an identification when it's closer to a coin flip — so we hedge the
    /// wording and keep the hazard framing conservative.
    private func uncertainCategory(_ coarse: Coarse) -> Assessment {
        let entry = coarse.entry
        return Assessment(
            headline: "Possibly \(article(for: entry.displayName)) \(entry.displayName.lowercased())",
            group: entry.group,
            // Never downgrade to "safe" on weak evidence.
            hazard: entry.hazard == .safe ? .caution : entry.hazard,
            hazardNote: "Confidence is low, so treat this as a guess rather than an identification. \(entry.hazardNote)",
            confidence: coarse.confidence,
            tier: .coarse,
            ruledOut: [],
            fieldNotes: [
                "Zoom in and retake so the subject fills the square — that alone usually fixes a weak result.",
                "Tap the subject on screen to lock focus before shooting.",
                "Plain, evenly lit backgrounds help far more than bright light."
            ] + entry.fieldNotes.prefix(1),
            nextStep: entry.nextStep,
            rawLabel: coarse.rawLabel,
            categoryKey: entry.id
        )
    }

    private func article(for word: String) -> String {
        "aeiouAEIOU".contains(word.first ?? "x") ? "an" : "a"
    }

    private func refusal(rawLabel: String, confidence: Double) -> Assessment {
        Assessment(
            headline: "Spider — group not determined",
            group: "Arachnid",
            hazard: .caution,
            hazardNote: "This is a spider, but FloraFang can't tell you which group with enough confidence to be useful. It is NOT ruling out a widow or recluse. Don't handle it.",
            confidence: confidence,
            tier: .refusal,
            ruledOut: [],
            fieldNotes: [
                "Retake from directly above with the whole spider in the square.",
                "A shot of the underside of the abdomen is the single most useful angle.",
                "Steady light beats bright light — flash washes out the markings that matter."
            ],
            nextStep: "For a human answer, post the photo to iNaturalist or an arachnology group.",
            rawLabel: rawLabel,
            categoryKey: "spider"
        )
    }

    private func pct(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
}
