//
//  CalibrationMath.swift
//  FloraFang
//
//  Pure math shared by HazardClassifier and PlantClassifier: the empirical
//  temperature scaling correction and the Shannon entropy OOD check. Pulled
//  out on its own so the numbers behind "T = 1.53" and "H > 2.35" can be
//  unit tested directly instead of only exercised through a loaded Core ML
//  model on a real device.
//

import Foundation

enum CalibrationMath {

    /// Raises each softmax probability to 1/T and renormalizes. Mathematically
    /// identical to scaling logits by T (softmax(z/T)) when only final
    /// probabilities are available, which is all Vision/Core ML hands back.
    /// Returned in descending order of calibrated probability.
    static func temperatureScale(
        _ raw: [(identifier: String, confidence: Double)],
        temperature: Double
    ) -> [(identifier: String, probability: Double)] {
        var powered: [(identifier: String, prob: Double)] = []
        var sum: Double = 0.0

        for item in raw {
            let clamped = max(item.confidence, 1e-6)
            let scaled = pow(clamped, 1.0 / temperature)
            powered.append((item.identifier, scaled))
            sum += scaled
        }

        return powered
            .map { ($0.identifier, $0.prob / max(sum, 1e-6)) }
            .sorted { $0.1 > $1.1 }
    }

    /// Shannon entropy in bits: H = -sum(p * log2(p)). Near 0 means the
    /// distribution is confidently peaked on one class; higher means it is
    /// spread out, the signature of an out-of-distribution input.
    static func shannonEntropyBits(_ probabilities: [Double]) -> Double {
        var entropy: Double = 0.0
        for p in probabilities where p > 1e-6 {
            entropy -= p * (log(p) / log(2.0))
        }
        return entropy
    }
}
