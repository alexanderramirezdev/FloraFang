//
//  DiagnosticFeatures.swift
//  FloraFang
//
//  The closed vocabulary the language model is allowed to report, and the
//  deterministic rules that turn reported features into a hazard call.
//
//  WHY THIS SHAPE
//
//  Asking a language model "what species is this and is it dangerous" gets a
//  fluent, confident, plausible answer whether or not it knows. A @Generable
//  schema with `isMedicallySignificant: Bool` makes that worse, not better,
//  because constrained decoding guarantees a true or false on every call.
//  There is no "I cannot tell" in a Bool.
//
//  So the model is never asked what it is. It is asked which of a fixed set
//  of markings it can see. Two things follow from that:
//
//    1. It cannot invent "black widow" because black widow is not in the
//       vocabulary. It can only claim to observe a feature that exists.
//    2. A claimed feature is checkable by the user. "Red hourglass on the
//       underside" is something a person can look at and confirm. "Latrodectus
//       hesperus, 84% confidence" is not.
//
//  The mapping from features to hazard is ordinary Swift below. Same input,
//  same output, auditable, testable, and no model involved in the decision.
//

import Foundation
import FoundationModels

// MARK: - Vocabulary

/// Visible markings only. Nothing in here is a conclusion, a species, or a
/// risk level. If a case name would let the model skip the reasoning step,
/// it does not belong in this enum.
@Generable
enum DiagnosticFeature: String, CaseIterable, Codable, Sendable {

    // Widow indicators
    case redHourglassUnderside
    case redOrOrangeSpotsOnBack
    case glossyBlackRoundAbdomen

    // Recluse indicators
    case violinShapeBehindHead
    case uniformTanOrBrownBody
    case sixEyesInThreePairs

    // Common harmless groups
    case veryLongThinLegsSmallBody
    case compactFuzzyBodyTwoLargeEyes
    case flatBodyLegsAngledSideways
    case denselyHairyHeavyBody
    case stripedOrBandedLegs
    case patternedBulbousAbdomen

    // Context
    case sittingInCircularWeb
    case tangledMessyWeb
    case carryingEggSac
    case noWebVisible

    /// Shown to the user when asking them to confirm. Written as something a
    /// person can actually go and look at.
    var userFacingDescription: String {
        switch self {
        case .redHourglassUnderside:
            return "A red hourglass shape on the underside of the abdomen"
        case .redOrOrangeSpotsOnBack:
            return "Red or orange spots on the top of the abdomen"
        case .glossyBlackRoundAbdomen:
            return "A glossy black, rounded abdomen"
        case .violinShapeBehindHead:
            return "A darker violin shape on the back, just behind the head"
        case .uniformTanOrBrownBody:
            return "An evenly tan or brown body with no strong pattern"
        case .sixEyesInThreePairs:
            return "Six eyes arranged in three pairs, rather than eight"
        case .veryLongThinLegsSmallBody:
            return "Very long thin legs with a small body"
        case .compactFuzzyBodyTwoLargeEyes:
            return "A compact fuzzy body with two large forward facing eyes"
        case .flatBodyLegsAngledSideways:
            return "A flat body with legs angled out to the sides, crab like"
        case .denselyHairyHeavyBody:
            return "A large, heavily haired body"
        case .stripedOrBandedLegs:
            return "Striped or banded legs"
        case .patternedBulbousAbdomen:
            return "A large patterned abdomen"
        case .sittingInCircularWeb:
            return "Sitting in the middle of a circular web"
        case .tangledMessyWeb:
            return "An irregular, tangled web"
        case .carryingEggSac:
            return "Carrying an egg sac"
        case .noWebVisible:
            return "No web visible"
        }
    }
}

// MARK: - Model output schema

/// What the language model is allowed to return.
///
/// Note what is absent: no species, no genus, no hazard level, no confidence
/// score. Those are decisions, and decisions happen below in ordinary code.
@Generable
struct FeatureReport: Codable, Sendable {

    @Guide(description: """
    Markings you can actually see in this image. Include a feature only if it \
    is visible. Do not infer features from what the animal probably is. An \
    empty list is a correct and useful answer when the photo does not show \
    diagnostic detail.
    """)
    let visibleFeatures: [DiagnosticFeature]

    @Guide(description: """
    Parts of the animal the photo does not show, such as the underside of the \
    abdomen or the eye arrangement. This tells the user what to photograph next.
    """)
    let notVisible: [String]

    @Guide(description: """
    A plain description of what is in the image, with no identification and no \
    species name. Describe size, colour, posture, and surroundings only.
    """)
    let plainDescription: String

    @Guide(description: """
    False when the image does not clearly show an animal at all, for example \
    when it shows a leaf, a wall, a shadow, or is too blurry to tell. Answer \
    false when unsure. Reporting no animal is more useful than describing one \
    that is not there.
    """)
    let animalVisible: Bool
}

// MARK: - Deterministic rules

/// What the features imply, decided in code rather than by a model.
struct FeatureVerdict: Sendable {

    /// The group the visible features point to, when they point anywhere.
    let indicatedClass: SpiderClass?

    /// How strongly. Not a probability, a rule strength.
    let strength: Strength

    /// The features that drove this, for showing the user why.
    let supportingFeatures: [DiagnosticFeature]

