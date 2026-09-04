//
//  HazardClassifier.swift
//  FloraFang
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
    let entropy: Double
    let isHighEntropy: Bool
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
            print("[FloraFang] No \(modelName) model in bundle — Tier 2 disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            // .all lets Core ML use the Neural Engine when available.
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            container = try CoreMLModelContainer(model: model)
        } catch {
            print("[FloraFang] Failed to load \(modelName): \(error)")
        }
    }

    func classify(_ image: UIImage) async throws -> HazardPrediction? {
        await loadIfNeeded()
        guard let container else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)
        request.cropAndScaleAction = .scaleToFit

        let observations = try await request.perform(on: cgImage)

        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

        // Layer 2: Empirical Temperature Scaling (T = 1.53)
        // Fitted via grid-search NLL minimization on 1,946 unseen held-out iNaturalist images.
        // Slashed Expected Calibration Error (ECE) from 0.1014 to 0.0274 (73% error reduction).
        let temperature: Double = 1.53
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

        // Layer 1: Shannon Entropy Out-of-Distribution (OOD) Filter
        // Max entropy for 10 classes is log2(10) ≈ 3.32.
        // Catches diffuse, scattered distributions (e.g. computer screen moiré, blurry noise)
        // where the model is confused across multiple classes. Note: does not catch sharp,
        // overconfident wrong peaks; those are defended by Layers 2, 3, and 4.
        var entropy: Double = 0.0
        for (_, p) in calibrated where p > 1e-6 {
            entropy -= p * (log(p) / log(2.0))
        }
        let isHighEntropy = entropy > 2.35 && top.1 < 0.55

        guard let spiderClass = SpiderClass.from(label: top.0) else {
            print("[FloraFang] Model emitted unmapped label: \(top.0)")
            return nil
        }

        return HazardPrediction(
            spiderClass: spiderClass,
            confidence: top.1,
            runnerUpConfidence: runnerUp,
            rawLabel: top.0,
            entropy: entropy,
            isHighEntropy: isHighEntropy
        )
    }
}
