//
//  IdentificationCascade.swift
//  FloraFang
//
//  Runs the tiers in order, stopping at the first one confident enough to
//  answer. Tier 4 always answers, so this function never fails to produce
//  something honest.
//
//    1. Vision coarse category: offline, free, ~50ms
//    2. Core ML hazard model:   offline, free, ~100ms (skipped if absent)
//    3. Remote model:           network, costs money (off by default)
//    4. Structured refusal:     always available
//

import Foundation
import Vision
import UIKit

@MainActor
@Observable
final class IdentificationCascade {

    private let classifier = HazardClassifier()
    private let plantClassifier = PlantClassifier()
    private let featureExtractor = FeatureExtractor()

    /// Coarse categories worth handing to the plant toxicity model.
    /// Mushroom is included because a fungus photo misrouted here still
    /// resolves to notKnownToxic, which is the correct answer anyway.
    private static let plantCategories: Set<String> = ["plant", "flower", "mushroom"]
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

        // Plants get their own Tier 2. Categories that can carry a toxicity
        // answer route to the plant model; everything else is fully answered
        // by the catalog.
        if Self.plantCategories.contains(coarse.entry.id) {
            if let plantAssessment = try await plantTier(image, coarse: coarse) {
                return plantAssessment
            }
            // Plant model absent or unsure. Fall through to the catalog, which
            // still gives honest category level guidance.
        }

        // Anything that isn't a spider is fully answered by the catalog,
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

        // ---- Tier 2a: Core ML hazard model ------------------------------
        var corePrediction: HazardPrediction?
        var coreVerdict: ConfidenceGate.Verdict = .escalate

        if await classifier.isAvailable {
            if let prediction = try await classifier.classify(image) {
                corePrediction = prediction
                lastTrace.append("tier2a: \(prediction.rawLabel) @ \(pct(prediction.confidence))")
                lastTrace.append("entropy: \(String(format: "%.2f", prediction.entropy)) (triggered: \(prediction.isHighEntropy))")
                coreVerdict = gate.evaluate(
                    top: (prediction.spiderClass, prediction.confidence),
                    runnerUp: prediction.runnerUpConfidence,
                    isHighEntropy: prediction.isHighEntropy
                )
                lastTrace.append("gate: \(coreVerdict)")
            }
        } else {
            lastTrace.append("tier2a: no model in bundle, skipped")
        }

        // ---- Tier 2b: visible markings ----------------------------------
        //
        // Runs alongside Core ML rather than after it, because the value is
        // in the comparison. Two models that fail differently disagreeing is
        // information; either one alone is just a guess with a number on it.
        var extraction: ExtractionResult?

        if await featureExtractor.isAvailable {
            do {
                extraction = try await featureExtractor.extract(from: image)
                if let ex = extraction {
                    let names = ex.report.visibleFeatures.map(\.rawValue).joined(separator: ", ")
                    lastTrace.append("tier2b: features [\(names.isEmpty ? "none visible" : names)]")
                    if let indicated = ex.verdict.indicatedClass {
                        lastTrace.append("tier2b: rules indicate \(indicated.trainingLabel), \(ex.verdict.strength)")
                    }
                }
            } catch {
                lastTrace.append("tier2b: extraction failed, \(error.localizedDescription)")
            }
        } else {
            lastTrace.append("tier2b: language model unavailable, skipped")
        }

