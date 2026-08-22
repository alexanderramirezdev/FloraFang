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
    /// warning. Low on purpose: we would rather over-warn than miss.
    var dangerousFloor: Double = 0.35

    /// A benign class must clear this before we tell someone it's safe.
    /// High on purpose: "this is harmless" is a strong claim.
    var benignFloor: Double = 0.70

    /// Below this we don't trust the prediction at all and escalate.
    var escalationFloor: Double = 0.30

    /// Margin the top prediction must beat the runner-up by. Two classes at
    /// 0.45/0.44 is a coin flip dressed up as an answer.
    var minimumMargin: Double = 0.10

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
        runnerUp: Double?
    ) -> Verdict {

        let margin = runnerUp.map { top.confidence - $0 } ?? 1.0

        // Dangerous classes: surface even on weak evidence, but label it honestly.
        if top.spiderClass.isMedicallySignificant {
            if top.confidence >= benignFloor && margin >= minimumMargin {
                return .accept
            }
            if top.confidence >= dangerousFloor {
                return .acceptAsWarning
            }
            return .escalate
        }

        // Benign classes: high bar, because we're telling someone not to worry.
        if top.confidence >= benignFloor && margin >= minimumMargin {
            return .accept
        }

        if top.confidence < escalationFloor || margin < minimumMargin {
            return .escalate
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
