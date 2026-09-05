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
        guard let top = classifications.first else { return nil }

        let runnerUp = classifications.dropFirst().first.map { Double($0.confidence) }

        guard let plantClass = PlantClass.from(label: top.identifier) else {
            print("[FloraFang] Plant model emitted unmapped label: \(top.identifier)")
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
        // Threshold is a placeholder until calibrated. Same caveat as
        // ConfidenceGate: softmax confidence is not probability.
        let namingFloor = 0.45
        if plantClass != .notKnownToxic && Double(top.confidence) < namingFloor {
            return PlantPrediction(
                plantClass: .notKnownToxic,
                confidence: Double(top.confidence),
                runnerUpConfidence: runnerUp,
                rawLabel: top.identifier
            )
        }

        return PlantPrediction(
            plantClass: plantClass,
            confidence: Double(top.confidence),
            runnerUpConfidence: runnerUp,
            rawLabel: top.identifier
        )
    }
}
