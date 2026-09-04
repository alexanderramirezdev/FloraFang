//
//  SpiderClasses.swift
//  FloraFang
//
//  The label space for the hazard model. These strings must match your
//  Create ML folder names EXACTLY — the folder name becomes the class label.
//

import Foundation

/// nonisolated because HazardClassifier is an actor and reads these off the
/// main actor. Under Swift 6 default main actor isolation every type is
/// implicitly @MainActor, which makes that a hard error. Pure static data,
/// no shared mutable state, so opting the whole type out is safe.
nonisolated enum SpiderClass: String, CaseIterable {
    case widow          // Latrodectus
    case recluse        // Loxosceles
    case wolfSpider
    case orbWeaver
    case jumpingSpider
    case cellarSpider
    case huntsman
    case tarantula
    case otherSpider
    case notASpider

    /// Folder name in your training data directory.
    var trainingLabel: String {
        switch self {
        case .widow:         return "widow"
        case .recluse:       return "recluse"
        case .wolfSpider:    return "wolf_spider"
        case .orbWeaver:     return "orb_weaver"
        case .jumpingSpider: return "jumping_spider"
        case .cellarSpider:  return "cellar_spider"
        case .huntsman:      return "huntsman"
        case .tarantula:     return "tarantula"
        case .otherSpider:   return "other_spider"
        case .notASpider:    return "not_a_spider"
        }
    }

    static func from(label: String) -> SpiderClass? {
        allCases.first { $0.trainingLabel == label.lowercased() }
    }

    var displayName: String {
        switch self {
        case .widow:         return "Widow spider"
        case .recluse:       return "Recluse spider"
        case .wolfSpider:    return "Wolf spider"
        case .orbWeaver:     return "Orb weaver"
        case .jumpingSpider: return "Jumping spider"
        case .cellarSpider:  return "Cellar spider"
        case .huntsman:      return "Huntsman spider"
        case .tarantula:     return "Tarantula"
        case .otherSpider:   return "Spider"
        case .notASpider:    return "Not a spider"
        }
    }

    var genus: String {
        switch self {
        case .widow:   return "Arachnid — Latrodectus"
        case .recluse: return "Arachnid — Loxosceles"
        default:       return "Arachnid"
        }
    }

    /// The two groups with medically significant bites in North America.
    var isMedicallySignificant: Bool {
        self == .widow || self == .recluse
    }

    var hazard: Hazard {
        switch self {
        case .widow, .recluse:
            return .avoid
        case .tarantula, .huntsman, .wolfSpider, .otherSpider:
            return .caution
        case .orbWeaver, .jumpingSpider, .cellarSpider:
            return .safe
        case .notASpider:
            return .unknown
        }
    }

    var hazardNote: String {
        switch self {
        case .widow:
            return "Widow bites are medically significant. Do not handle. Symptoms can include severe muscle cramping and pain spreading from the bite site."
        case .recluse:
            return "Recluse bites can cause tissue damage that develops over days. Do not handle. Bites are often painless at first."
        case .tarantula:
            return "Not medically dangerous to healthy adults, but urticating hairs cause serious irritation, especially to eyes. Don't handle."
        case .huntsman:
            return "Large and fast, which is alarming, but not medically significant. Bites are rare and defensive. Do not handle."
        case .wolfSpider:
            return "A defensive bite is painful but not medically significant. Ground hunters, often found indoors by accident. Leave undisturbed."
        case .orbWeaver:
            return "Not medically significant. Builds the classic circular web and stays in it. Relocate gently if needed."
        case .jumpingSpider:
            return "Not medically significant. Highly curious and visually capable spiders. Bites are essentially unheard of."
        case .cellarSpider:
            return "Not medically significant. Long thin legs, tangled webs in corners and basements. Fangs rarely penetrate human skin."
        case .otherSpider:
            return "Group not determined. Most spiders are not medically significant, but treat any unidentified spider as hands-off."
        case .notASpider:
            return "This doesn't appear to be a spider."
        }
    }

    var fieldNotes: [String] {
        switch self {
        case .widow:
            return [
                "Glossy black body with a red hourglass on the underside of the abdomen.",
                "Builds messy, irregular webs low to the ground in undisturbed spaces.",
                "Common in garages, woodpiles, meter boxes, and under outdoor furniture."
            ]
        case .recluse:
            return [
                "Uniform tan body with a darker violin shape on the back near the head.",
                "Six eyes in three pairs — unusual, most spiders have eight.",
                "Hides in stored boxes, shoes, and clothing left undisturbed."
            ]
        case .wolfSpider:
            return [
                "Robust, hairy, and fast; hunts on the ground rather than in a web.",
                "Two large forward-facing eyes reflect light brightly at night.",
                "Females often carry an egg sac attached to the spinnerets."
            ]
        case .orbWeaver:
            return [
                "Sits in the center of a large circular web, often rebuilt nightly.",
                "Bulbous abdomen, frequently patterned.",
                "Webs are usually across open spans — doorways, between plants."
            ]
        case .jumpingSpider:
            return [
                "Compact, fuzzy, with two very large forward eyes.",
                "Moves in short deliberate hops and will visibly track you.",
                "Hunts in the open during daylight, no capture web."
            ]
        case .cellarSpider:
            return [
                "Very long, thin legs with a small body.",
                "Vibrates rapidly in its web when disturbed.",
                "Tangled webs in ceiling corners, basements, and garages."
            ]
        case .huntsman:
            return [
                "Large, flat-bodied, with legs angled crab-like to the sides.",
                "Moves in fast bursts across walls and ceilings.",
                "Prefers to flee; presses flat into gaps when cornered."
            ]
        case .tarantula:
            return [
                "Very large and heavily haired.",
                "Ground-dwelling; males wander in late summer looking for mates.",
                "Slow-moving compared with most spiders."
            ]
        case .otherSpider:
            return [
                "Photograph from directly above with the whole body in frame.",
                "A second shot showing the underside of the abdomen helps a lot.",
                "Include something for scale — a coin or your fingertip nearby, not touching."
            ]
        case .notASpider:
            return ["Try scanning again with the subject filling the frame."]
        }
    }

    var nextStep: String {
        switch self {
        case .widow, .recluse:
            return "If bitten, seek medical care. Bring a photo if you can do so safely."
        case .otherSpider:
            return "Post the photo to iNaturalist or a local arachnology group for a human ID."
        default:
            return "Leave it be — it's doing pest control for you."
        }
    }
}
