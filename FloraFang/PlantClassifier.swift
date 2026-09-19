//
//  PlantClassifier.swift
//  FloraFang
//
//  Wraps the plant toxicity Core ML model. Same shape as HazardClassifier,
//  same graceful degradation: with no model in the bundle, isAvailable is
//  false and callers fall through.
//
//  Drop PlantHazard.mlmodel into the Xcode project and this lights up with
//  no other code change.
//

import Foundation
import Vision
import CoreML
import UIKit

struct PlantPrediction {
    let plantClass: PlantClass
    let confidence: Double
    let runnerUpConfidence: Double?
    let rawLabel: String
}

actor PlantClassifier {

    private let modelName = "PlantHazard"

    private var container: CoreMLModelContainer?
    private var loadAttempted = false

    var isAvailable: Bool {
        get async {
            await loadIfNeeded()
            return container != nil
        }
    }

    private func loadIfNeeded() async {
        guard !loadAttempted else { return }
        loadAttempted = true

        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: modelName, withExtension: "mlmodel")
        else {
            print("[FloraFang] No \(modelName) model in bundle: plant classification disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            container = try CoreMLModelContainer(model: model)
        } catch {
            print("[FloraFang] Failed to load \(modelName): \(error)")
        }
    }

    func classify(_ image: UIImage) async throws -> PlantPrediction? {
        await loadIfNeeded()
        guard let container else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)
        request.cropAndScaleAction = .centerCrop

        let observations = try await request.perform(on: cgImage)
        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

        // Temperature scaling (T = 1.62), same closed-form trick as
        // HazardClassifier: p_i^(1/T) renormalized is exactly softmax(z_i/T)
        // when all you have is final probabilities, not logits. Matches
        // HazardClassifier's pattern so this model's on-device confidence is
        // calibrated the same way the spider one already is, rather than
        // reading raw, overconfident softmax straight off Core ML. Fitted
        // against a 1,711-image leakage-protected holdout
        // (fetch_holdout.py + calibrate_plants.py, 2026-09-18): cut Expected
        // Calibration Error from 0.095 to 0.019.
        let temperature: Double = 1.62
        var powered: [(identifier: String, prob: Double)] = []
        var sum: Double = 0.0

        for obs in classifications {
            let raw = max(Double(obs.confidence), 1e-6)
            let scaled = pow(raw, 1.0 / temperature)
            powered.append((obs.identifier, scaled))
            sum += scaled
        }

        let calibrated = powered.map { ($0.identifier, $0.prob / max(sum, 1e-6)) }
            .sorted { $0.1 > $1.1 }

        guard let top = calibrated.first else { return nil }
        let runnerUp = calibrated.dropFirst().first.map { $0.1 }

        guard let plantClass = PlantClass.from(label: top.0) else {
            print("[FloraFang] Plant model emitted unmapped label: \(top.0)")
            return nil
        }

        // ASYMMETRIC GATE, and it leans the opposite way from the spider one.
        //
        // On the spider side a weak benign call gets suppressed. Here there is
        // no benign call to make at all: notKnownToxic is not "safe", it is
        // "we found nothing", and the UI says so. So the only thing worth
        // gating is whether a TOXIC match is strong enough to name a species
        // to a vet. Too low and we send someone down a wrong path, which
        // wastes time in an emergency.
        //
        // Calibrated against the same 1,711-image holdout as the temperature
        // above, measured on THIS calibrated confidence (not raw), since that
        // is what is compared below. At the old placeholder (0.45, which was
        // also measured in the wrong space, raw not calibrated): named-species
        // accuracy was materially below the 95% bar. At 0.82: named-species
        // accuracy clears 95%, toxic recall on named calls is 58.0%. This is
        // a real precision/recall trade, not a strict improvement -- see
        // calibration-plants-predictions.csv for the full sweep before
        // changing this number again.
        //
        // Separately: the model's top-1 pick lands on some toxic class
        // (right or wrong species) for ~97% of real toxic holdout images and
        // only ~3% land on notKnownToxic. So most of what this floor
        // discards below threshold is still correctly "this is toxic," just
        // not confidently one specific species -- that signal is thrown away
        // along with the bad guess. Worth a follow-up: a middle state
        // ("likely toxic, species unclear") instead of collapsing straight
        // to notKnownToxic. Tried deriving that middle state directly from
        // this model's own output (aggregate non-benign probability mass, and
        // top-1-is-toxic-at-any-confidence) and both failed: 61.5% of real
        // benign holdout images still get a toxic species as top-1 at any
        // confidence. This model does not separate its own benign class well,
        // so a threshold on its own output cannot be the fix. Spiders protect
        // against the equivalent failure with a second, independently trained
        // gate model (SpiderHazardGate.mlmodel via classifyGate in
        // HazardClassifier), not a threshold. Plants have no equivalent
        // second model yet.
        let namingFloor = 0.82
        if plantClass != .notKnownToxic && top.1 < namingFloor {
            return PlantPrediction(
                plantClass: .notKnownToxic,
                confidence: top.1,
                runnerUpConfidence: runnerUp,
                rawLabel: top.0
            )
        }

        return PlantPrediction(
            plantClass: plantClass,
            confidence: top.1,
            runnerUpConfidence: runnerUp,
            rawLabel: top.0
        )
    }
}
