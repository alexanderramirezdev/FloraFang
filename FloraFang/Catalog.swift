//
//  Catalog.swift
//  FloraFang
//
//  The knowledge layer. Vision gives us a coarse label like "spider" or
//  "flower"; this file turns that label into something a person can act on.
//
//  IMPORTANT SCOPE NOTE: Apple's built-in classifier identifies *categories*,
//  not species. It can tell you "that's a spider." It cannot tell you it's a
//  black widow. Everything in here is therefore written at the category level
//  and is deliberately cautious about hazard claims.
//

import Foundation

enum Hazard: String, CaseIterable {
    case safe        // no meaningful risk from casual encounter
    case caution     // may bite/sting/irritate; some members of group are risky
    case avoid       // group contains species with medically significant risk
    case unknown     // we matched nothing useful

    var label: String {
        switch self {
        case .safe:    return "Not medically significant"
        case .caution: return "Use caution"
        case .avoid:   return "Do not handle"
        case .unknown: return "Unidentified"
        }
    }

    var symbol: String {
        switch self {
        case .safe:    return "leaf"
        case .caution: return "exclamationmark.triangle"
        case .avoid:   return "hand.raised.slash"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct CatalogEntry: Identifiable, Hashable {
    let id: String              // stable key, e.g. "spider"
    let displayName: String
    let group: String           // "Arachnid", "Flowering plant", ...
    let hazard: Hazard
    let hazardNote: String
    let fieldNotes: [String]
    let nextStep: String

    /// Lowercased substrings we look for inside Vision's label.
    let matchTerms: [String]
}

enum Catalog {

    static func entry(forKey key: String) -> CatalogEntry? {
        all.first { $0.id == key }
    }

    /// Finds the best catalog entry for a raw Vision label.
    /// Matching is substring-based because Vision emits things like
    /// "orb_weaver_spider" or "flowering_plant".
    static func match(rawLabel: String) -> CatalogEntry? {
        let needle = rawLabel
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")

        // Longest match wins, so "wolf spider" beats a bare "spider" rule.
        return all
            .compactMap { entry -> (CatalogEntry, Int)? in
                let hit = entry.matchTerms
                    .filter { needle.contains($0) }
                    .map(\.count)
                    .max()
                return hit.map { (entry, $0) }
            }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    static let unknownEntry = CatalogEntry(
        id: "unknown",
        displayName: "Not recognized",
        group: "Unassigned",
        hazard: .unknown,
        hazardNote: "FloraFang couldn't place this in a known group. Treat any unidentified animal or plant as hands-off.",
        fieldNotes: [
            "Try again with the subject filling more of the frame.",
            "Even lighting and a plain background improve results a lot.",
            "Get the distinguishing feature in shot: leaf shape, wing pattern, body markings."
        ],
        nextStep: "Save it anyway, as you can revisit the photo later.",
        matchTerms: []
    )

    static let all: [CatalogEntry] = [

        CatalogEntry(
            id: "spider",
            displayName: "Spider",
            group: "Arachnid",
            hazard: .caution,
            hazardNote: "Most spiders are harmless to people. A few groups, including widows and recluses, can cause medically significant bites. Do not handle a spider you cannot identify to species.",
            fieldNotes: [
                "Count the eyes and note the body markings; both are key to species ID.",
                "Indoor spiders are usually harmless hunters that eat other pests.",
                "Webs in low, undisturbed corners are worth a closer look before reaching in."
            ],
            nextStep: "If bitten and symptoms spread beyond the bite site, seek medical care.",
            matchTerms: ["spider", "tarantula", "arachnid"]
        ),

        CatalogEntry(
            id: "insect",
            displayName: "Insect",
            group: "Insect",
            hazard: .caution,
            hazardNote: "Varies enormously by group. Stinging insects defend nests; most others are harmless.",
            fieldNotes: [
                "Six legs and three body segments separate insects from arachnids.",
                "Wing structure and antennae shape narrow the family quickly.",
                "Note what it was on: host plant is a strong ID clue."
            ],
            nextStep: "Leave nests alone and observe from a distance.",
            matchTerms: ["insect", "beetle", "ant", "wasp", "bee", "hornet", "cricket", "grasshopper", "dragonfly", "moth"]
        ),

        CatalogEntry(
            id: "butterfly",
            displayName: "Butterfly",
            group: "Insect: Lepidoptera",
            hazard: .safe,
            hazardNote: "Harmless. Handling damages wing scales, so look but don't touch.",
            fieldNotes: [
                "Wing pattern on the underside is often more diagnostic than the top.",
                "Note the nectar plant: many species are host specific.",
                "Clubbed antennae distinguish butterflies from most moths."
            ],
            nextStep: "Photograph perched with wings both open and closed if you can.",
            matchTerms: ["butterfly"]
        ),

        CatalogEntry(
            id: "flower",
            displayName: "Flowering plant",
            group: "Plant",
            hazard: .caution,
            hazardNote: "Appearance alone doesn't establish edibility or toxicity. Never eat a plant identified only from a photo.",
            fieldNotes: [
                "Petal count and arrangement are the fastest narrowing feature.",
                "Photograph leaves and stem too, because flowers alone are often ambiguous.",
                "Note the habitat: soil, sun exposure, and what's growing nearby."
            ],
            nextStep: "Cross-check with a regional flora before acting on any ID.",
            matchTerms: ["flower", "blossom", "bloom", "petal", "wildflower", "daisy", "rose", "sunflower"]
        ),

        CatalogEntry(
            id: "plant",
            displayName: "Plant",
            group: "Plant",
            hazard: .caution,
            hazardNote: "Some common landscape and wild plants cause contact dermatitis. Treat unfamiliar foliage as look-only.",
            fieldNotes: [
                "Leaf arrangement (opposite, alternate, whorled) is a core ID key.",
                "Leaves of three is worth learning by sight in your region.",
                "Bark, buds, and growth habit matter as much as the leaf."
            ],
            nextStep: "Wash your hands if you brushed against something unfamiliar.",
            matchTerms: ["plant", "leaf", "foliage", "shrub", "tree", "fern", "grass", "succulent", "cactus"]
        ),

        CatalogEntry(
            id: "mushroom",
            displayName: "Mushroom / fungus",
            group: "Fungi",
            hazard: .avoid,
            hazardNote: "Do not eat any wild mushroom identified from an app. Several deadly species closely resemble edible ones, and photo ID is not sufficient for safety.",
            fieldNotes: [
                "Gill attachment, spore print color, and stem base are essential for real ID.",
                "Dig up the whole base: a volva at the bottom is a critical warning feature.",
                "Note the substrate: soil, hardwood, or conifer changes the likely species."
            ],
            nextStep: "For anything you intend to eat, consult a local mycological society.",
            matchTerms: ["mushroom", "fungus", "fungi", "toadstool"]
        ),

        CatalogEntry(
            id: "bird",
            displayName: "Bird",
            group: "Ave",
            hazard: .safe,
            hazardNote: "No risk from observation. Keep distance from nests, especially during breeding season.",
            fieldNotes: [
                "Silhouette, bill shape, and behavior often beat color for ID.",
                "Note the habitat and what it was doing: feeding style is diagnostic.",
                "Song is frequently the fastest identifier when the bird stays hidden."
            ],
            nextStep: "Log the location: resident vs migrant matters for ID.",
            matchTerms: ["bird", "sparrow", "finch", "hawk", "owl", "duck", "crow", "jay", "hummingbird"]
        ),

        CatalogEntry(
            id: "snake",
            displayName: "Snake",
            group: "Reptile",
            hazard: .avoid,
            hazardNote: "Do not approach or handle. Venomous and non-venomous species overlap in appearance, and most bites happen during attempts to move or kill a snake.",
            fieldNotes: [
                "Head shape is an unreliable field marker: many harmless snakes flatten their heads when threatened.",
                "Back away and give it a clear exit; snakes leave on their own.",
                "Photograph from a safe distance with zoom rather than approaching."
            ],
            nextStep: "If bitten, call emergency services immediately and keep the limb still.",
            matchTerms: ["snake", "serpent", "rattlesnake", "viper"]
        ),

        CatalogEntry(
            id: "lizard",
            displayName: "Lizard",
            group: "Reptile",
            hazard: .safe,
            hazardNote: "Nearly all lizards in North America are harmless. They may bite defensively if grabbed.",
            fieldNotes: [
                "Scale texture and tail length are useful ID features.",
                "Many species drop their tail when grabbed, which is another reason not to.",
                "Basking behavior and time of day narrow the possibilities."
            ],
            nextStep: "Observe without cornering it.",
            matchTerms: ["lizard", "gecko", "skink", "iguana"]
        ),

        CatalogEntry(
            id: "mammal",
            displayName: "Mammal",
            group: "Mammal",
            hazard: .caution,
            hazardNote: "Wild mammals can carry disease and will defend themselves. Never approach, feed, or corner one.",
            fieldNotes: [
                "Note size relative to a known object in frame.",
                "Tracks and scat nearby help confirm ID.",
                "Daytime activity in a normally nocturnal species is worth noting."
            ],
            nextStep: "Report any wild mammal behaving erratically to local animal control.",
            matchTerms: ["mammal", "squirrel", "rabbit", "deer", "fox", "coyote", "raccoon", "bat", "rodent", "mouse"]
        )
    ]
}