    enum Strength: Sendable {
        case diagnostic   // a marking that is close to definitive on its own
        case suggestive   // consistent with, not conclusive
        case none
    }
}

enum FeatureRules {

    /// Maps observed features to an indicated group.
    ///
    /// TWO PRINCIPLES, both carried over from Haki Check:
    ///
    /// Highest hazard wins. Dangerous indicators are checked first and return
    /// immediately, so a photo showing both an hourglass and a tangled web
    /// resolves to widow rather than to some averaged answer.
    ///
    /// Features escalate, never downgrade. The absence of an hourglass is not
    /// evidence against a widow, because the photo may simply not show the
    /// underside. Nothing in here can conclude "not dangerous."
    static func evaluate(_ features: [DiagnosticFeature]) -> FeatureVerdict {
        let set = Set(features)

        // Widow. The ventral hourglass is the one marking that is close to
        // definitive on its own.
        if set.contains(.redHourglassUnderside) {
            return FeatureVerdict(
                indicatedClass: .widow,
                strength: .diagnostic,
                supportingFeatures: [.redHourglassUnderside]
            )
        }

        if set.contains(.glossyBlackRoundAbdomen) && set.contains(.redOrOrangeSpotsOnBack) {
            return FeatureVerdict(
                indicatedClass: .widow,
                strength: .suggestive,
                supportingFeatures: [.glossyBlackRoundAbdomen, .redOrOrangeSpotsOnBack]
            )
        }

        // Recluse. Six eyes in three pairs is unusual enough to be strong on
        // its own, since most spiders have eight.
        if set.contains(.sixEyesInThreePairs) {
            var support: [DiagnosticFeature] = [.sixEyesInThreePairs]
            if set.contains(.violinShapeBehindHead) { support.append(.violinShapeBehindHead) }
            return FeatureVerdict(
                indicatedClass: .recluse,
                strength: .diagnostic,
                supportingFeatures: support
            )
        }

        if set.contains(.violinShapeBehindHead) && set.contains(.uniformTanOrBrownBody) {
            return FeatureVerdict(
                indicatedClass: .recluse,
                strength: .suggestive,
                supportingFeatures: [.violinShapeBehindHead, .uniformTanOrBrownBody]
            )
        }

        // A glossy black rounded abdomen alone is worth flagging as possible
        // widow rather than ignoring, since the underside is frequently not
        // visible in a photo taken from above.
        if set.contains(.glossyBlackRoundAbdomen) {
            return FeatureVerdict(
                indicatedClass: .widow,
                strength: .suggestive,
                supportingFeatures: [.glossyBlackRoundAbdomen]
            )
        }

        // Benign groups. These produce an indicated class but never a claim
        // of safety, because the caller treats benign feature matches as
        // corroboration only.
        if set.contains(.compactFuzzyBodyTwoLargeEyes) {
            return FeatureVerdict(
                indicatedClass: .jumpingSpider,
                strength: .suggestive,
                supportingFeatures: [.compactFuzzyBodyTwoLargeEyes]
            )
        }

        if set.contains(.veryLongThinLegsSmallBody) {
            var support: [DiagnosticFeature] = [.veryLongThinLegsSmallBody]
            if set.contains(.tangledMessyWeb) { support.append(.tangledMessyWeb) }
            return FeatureVerdict(
                indicatedClass: .cellarSpider,
                strength: .suggestive,
                supportingFeatures: support
            )
        }

        if set.contains(.sittingInCircularWeb) || set.contains(.patternedBulbousAbdomen) {
            return FeatureVerdict(
                indicatedClass: .orbWeaver,
                strength: .suggestive,
                supportingFeatures: features.filter {
                    $0 == .sittingInCircularWeb || $0 == .patternedBulbousAbdomen
                }
            )
        }

        if set.contains(.flatBodyLegsAngledSideways) {
            return FeatureVerdict(
                indicatedClass: .huntsman,
                strength: .suggestive,
                supportingFeatures: [.flatBodyLegsAngledSideways]
            )
        }

        if set.contains(.denselyHairyHeavyBody) {
            return FeatureVerdict(
                indicatedClass: .tarantula,
                strength: .suggestive,
                supportingFeatures: [.denselyHairyHeavyBody]
            )
        }

        if set.contains(.carryingEggSac) && set.contains(.noWebVisible) {
            return FeatureVerdict(
                indicatedClass: .wolfSpider,
                strength: .suggestive,
                supportingFeatures: [.carryingEggSac, .noWebVisible]
            )
        }

        return FeatureVerdict(indicatedClass: nil, strength: .none, supportingFeatures: [])
    }

    /// What to tell the user to photograph next, given what was not visible.
    static func retakeAdvice(notVisible: [String], indicated: SpiderClass?) -> [String] {
        var advice: [String] = []

        switch indicated {
        case .widow:
            advice.append("The underside of the abdomen is the deciding view. Photograph from below if you can do it without getting close.")
        case .recluse:
            advice.append("The back just behind the head shows the violin marking. Photograph from directly above.")
        default:
            advice.append("A shot from directly above with the whole body in frame is the most useful angle.")
        }

        if !notVisible.isEmpty {
            advice.append("Not visible in this photo: " + notVisible.joined(separator: ", ") + ".")
        }

        advice.append("Use zoom rather than moving closer. The lens cannot focus below about ten centimetres.")
        return advice
    }
}
