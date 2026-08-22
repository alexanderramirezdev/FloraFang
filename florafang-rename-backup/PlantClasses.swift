//
//  PlantClasses.swift
//  Quadrat
//
//  The label space for the plant toxicity model. These strings must match
//  your Create ML folder names EXACTLY.
//
//  SCOPE, DELIBERATELY NARROW:
//  This is not a plant identifier. It answers one question, "is this a plant
//  known to hurt you," and it answers it for a short list of notorious
//  species. Everything else is notKnownToxic, which is NOT the same as safe.
//
//  THE APP NEVER MAKES AN EDIBILITY CLAIM. Not at any confidence. Ruling out
//  a specific known toxic species is a supportable claim. "You can eat this"
//  is not, and a phone camera is the wrong instrument for that question.
//

import Foundation

/// How a plant hurts you. Drives which guidance the app shows.
///
/// nonisolated for the same reason PlantClass is: PlantClass compares these
/// (`route == .contact`) from nonisolated code, and the synthesized Equatable
/// conformance would otherwise be main actor isolated.
nonisolated enum ExposureRoute {
    case contact      // skin reaction, no ingestion required
    case ingestion    // only dangerous if eaten
    case both

    var label: String {
        switch self {
        case .contact:   return "Skin contact"
        case .ingestion: return "If eaten"
        case .both:      return "Contact and ingestion"
        }
    }
}

