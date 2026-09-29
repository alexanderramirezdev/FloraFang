import Foundation

/// Photographer credits for the CC BY licensed reference photos bundled in the app.
/// Source of truth is REFERENCE_PHOTO_CREDITS.md. CC0 photos need no credit and are omitted.
struct PhotoCredit: Identifiable, Hashable {
    let subject: String
    let photographer: String
    let observationID: Int

    var id: String { subject }

    var photographerURL: URL? { URL(string: "https://www.inaturalist.org/people/\(photographer)") }
    var observationURL: URL? { URL(string: "https://www.inaturalist.org/observations/\(observationID)") }
}

enum PhotoCredits {
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")
    static let all: [PhotoCredit] = [
        PhotoCredit(subject: "American Crow", photographer: "bluejaybluejay", observationID: 139679929),
        PhotoCredit(subject: "American Robin", photographer: "milaturov", observationID: 209375487),
        PhotoCredit(subject: "Black Capped Chickadee", photographer: "blakemross", observationID: 93952311),
        PhotoCredit(subject: "Blue Jay", photographer: "oksanaetal", observationID: 247799208),
        PhotoCredit(subject: "Castor Bean", photographer: "eralverson", observationID: 54869160),
        PhotoCredit(subject: "Datura", photographer: "littlelegofan", observationID: 72112801),
        PhotoCredit(subject: "Eastern Cottontail", photographer: "bugeyedbernie", observationID: 150217371),
        PhotoCredit(subject: "Eastern Gray Squirrel", photographer: "mmmiller", observationID: 191545276),
        PhotoCredit(subject: "European Starling", photographer: "egorbirder", observationID: 72752929),
        PhotoCredit(subject: "General Flower", photographer: "morten", observationID: 1501426),
        PhotoCredit(subject: "General Mushroom", photographer: "alan_rockefeller", observationID: 188728693),
        PhotoCredit(subject: "General Plant", photographer: "morten", observationID: 1501426),
        PhotoCredit(subject: "General Snake", photographer: "jvl", observationID: 111494406),
        PhotoCredit(subject: "General Spider", photographer: "wynand_uys", observationID: 9319352),
        PhotoCredit(subject: "Giant Hogweed", photographer: "tsn", observationID: 171921129),
        PhotoCredit(subject: "Gila Monster", photographer: "sheriff_woody_pct", observationID: 33820523),
        PhotoCredit(subject: "Green Anole", photographer: "daughterdad", observationID: 270279876),
        PhotoCredit(subject: "Groundhog", photographer: "sdz456", observationID: 2978994),
        PhotoCredit(subject: "House Finch", photographer: "dennisvo", observationID: 48944342),
        PhotoCredit(subject: "Huntsman", photographer: "mutolisp", observationID: 12638695),
        PhotoCredit(subject: "Jumping Spider", photographer: "scottward", observationID: 59225791),
        PhotoCredit(subject: "Lily", photographer: "alexanderdubynin", observationID: 49702343),
        PhotoCredit(subject: "Little Brown Bat", photographer: "leeann_latremouille", observationID: 187204962),
        PhotoCredit(subject: "Mourning Dove", photographer: "froggymum", observationID: 330289532),
        PhotoCredit(subject: "Northern Cardinal", photographer: "daughterdad", observationID: 287527828),
        PhotoCredit(subject: "Orb Weaver", photographer: "suncana", observationID: 9060520),
        PhotoCredit(subject: "Poison Ivy and Oak", photographer: "alan_rockefeller", observationID: 61188945),
        PhotoCredit(subject: "Poison Sumac", photographer: "jyoung2399", observationID: 243145419),
        PhotoCredit(subject: "Raccoon", photographer: "mchlfx", observationID: 2402257),
        PhotoCredit(subject: "Recluse", photographer: "elaphrornis", observationID: 91147844),
        PhotoCredit(subject: "Red Fox", photographer: "urusovaalina", observationID: 36315268),
        PhotoCredit(subject: "Red Tailed Hawk", photographer: "inkasaur", observationID: 365887523),
        PhotoCredit(subject: "Sago Palm", photographer: "dhfischer", observationID: 56080786),
        PhotoCredit(subject: "Side Blotched Lizard", photographer: "decoyhedgehog", observationID: 269406119),
        PhotoCredit(subject: "Striped Skunk", photographer: "rpoort", observationID: 197025524),
        PhotoCredit(subject: "Tarantula", photographer: "ricardelremate", observationID: 71037729),
        PhotoCredit(subject: "Texas Horned Lizard", photographer: "seeddweeb", observationID: 14328297),
        PhotoCredit(subject: "Virginia Opossum", photographer: "milliebasden", observationID: 7073976),
        PhotoCredit(subject: "Western Fence Lizard", photographer: "shawnodonnell", observationID: 82124588),
        PhotoCredit(subject: "White Tailed Deer", photographer: "nflicker101", observationID: 119644833),
        PhotoCredit(subject: "Widow", photographer: "renatobrito", observationID: 51608861),
        PhotoCredit(subject: "Wolf Spider", photographer: "invertebratist", observationID: 204690367),
    ]
}
