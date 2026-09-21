//
//  CatalogSubSpecies.swift
//  FloraFang
//
//  Species-level drill-down for a few of the general Catalog categories.
//  Apple's built-in classifier only gets you to "that's a bird" or "that's
//  a lizard," never the species — so unlike SpiderClasses.swift and
//  PlantClasses.swift, nothing here is ever the output of a live scan. This
//  is reference-only content for browsing the Full Catalog: "here's what
//  the 10 most likely candidates actually look like," for someone to
//  compare against what they saw. Lighter than a SpiderClass/PlantClass
//  entry on purpose: name, reference photo, one line. No field notes, no
//  next step, because none of these carry that kind of hazard content
//  except Gila Monster, which gets its own hazard flag for exactly that
//  reason.
//
//  Piloted with bird, mammal, and lizard. Extend byCategory with more
//  Catalog.swift category ids (matching CatalogEntry.id) if/when the rest
//  get the same treatment.
//

import Foundation

struct CatalogSubEntry: Identifiable, Hashable {
    let id: String              // stable key, e.g. "american_robin"
    let displayName: String
    let scientificName: String?
    let hazard: Hazard
    let note: String            // the one-liner
}

enum CatalogSubSpecies {

    static let byCategory: [String: [CatalogSubEntry]] = [
        "bird": [
            CatalogSubEntry(id: "american_robin", displayName: "American Robin", scientificName: "Turdus migratorius", hazard: .safe,
                note: "One of the most common lawn birds in North America. Look for the orange breast and yellow bill."),
            CatalogSubEntry(id: "northern_cardinal", displayName: "Northern Cardinal", scientificName: "Cardinalis cardinalis", hazard: .safe,
                note: "A backyard favorite. Males are solid red with a black face mask; females are warm brown."),
            CatalogSubEntry(id: "blue_jay", displayName: "Blue Jay", scientificName: "Cyanocitta cristata", hazard: .safe,
                note: "Bold and vocal, with a blue crest and white-barred wings. Known for mimicking hawk calls."),
            CatalogSubEntry(id: "mourning_dove", displayName: "Mourning Dove", scientificName: "Zenaida macroura", hazard: .safe,
                note: "A slim, soft gray-brown dove with a long pointed tail, named for its mournful cooing call."),
            CatalogSubEntry(id: "american_crow", displayName: "American Crow", scientificName: "Corvus brachyrhynchos", hazard: .safe,
                note: "All black, all-purpose. Highly intelligent and often seen in noisy family groups."),
            CatalogSubEntry(id: "red_tailed_hawk", displayName: "Red-tailed Hawk", scientificName: "Buteo jamaicensis", hazard: .safe,
                note: "The classic soaring hawk silhouette. Look for the rusty red tail from below in good light."),
            CatalogSubEntry(id: "house_finch", displayName: "House Finch", scientificName: "Haemorhous mexicanus", hazard: .safe,
                note: "Small and streaky, with reddish coloring on the head and chest of males. Common at feeders."),
            CatalogSubEntry(id: "black_capped_chickadee", displayName: "Black-capped Chickadee", scientificName: "Poecile atricapillus", hazard: .safe,
                note: "Tiny and curious, easy to recognize by its black cap and bib and its own name-like call."),
            CatalogSubEntry(id: "european_starling", displayName: "European Starling", scientificName: "Sturnus vulgaris", hazard: .safe,
                note: "Iridescent black with pale speckles in winter. Introduced to North America in the 1890s."),
            CatalogSubEntry(id: "american_goldfinch", displayName: "American Goldfinch", scientificName: "Spinus tristis", hazard: .safe,
                note: "Bright lemon-yellow males with a black cap in summer, duller olive in winter."),
        ],
        "mammal": [
            CatalogSubEntry(id: "eastern_gray_squirrel", displayName: "Eastern Gray Squirrel", scientificName: "Sciurus carolinensis", hazard: .safe,
                note: "The common tree squirrel across the eastern half of the US. Bold around people, especially where fed."),
            CatalogSubEntry(id: "white_tailed_deer", displayName: "White-tailed Deer", scientificName: "Odocoileus virginianus", hazard: .caution,
                note: "Named for the white underside of its tail, flashed when alarmed. Give space during rut and fawning season."),
            CatalogSubEntry(id: "raccoon", displayName: "Raccoon", scientificName: "Procyon lotor", hazard: .caution,
                note: "Recognizable by its black face mask and ringed tail. Nocturnal, so daytime activity can be a rabies warning sign."),
            CatalogSubEntry(id: "coyote", displayName: "Coyote", scientificName: "Canis latrans", hazard: .caution,
                note: "Smaller and lankier than a wolf, with large pointed ears. Increasingly common in suburban and urban areas."),
            CatalogSubEntry(id: "red_fox", displayName: "Red Fox", scientificName: "Vulpes vulpes", hazard: .caution,
                note: "Rusty orange coat, black legs, and a white-tipped tail. Shy around people despite its adaptability."),
            CatalogSubEntry(id: "virginia_opossum", displayName: "Virginia Opossum", scientificName: "Didelphis virginiana", hazard: .safe,
                note: "North America's only marsupial. Plays dead when threatened and very rarely carries rabies."),
            CatalogSubEntry(id: "striped_skunk", displayName: "Striped Skunk", scientificName: "Mephitis mephitis", hazard: .caution,
                note: "Black with two white stripes down the back. Give it room; it can spray accurately over 10 feet."),
            CatalogSubEntry(id: "eastern_cottontail", displayName: "Eastern Cottontail", scientificName: "Sylvilagus floridanus", hazard: .safe,
                note: "The common backyard rabbit east of the Rockies, with a namesake puffball tail."),
            CatalogSubEntry(id: "groundhog", displayName: "Groundhog", scientificName: "Marmota monax", hazard: .safe,
                note: "A large, low-slung burrowing rodent, also called a woodchuck. Digs extensive den systems."),
            CatalogSubEntry(id: "little_brown_bat", displayName: "Little Brown Bat", scientificName: "Myotis lucifugus", hazard: .caution,
                note: "A small insect-eating bat. Never handle one bare-handed; bats are a leading rabies vector."),
        ],
        "lizard": [
            CatalogSubEntry(id: "eastern_fence_lizard", displayName: "Eastern Fence Lizard", scientificName: "Sceloporus undulatus", hazard: .safe,
                note: "A spiny gray-brown lizard often seen doing \"push-ups\" on fence posts and tree trunks."),
            CatalogSubEntry(id: "side_blotched_lizard", displayName: "Common Side-blotched Lizard", scientificName: "Uta stansburiana", hazard: .safe,
                note: "Small and fast, with a dark blotch just behind the front leg. One of the most common lizards in the West."),
            CatalogSubEntry(id: "western_fence_lizard", displayName: "Western Fence Lizard", scientificName: "Sceloporus occidentalis", hazard: .safe,
                note: "Blue belly patches on males give it the common nickname \"blue-belly.\""),
            CatalogSubEntry(id: "green_anole", displayName: "Green Anole", scientificName: "Anolis carolinensis", hazard: .safe,
                note: "Can shift between bright green and brown. Males display a pink throat fan called a dewlap."),
            CatalogSubEntry(id: "five_lined_skink", displayName: "Common Five-lined Skink", scientificName: "Plestiodon fasciatus", hazard: .safe,
                note: "Glossy black or brown with five cream stripes; juveniles have a bright blue tail."),
            CatalogSubEntry(id: "desert_spiny_lizard", displayName: "Desert Spiny Lizard", scientificName: "Sceloporus magister", hazard: .safe,
                note: "Large and heavily scaled, found on rocks, trees, and fence posts across the Southwest."),
            CatalogSubEntry(id: "eastern_collared_lizard", displayName: "Eastern Collared Lizard", scientificName: "Crotaphytus collaris", hazard: .safe,
                note: "Named for the dark double band around its neck. Can sprint on its hind legs alone."),
            CatalogSubEntry(id: "gila_monster", displayName: "Gila Monster", scientificName: "Heloderma suspectum", hazard: .avoid,
                note: "One of only two venomous lizards in the world. Slow-moving, but do not handle: the bite is a real medical event."),
            CatalogSubEntry(id: "texas_horned_lizard", displayName: "Texas Horned Lizard", scientificName: "Phrynosoma cornutum", hazard: .safe,
                note: "The \"horny toad,\" armored with spines and camouflaged for sandy, open ground."),
            CatalogSubEntry(id: "new_mexico_whiptail", displayName: "New Mexico Whiptail", scientificName: "Aspidoscelis neomexicana", hazard: .safe,
                note: "New Mexico's state reptile. Every individual is female; the species reproduces without males."),
        ],
    ]
}