/// nonisolated because PlantClassifier is an actor and reads these off the
/// main actor. Under Swift 6 default main actor isolation every type is
/// implicitly @MainActor, which makes that a hard error. This enum is pure
/// static data with no shared mutable state, so opting the whole type out is
/// both safe and simpler than annotating each member.
nonisolated enum PlantClass: String, CaseIterable {

    // Contact toxicity. The outdoor case.
    case poisonIvyOak
    case poisonSumac
    case stingingNettle
    case giantHogweed

    // Notorious ingestion. The "someone ate this" case.
    case oleander
    case sagoPalm
    case foxglove
    case datura
    case lily
    case castorBean

    // The negative class. Large and deliberately unreassuring.
    case notKnownToxic

    /// Folder name in your training data directory.
    var trainingLabel: String {
        switch self {
        case .poisonIvyOak:   return "poison_ivy_oak"
        case .poisonSumac:    return "poison_sumac"
        case .stingingNettle: return "stinging_nettle"
        case .giantHogweed:   return "giant_hogweed"
        case .oleander:       return "oleander"
        case .sagoPalm:       return "sago_palm"
        case .foxglove:       return "foxglove"
        case .datura:         return "datura"
        case .lily:           return "lily"
        case .castorBean:     return "castor_bean"
        case .notKnownToxic:  return "not_known_toxic"
        }
    }

    static func from(label: String) -> PlantClass? {
        allCases.first { $0.trainingLabel == label.lowercased() }
    }

    var displayName: String {
        switch self {
        case .poisonIvyOak:   return "Poison ivy or poison oak"
        case .poisonSumac:    return "Poison sumac"
        case .stingingNettle: return "Stinging nettle"
        case .giantHogweed:   return "Giant hogweed"
        case .oleander:       return "Oleander"
        case .sagoPalm:       return "Sago palm"
        case .foxglove:       return "Foxglove"
        case .datura:         return "Datura"
        case .lily:           return "Lily"
        case .castorBean:     return "Castor bean"
        case .notKnownToxic:  return "Not a plant we recognize as toxic"
        }
    }

    var scientificName: String {
        switch self {
        case .poisonIvyOak:   return "Toxicodendron radicans / diversilobum"
        case .poisonSumac:    return "Toxicodendron vernix"
        case .stingingNettle: return "Urtica dioica"
        case .giantHogweed:   return "Heracleum mantegazzianum"
        case .oleander:       return "Nerium oleander"
        case .sagoPalm:       return "Cycas revoluta"
        case .foxglove:       return "Digitalis purpurea"
        case .datura:         return "Datura species"
        case .lily:           return "Lilium / Hemerocallis"
        case .castorBean:     return "Ricinus communis"
        case .notKnownToxic:  return ""
        }
    }

    var route: ExposureRoute {
        switch self {
        case .poisonIvyOak, .poisonSumac, .stingingNettle, .giantHogweed:
            return .contact
        case .oleander, .sagoPalm, .foxglove, .datura, .lily, .castorBean:
            return .ingestion
        case .notKnownToxic:
            return .both
        }
    }

    /// True where eating even a small amount is a medical emergency.
    /// Drives the hardest warning language in the app.
    var isSevereIfEaten: Bool {
        switch self {
        case .oleander, .sagoPalm, .foxglove, .datura, .castorBean, .lily:
            return true
        default:
            return false
        }
    }

    /// Species specific pet danger worth calling out separately, because pet
    /// owners often do not know these and the outcomes are severe.
    var petNote: String? {
        switch self {
        case .sagoPalm:
            return "Sago palm is one of the most dangerous plants for dogs. Every part is toxic and the seeds are the worst. Liver failure can follow. This is an emergency."
        case .lily:
            return "True lilies cause kidney failure in cats. Even pollen or vase water can be enough. This is an emergency for a cat."
        case .oleander:
            return "Oleander affects the heart in dogs, cats, and horses. Small amounts matter."
        case .castorBean:
            return "Castor bean seeds are severely toxic to dogs. A single chewed seed can be enough."
        case .foxglove:
            return "Foxglove affects the heart in dogs and cats."
        case .datura:
            return "Datura causes severe neurological effects in dogs and cats."
        default:
            return nil
        }
    }

    var hazard: Hazard {
        switch self {
        case .notKnownToxic:
            // Never .safe. The model recognizing nothing is not evidence of
            // safety, and a green checkmark here would be a lie.
            return .caution
        case .stingingNettle:
            return .caution
        default:
            return .avoid
        }
    }

    var hazardNote: String {
        switch self {
        case .poisonIvyOak:
            return "Contact with any part of this plant can cause an itching, blistering rash that may appear hours to days later. The oil sticks to skin, clothing, tools, and pet fur, and it spreads from those surfaces."
        case .poisonSumac:
            return "Same rash causing oil as poison ivy, often described as more severe. Grows in wet ground and swampy areas. Do not burn it. Inhaling the smoke can injure the lungs."
        case .stingingNettle:
            return "Fine hairs inject an irritant on contact. Painful stinging and welts that usually fade within a day. Not dangerous to most people, but unpleasant."
        case .giantHogweed:
            return "Sap plus sunlight causes severe burns and blistering that can scar. Keep the area covered and out of sun, wash immediately, and do not touch this plant."
        case .oleander:
            return "Every part of this plant is toxic if eaten, including dried leaves and smoke from burning it. Affects the heart. Do not eat, do not burn, keep away from children and animals."
        case .sagoPalm:
            return "Every part is toxic if eaten and the seeds are the most dangerous. Causes liver failure. Common as landscaping and as a houseplant, which is how most exposures happen."
        case .foxglove:
            return "Contains compounds that affect heart rhythm. Toxic if eaten, including the leaves, flowers, and seeds. Has been mistaken for edible plants."
        case .datura:
            return "All parts are toxic if eaten, especially seeds. Causes severe confusion, hallucination, and dangerous heart effects. Common in the Southwest along roadsides and disturbed ground."
        case .lily:
            return "Dangerous if eaten. The critical risk is to cats, where even small exposures cause kidney failure."
        case .castorBean:
            return "Seeds contain ricin and are severely toxic if chewed and swallowed. A very small number of seeds can be lethal."
        case .notKnownToxic:
            return "This does not match any plant on Quadrat's toxic list. That is not the same as safe. Quadrat only recognizes a short list of notorious species, and most toxic plants are not on it. Do not eat it and do not assume it is harmless."
        }
    }

    /// Shown for contact exposures. Nil where the class is ingestion only.
    var contactSteps: [String]? {
        switch self {
        case .poisonIvyOak, .poisonSumac:
            return [
                "Wash the skin with soap and cool water as soon as possible. Warm water spreads the oil.",
                "Wash clothing, tools, and anything else that touched the plant. The oil stays active on surfaces.",
                "Do not scratch. The rash does not spread from scratching, but broken skin can get infected.",
                "See a doctor for a rash on the face or genitals, a widespread rash, or any trouble breathing."
            ]
        case .stingingNettle:
            return [
                "Rinse the area with cool water. Avoid rubbing, which pushes the hairs in further.",
                "Tape lifted gently off the skin can remove remaining hairs.",
                "Symptoms usually fade within a day. See a doctor if they do not."
            ]
        case .giantHogweed:
            return [
                "Wash with soap and water immediately and keep the area out of sunlight.",
                "Cover the skin and keep it covered for at least 48 hours.",
                "See a doctor. Burns from this plant can be severe and can scar.",
                "Get medical care immediately if sap contacted the eyes."
            ]
        default:
            return nil
        }
    }

    var fieldNotes: [String] {
        switch self {
        case .poisonIvyOak:
            return [
                "Three leaflets on each stem. The old line about leaves of three is the reliable one.",
                "Grows as a vine, a low plant, or a shrub depending on conditions.",
                "Leaf edges vary from smooth to notched, and color shifts red in fall."
            ]
        case .poisonSumac:
            return [
                "Seven to thirteen leaflets in pairs along a reddish stem, not three.",
                "Grows in standing water and swampy ground, unlike poison ivy.",
                "Often mistaken for harmless sumacs. Habitat is the strongest clue."
            ]
        case .stingingNettle:
            return [
                "Square stems and toothed leaves, both covered in fine hairs.",
                "Grows in disturbed soil, along trails, and near water.",
                "Often found in large patches rather than as a single plant."
            ]
        case .giantHogweed:
            return [
                "Very large, often above head height, with a thick blotchy purple stem.",
                "Umbrella shaped clusters of white flowers.",
                "Report sightings to your state agriculture office. It is a regulated invasive species in many places."
            ]
        case .oleander:
            return [
                "Evergreen shrub with narrow leathery leaves and clustered pink, white, or red flowers.",
                "Very common as roadside and highway landscaping in the Southwest.",
                "Do not use the branches as skewers or firewood."
            ]
        case .sagoPalm:
            return [
                "Not a true palm. Stiff feather like fronds emerging from a thick low trunk.",
                "Sold widely as a landscape and container plant.",
                "The orange seeds at the base are the most dangerous part and are the right size for a dog to chew."
            ]
        case .foxglove:
            return [
                "Tall spike of drooping tubular flowers, often speckled inside.",
                "A common garden ornamental that also escapes into the wild.",
                "First year plants are a low rosette of leaves with no flower spike."
            ]
        case .datura:
            return [
                "Large white or purple trumpet shaped flowers that open in the evening.",
                "Spiny seed pods, which is where the name thornapple comes from.",
                "Common in the Southwest on roadsides and disturbed ground."
            ]
        case .lily:
            return [
                "Large showy flowers with prominent stamens, often in bouquets.",
                "Daylilies and true lilies are both dangerous to cats.",
                "Keep cut arrangements entirely out of reach of cats."
            ]
        case .castorBean:
            return [
                "Large star shaped leaves, often with a red or bronze cast.",
                "Spiky seed pods holding mottled beanlike seeds.",
                "Grown ornamentally and also escapes into the wild."
            ]
        case .notKnownToxic:
            return [
                "Fill the frame with leaves and stem, not just the flower.",
                "A second photo showing how the plant grows helps a person identify it later.",
                "Note the habitat, since where a plant grows narrows it down fast."
            ]
        }
    }

    var nextStep: String {
        switch self {
        case .notKnownToxic:
            return "For a real identification, ask a person. Your county extension office or a local native plant society can help."
        default:
            return route == .contact
                ? "Wash exposed skin and anything the plant touched."
                : "If anyone or any animal has eaten this, call poison control now."
        }
    }
}
