//
//  ConfidenceGate.swift
//  FloraFang
//
//  Decides whether a model's output is trustworthy enough to show.
//
//  Two things drive this file:
//
//  1. Softmax confidence is NOT calibrated probability. A model reporting 0.85
//     is not correct 85% of the time. These thresholds are placeholders until
//     you measure them against a labeled test set (see TRAINING.md, step 8).
//
//  2. The costs are asymmetric. Missing a widow is far worse than wrongly
//     flagging a wolf spider. So dangerous classes get a LOWER bar to be
//     reported, and safe classes get a HIGHER bar. This is deliberate and
//     will feel wrong if you're used to a single global threshold.
//

import Foundation

struct ConfidenceGate {

    /// Below this, a dangerous-class prediction is still worth surfacing as a
    /// warning. With 10 classes, anything above 22% is more than 2x random chance.
    var dangerousFloor: Double = 0.22

    /// A benign class must clear this before we report an identification.
    var benignFloor: Double = 0.55

    /// Below this we don't trust the prediction at all and escalate.
    var escalationFloor: Double = 0.22

    /// Margin the top prediction must beat the runner-up by.
    var minimumMargin: Double = 0.06

    enum Verdict {
        /// Confident enough to report as-is.
        case accept
        /// Report, but frame it as a possible hazard rather than an ID.
        case acceptAsWarning
        /// Not good enough — try the next tier.
        case escalate
    }

    func evaluate(
        top: (spiderClass: SpiderClass, confidence: Double),
        runnerUp: Double?,
        isHighEntropy: Bool = false
    ) -> Verdict {

        // Layer 1 OOD filter: If the model exhibits high Shannon entropy
        // (probability spread erratically across multiple classes), escalate rather than accepting.
        if isHighEntropy {
            return .escalate
        }

        let margin = runnerUp.map { top.confidence - $0 } ?? 1.0

        // Dangerous classes (Widow, Recluse): surface even on moderate evidence
        if top.spiderClass.isMedicallySignificant {
            if top.confidence >= benignFloor && margin >= minimumMargin {
                return .accept
            }
            if top.confidence >= dangerousFloor {
                return .acceptAsWarning
            }
            return .escalate
        }

        // Benign classes:
        if top.confidence >= benignFloor && margin >= minimumMargin {
            return .accept
        }

        if top.confidence >= 0.38 && margin >= minimumMargin {
            return .acceptAsWarning
        }

        return .escalate
    }

    /// Thresholds you've actually measured. Swap this in after calibration
    /// and delete the defaults above.
    static var calibrated: ConfidenceGate {
        // TODO: replace with values from your validation sweep.
        ConfidenceGate()
    }
}
