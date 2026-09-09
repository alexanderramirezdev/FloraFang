//
//  HazardClassifier.swift
//  FloraFang
//
//  Tier 2. Wraps your trained Core ML model.
//
//  This compiles and runs with NO model present: isAvailable returns false
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

    /// Candidate filenames for the primary 3 class hazard model in the app bundle.
    private let hazardModelNames = ["SpiderHazard-training dangerous", "SpiderHazard"]

    /// Candidate filenames for the secondary 10 class family model in the app bundle.
    private let familyModelNames = ["SpiderHazard-tier2c", "SpiderFamily"]

    private var hazardContainer: CoreMLModelContainer?
    private var familyContainer: CoreMLModelContainer?
    private var hazardLoadAttempted = false
    private var familyLoadAttempted = false

    /// True once the primary hazard model has been found and loaded.
    var isAvailable: Bool {
        get async {
            await loadHazardIfNeeded()
            return hazardContainer != nil
        }
    }

    /// True once the secondary family model has been found and loaded.
    var isFamilyAvailable: Bool {
        get async {
            await loadFamilyIfNeeded()
            return familyContainer != nil
        }
    }

    private func loadHazardIfNeeded() async {
        guard !hazardLoadAttempted else { return }
        hazardLoadAttempted = true

        var foundUrl: URL?
        for name in hazardModelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                      ?? Bundle.main.url(forResource: name, withExtension: "mlmodel") {
                foundUrl = url
                break
            }
        }

        guard let url = foundUrl else {
            print("[FloraFang] No hazard model in bundle: Tier 2 hazard screener disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            hazardContainer = try CoreMLModelContainer(model: model)
        } catch {
            print("[FloraFang] Failed to load hazard model: \(error)")
        }
    }

    private func loadFamilyIfNeeded() async {
        guard !familyLoadAttempted else { return }
        familyLoadAttempted = true

        var foundUrl: URL?
        for name in familyModelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                      ?? Bundle.main.url(forResource: name, withExtension: "mlmodel") {
                foundUrl = url
                break
            }
        }

        guard let url = foundUrl else {
            print("[FloraFang] No family model in bundle: Tier 2c family resolver disabled.")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: config)
            familyContainer = try CoreMLModelContainer(model: model)
        } catch {
            print("[FloraFang] Failed to load family model: \(error)")
        }
    }

    /// Primary screening: 3 class hazard model (widow, recluse, not_medically_significant).
    func classify(_ image: UIImage) async throws -> HazardPrediction? {
        await loadHazardIfNeeded()
        guard let container = hazardContainer else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)
        request.cropAndScaleAction = .scaleToFill

        let observations = try await request.perform(on: cgImage)
        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

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

    /// Tier 2c: 10 class family resolver for benign spiders.
    func classifyFamily(_ image: UIImage) async throws -> HazardPrediction? {
        await loadFamilyIfNeeded()
        guard let container = familyContainer else { return nil }
        guard let cgImage = image.cgImage else { throw IdentificationError.badImage }

        var request = CoreMLRequest(model: container)
        request.cropAndScaleAction = .scaleToFill

        let observations = try await request.perform(on: cgImage)
        let classifications = observations.compactMap { $0 as? ClassificationObservation }
        guard !classifications.isEmpty else { return nil }

        let temperature: Double = 1.53
        var powered: [(identifier: String, prob: Double)] = []
        var sum: Double = 0.0

        for obs in classifications {
            let raw = max(Double(obs.confidence), 1e-6)
            let scaled = pow(raw, 1.0 / temperature)
            powered.append((identifier: obs.identifier, prob: scaled))
            sum += scaled
        }

        let calibrated: [(identifier: String, prob: Double)] = powered.map {
            (identifier: $0.identifier, prob: $0.prob / max(sum, 1e-6))
        }.sorted { $0.prob > $1.prob }

        let topCandidate = calibrated.first
        let topIsDangerous = topCandidate.flatMap { SpiderClass.from(label: $0.identifier)?.isMedicallySignificant } ?? false
        let topConfidence = topCandidate?.prob ?? 0.0

        // In Tier 2c, we are resolving harmless families after Tier 2a cleared the spider.
        // If the model has extreme conviction (>= 0.85) on danger, preserve it as a safety backup.
        // Otherwise, filter to harmless classes to eliminate 10 class false alarms.
        let finalPool: [(identifier: String, prob: Double)]
        if topIsDangerous && topConfidence >= 0.85 {
            finalPool = calibrated
        } else {
            let benign = calibrated.filter {
                guard let sc = SpiderClass.from(label: $0.identifier) else { return false }
                return !sc.isMedicallySignificant
            }
            if benign.isEmpty {
                finalPool = calibrated
            } else {
                let benignSum = benign.reduce(0.0) { $0 + $1.prob }
                finalPool = benign.map { (identifier: $0.identifier, prob: $0.prob / max(benignSum, 1e-6)) }
            }
        }

        guard let top = finalPool.first else { return nil }
        let runnerUp = finalPool.dropFirst().first.map { $0.prob }

        var entropy: Double = 0.0
        for item in finalPool where item.prob > 1e-6 {
            entropy -= item.prob * (log(item.prob) / log(2.0))
        }
        let isHighEntropy = entropy > 2.35 && top.prob < 0.55

        guard let spiderClass = SpiderClass.from(label: top.identifier) else {
            print("[FloraFang] Family model emitted unmapped label: \(top.identifier)")
            return nil
        }

        return HazardPrediction(
            spiderClass: spiderClass,
            confidence: top.prob,
            runnerUpConfidence: runnerUp,
            rawLabel: top.identifier,
            entropy: entropy,
            isHighEntropy: isHighEntropy
        )
    }
}
