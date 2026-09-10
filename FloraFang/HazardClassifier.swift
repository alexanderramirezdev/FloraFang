//
//  HazardClassifier.swift
//  FloraFang
//
//  Tier 2. Wraps your trained Core ML models.
//
//  This compiles and runs with NO models present: isAvailable and isGateAvailable
//  return false and the cascade skips past them gracefully.
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

struct GatePrediction {
    let isDangerous: Bool
    let topClass: String
    let confidence: Double
}

actor HazardClassifier {

    /// Filename (no extension) of the compiled primary model in the app bundle.
    private let modelName = "SpiderHazard"

    private var container: CoreMLModelContainer?
    private var loadAttempted = false

    // CRITICAL ARCHITECTURAL WARNING ON SPIDERHAZARDGATE.MLMODEL:
    //
    // This model is trained on a collapsed three class dataset (3,013 images:
    // widow, recluse, not_medically_significant).
    //
    // On its own, it suffers an unacceptable 14.5% false reassurance rate
    // on unseen holdout images (50 of 346 real dangerous spiders called safe).
    //
    // Therefore, this model must NEVER be used as a standalone authority or
    // primary triage gate. It is included in this bundle strictly as a
    // one direction safety veto in IdentificationCascade.
    //
    // It can only veto or escalate a benign call from SpiderHazard. It never
    // makes a positive safety assertion on its own.
    private let gateModelName = "SpiderHazardGate"
    private var gateContainer: CoreMLModelContainer?
    private var gateLoadAttempted = false

    /// True once the primary model has been found and loaded.
    var isAvailable: Bool {
        get async {
            await loadIfNeeded()
            return container != nil
        }
    }

    /// True once the gate model has been found and loaded.
    /// If absent, the cascade gracefully skips the veto check.
    var isGateAvailable: Bool {
        get async {
            await loadGateIfNeeded()
            return gateContainer != nil
        }
    }

    private func loadIfNeeded() async {
        guard !loadAttempted else { return }
        loadAttempted = true

        // Create ML output compiles to .mlmodelc when Xcode builds it.
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: modelName, withExtension: "mlmodel")
        else {
            print("[FloraFang] No \(modelName) model in bundle: Tier 2 primary disabled.")
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

    private func loadGateIfNeeded() async {
        guard !gateLoadAttempted else { return }
        gateLoadAttempted = true

        guard let url = Bundle.main.url(forResource: gateModelName, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: gateModelName, withExtension: "mlmodel")
        else {
            print("[FloraFang] No \(gateModelName) model in bundle: gate veto disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            gateContainer = try CoreMLModelContainer(model: model)
        } catch {
            print("[FloraFang] Failed to load \(gateModelName): \(error)")
        }
    }

    func classify(_ image: UIImage) async throws -> HazardPrediction? {
        await loadIfNeeded()
        guard let container else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)
        // .scaleToFill, not .scaleToFit. Create ML trains by squashing to 299x299,
        // so letterboxing at inference is a train/test mismatch.
        request.cropAndScaleAction = .scaleToFill

        let observations = try await request.perform(on: cgImage)

        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

        // Layer 2: Empirical Temperature Scaling (T = 1.53)
        // Slashed Expected Calibration Error from 0.1014 to 0.0274 on holdout.
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

        // Layer 1: Shannon Entropy Out of Distribution Filter
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

    func classifyGate(_ image: UIImage) async throws -> GatePrediction? {
        await loadGateIfNeeded()
        guard let gateContainer else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: gateContainer)
        request.cropAndScaleAction = .scaleToFill

        let observations = try await request.perform(on: cgImage)
        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

        // Empirical temperature scaling for three class gate (T = 1.86)
        let temperature: Double = 1.86
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

        let isDangerous = top.0 == "widow" || top.0 == "recluse"
        return GatePrediction(
            isDangerous: isDangerous,
            topClass: top.0,
            confidence: top.1
        )
    }
}
