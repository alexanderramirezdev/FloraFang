//
//  HazardClassifier.swift
//  Quadrat
//
//  Tier 2. Wraps your trained Core ML model.
//
//  This compiles and runs with NO model present — isAvailable returns false
//  and the cascade skips straight past it. Drop SpiderHazard.mlmodel into the
//  Xcode project and it lights up with no other code change.
//

import Foundation
import Vision
import CoreML
import UIKit

struct HazardPrediction {
    let spiderClass: SpiderClass
    let confidence: Double
    let runnerUpConfidence: Double?
    let rawLabel: String
}

actor HazardClassifier {

    /// Filename (no extension) of the compiled model in the app bundle.
    private let modelName = "SpiderHazard"

    private var container: CoreMLModelContainer?
    private var loadAttempted = false

    /// True once a model has been found and loaded.
    var isAvailable: Bool {
        get async {
            await loadIfNeeded()
            return container != nil
        }
    }

    private func loadIfNeeded() async {
        guard !loadAttempted else { return }
        loadAttempted = true

        // Create ML output compiles to .mlmodelc when Xcode builds it.
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: modelName, withExtension: "mlmodel")
        else {
            print("[Quadrat] No \(modelName) model in bundle — Tier 2 disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            // .all lets Core ML use the Neural Engine when available.
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            container = try CoreMLModelContainer(model: model)
        } catch {
            print("[Quadrat] Failed to load \(modelName): \(error)")
        }
    }

    func classify(_ image: UIImage) async throws -> HazardPrediction? {
        await loadIfNeeded()
        guard let container else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)

        // Match this to how you preprocessed training images. If you trained on
        // tight crops, .centerCrop here; if on full frames, .scaleToFit.
        // A mismatch between training and inference preprocessing is one of the
        // most common causes of "works in Create ML, fails on device."
        request.cropAndScaleAction = .centerCrop

        let observations = try await request.perform(on: cgImage)

        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard let top = classifications.first else { return nil }

        let runnerUp = classifications.dropFirst().first.map { Double($0.confidence) }

        guard let spiderClass = SpiderClass.from(label: top.identifier) else {
            print("[Quadrat] Model emitted unmapped label: \(top.identifier)")
            return nil
        }

        return HazardPrediction(
            spiderClass: spiderClass,
            confidence: Double(top.confidence),
            runnerUpConfidence: runnerUp,
            rawLabel: top.identifier
        )
    }
}