        // ---- Combine ----------------------------------------------------
        if let combined = combine(core: corePrediction,
                                  coreVerdict: coreVerdict,
                                  extraction: extraction) {
            return combined
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
        // don't crop again, because that would throw away the framing the user chose.
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
        // Vision confuses spiders with insects constantly: small dark body,
        // many legs, similar context. If "insect" scores 0.25 and "spider"
        // scores 0.20, first-match-wins sends it down the insect path and the
        // hazard classifier never runs. After the model is trained, that means
        // a widow gets reported as "Insect: most are harmless."
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

    // MARK: - Combining the two tier 2 signals

    /// Decides what to report given a Core ML prediction, its gate verdict,
    /// and whatever markings the language model claimed to see.
    ///
    /// THE RULE THAT MATTERS: features can escalate, never downgrade. If Core
    /// ML says cellar spider and the markings show an hourglass, the answer
    /// is widow. If Core ML says widow and no markings are visible, the
    /// answer is still widow. Nothing here can turn a dangerous call into a
    /// safe one, because a photo failing to show a marking is not evidence
    /// the marking is absent.
    ///
    /// Returns nil when neither signal is strong enough, so the caller falls
    /// through to the refusal.
    private func combine(
        core: HazardPrediction?,
        coreVerdict: ConfidenceGate.Verdict,
        extraction: ExtractionResult?
    ) -> Assessment? {

        let featureClass = extraction?.verdict.indicatedClass
        let featureStrength = extraction?.verdict.strength ?? .none
        let features = extraction?.report.visibleFeatures ?? []

        // A diagnostic marking outranks everything. The ventral hourglass and
        // the six eye arrangement are close to definitive, and a classifier
        // with 66.5% widow recall measured on holdout should not be allowed to overrule one.
        if featureStrength == .diagnostic,
           let fc = featureClass,
           fc.isMedicallySignificant {
            lastTrace.append("combine: diagnostic marking, features lead")
            var result = featureLedAssessment(fc, extraction: extraction, corroboratedBy: core)
            if let core, core.spiderClass != fc {
                result.disagreementNote = "The photo classifier suggested \(core.spiderClass.displayName.lowercased()), but a marking associated with \(fc.displayName.lowercased()) is visible. Treating it as the more dangerous of the two."
            }
            return result
        }

        // Features escalate a benign Core ML call toward a dangerous group.
        if let core, let fc = featureClass,
           fc.isMedicallySignificant, !core.spiderClass.isMedicallySignificant {
            lastTrace.append("combine: features escalate over benign Core ML call")
            var result = featureLedAssessment(fc, extraction: extraction, corroboratedBy: core)
            result.disagreementNote = "The photo classifier suggested \(core.spiderClass.displayName.lowercased()). Markings consistent with \(fc.displayName.lowercased()) are also visible, so this is being treated as the more dangerous possibility."
            return result
        }

        guard let core else {
            // No Core ML result. Features alone are enough only when the
            // marking is diagnostic, which was handled above.
            return nil
        }

        // Both point the same way. This is the case where confidence is
        // actually earned rather than asserted, so it gets its own tier label.
        if let fc = featureClass, fc == core.spiderClass {
            lastTrace.append("combine: agreement")
            var result = assessment(from: core, asWarning: false)
            result = withFeatures(result, features, tier: .corroborated)
            return result
        }

        // No feature signal. Fall back to the gate's own verdict on Core ML.
        switch coreVerdict {
        case .accept:
            return withFeatures(assessment(from: core, asWarning: false), features, tier: .hazard)
        case .acceptAsWarning:
            return withFeatures(assessment(from: core, asWarning: true), features, tier: .hazard)
        case .escalate:
            return nil
        }
    }

    private func featureLedAssessment(
        _ sc: SpiderClass,
        extraction: ExtractionResult?,
        corroboratedBy core: HazardPrediction?
    ) -> Assessment {
        let features = extraction?.report.visibleFeatures ?? []
        let supporting = extraction?.verdict.supportingFeatures ?? []

        var notes = supporting.map { "Visible: \($0.userFacingDescription.lowercased())." }
        notes += sc.fieldNotes

        var result = Assessment(
            headline: sc.displayName,
            group: sc.genus,
            hazard: sc.hazard,
            hazardNote: sc.hazardNote,
            // Rule strength, not a model confidence. Deliberately not a
            // number the language model produced.
            confidence: extraction?.verdict.strength == .diagnostic ? 0.9 : 0.6,
            tier: core != nil ? .corroborated : .features,
            ruledOut: [],
            fieldNotes: notes,
            nextStep: sc.nextStep,
            rawLabel: supporting.map(\.rawValue).joined(separator: "+"),
            categoryKey: "spider"
        )
        result.observedFeatures = features
        return result
    }

    private func withFeatures(_ base: Assessment, _ features: [DiagnosticFeature], tier: ResolutionTier) -> Assessment {
        var copy = base
        copy.observedFeatures = features
        copy.tier = tier
        return copy
    }

    // MARK: - Plant tier

    /// Returns nil when the plant model is absent or produced nothing useful,
    /// so the caller can fall back to catalog level guidance.
    private func plantTier(_ image: UIImage, coarse: Coarse) async throws -> Assessment? {
        guard await plantClassifier.isAvailable else {
            lastTrace.append("tier2 plant: no model in bundle, skipped")
            return nil
        }

        guard let prediction = try await plantClassifier.classify(image) else {
            lastTrace.append("tier2 plant: no usable prediction")
            return nil
        }

        lastTrace.append("tier2 plant: \(prediction.rawLabel) @ \(pct(prediction.confidence))")

        let pc = prediction.plantClass

        // A notKnownToxic result is NOT a clean bill of health, and the app
        // must not present it as one. Hand it back as nil so the catalog's
        // ordinary plant guidance shows instead, which already says appearance
        // alone does not establish toxicity. Claiming "we checked and it is
        // fine" would be the single worst thing this feature could say.
        guard pc != .notKnownToxic else {
            lastTrace.append("tier2 plant: no toxic match, deferring to catalog")
            return nil
        }

        var notes = pc.fieldNotes
        if let steps = pc.contactSteps {
            notes = steps + notes
        }

        return Assessment(
            headline: pc.displayName,
            group: pc.scientificName.isEmpty ? "Plant" : "Plant, \(pc.scientificName)",
            hazard: pc.hazard,
            hazardNote: pc.hazardNote,
            confidence: prediction.confidence,
            tier: .hazard,
            ruledOut: [],
            fieldNotes: notes,
            nextStep: pc.nextStep,
            rawLabel: prediction.rawLabel,
            categoryKey: coarse.entry.id,
            plantClass: pc
        )
    }

    // MARK: - Debug

    /// Vision's full ranked label list, unfiltered by the catalog.
    /// Development tool: this is how you find labels your matchTerms miss.
    func rawLabels(_ image: UIImage, limit: Int = 20) async throws -> [RankedLabel] {
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = ClassifyImageRequest()
        request.cropAndScaleAction = .scaleToFit
        let observations = try await request.perform(on: cgImage)

        return observations.prefix(limit).map {
            RankedLabel(identifier: $0.identifier, confidence: Double($0.confidence))
        }
    }

    // MARK: - Building assessments

    private func assessment(from prediction: HazardPrediction, asWarning: Bool) -> Assessment {
        let sc = prediction.spiderClass

        let headline = asWarning
            ? "Possibly a \(sc.displayName.lowercased())"
            : sc.displayName

        // THE CRITICAL DISTINCTION, measured rather than assumed.
        //
        // On 346 held-out real widows and recluses, a benign prediction shown
        // above the 0.86 benignFloor was wrong 2 times, 0.6%. The same
        // prediction shown above 0.38 was wrong 76 times, 22%.
        //
        // The 0.38 branch is worth keeping, because cutting it turns roughly
        // 1,100 of 1,946 predictions into refusals and an app that refuses on
        // most scans is useless in a different way. What is NOT acceptable is
        // attaching a benign hazard note to it. SpiderClass.hazardNote for a
        // huntsman says "not medically significant", and saying that on a
        // prediction that is right about a third of the time is how 22% of
        // widow holders get told to relax.
        //
        // So a low confidence benign call names the family and says nothing
        // about safety. The hazard level is forced to .caution and the note
        // carries the same non-exclusion language a refusal does.
        let isWeakBenign = asWarning && !sc.isMedicallySignificant

        let note: String
        if isWeakBenign {
            note = "The shape is consistent with a \(sc.displayName.lowercased()), but the evidence is weak and this is NOT ruling out a widow or recluse. Don't handle it."
        } else if asWarning {
            note = "Evidence is weak, but consistent with a \(sc.displayName.lowercased()). Treat it as one until you know otherwise. \(sc.hazardNote)"
        } else {
            note = sc.hazardNote
        }

        // A weak benign call must never present as safe, whatever the class
        // would normally report.
        let hazard = isWeakBenign ? Hazard.caution : sc.hazard

        // Retake guidance rather than "leave it be, it's doing pest control
        // for you", which is a safety claim in disguise.
        let notes = isWeakBenign
            ? ["Retake from directly above with the whole spider in the square.",
               "A shot of the underside of the abdomen is the single most useful angle.",
               "Steady light beats bright light. Flash washes out the markings that matter."]
            : sc.fieldNotes

        let next = isWeakBenign
            ? "For a confident answer, post the photo to iNaturalist or an arachnology group."
            : sc.nextStep

        return Assessment(
            headline: headline,
            group: sc.genus,
            hazard: hazard,
            hazardNote: note,
            confidence: prediction.confidence,
            tier: .hazard,
            ruledOut: ruledOutGroups(given: sc, confidence: prediction.confidence),
            fieldNotes: notes,
            nextStep: next,
            rawLabel: prediction.rawLabel,
            categoryKey: "spider"
        )
    }

    /// Always empty. Kept as a function so the call sites read explicitly
    /// rather than silently passing [].
    ///
    /// WHY THIS WAS REMOVED, September 2026:
    ///
    /// It used to return "widow and recluse ruled out" whenever a benign
    /// class cleared the confidence floor. A screen photo of an obvious black
    /// widow classified as huntsman at 86% therefore displayed an affirmative
    /// claim that it was not a widow. The exclusion was derived from the same
    /// prediction that was wrong, so it carried no independent evidence and
    /// simply amplified the error.
    ///
    /// The reasoning was unsound even when the prediction is correct. Ruling
    /// out a widow means observing the absence of a ventral hourglass, and
    /// absence cannot be established from a photo that may not show the
    /// underside. That is the same principle FeatureRules already enforces:
    /// features escalate, never downgrade.
    ///
    /// If an exclusion is ever reinstated it needs independent positive
    /// evidence of a different group, not the absence of evidence for this
    /// one, and it should never be reachable from a single classifier.
    private func ruledOutGroups(given sc: SpiderClass, confidence: Double) -> [String] {
        []
    }

    /// A weak Tier 1 result. "Insect" in large type at 16% confidence reads as
    /// an identification when it's closer to a coin flip, so we hedge the
    /// wording and keep the hazard framing conservative.
    private func uncertainCategory(_ coarse: Coarse) -> Assessment {
        let entry = coarse.entry
        return Assessment(
            headline: "Possibly \(article(for: entry.displayName)) \(entry.displayName.lowercased())",
            group: entry.group,
            hazard: entry.hazard == .safe ? .caution : entry.hazard,
            hazardNote: "Confidence is low, so treat this as a guess rather than an identification. \(entry.hazardNote)",
            confidence: coarse.confidence,
            tier: .coarse,
            ruledOut: [],
            fieldNotes: [
                "Zoom in and retake so the subject fills the square. That alone usually fixes a weak result.",
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
            headline: "Spider: group not determined",
            group: "Arachnid",
            hazard: .caution,
            hazardNote: "This is a spider, but FloraFang can't tell you which group with enough confidence to be useful. It is NOT ruling out a widow or recluse. Don't handle it.",
            // Zero on purpose. This used to carry Tier 1's Vision confidence,
            // which is how sure we are it is a spider at all, and has nothing
            // to do with why the hazard call was refused. In an export that
            // produced rows reading "0.9575, insufficient confidence", which
            // is a contradiction on its face. A refusal has no confidence to
            // report, and the trace explains what actually happened.
            confidence: 0,
            tier: .refusal,
            ruledOut: [],
            fieldNotes: [
                "Retake from directly above with the whole spider in the square.",
                "A shot of the underside of the abdomen is the single most useful angle.",
                "Steady light beats bright light. Flash washes out the markings that matter."
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
