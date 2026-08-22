//
//  PoisonResources.swift
//  FloraFang
//
//  Hardcoded on purpose. These numbers must work with no network, no model,
//  and no successful identification. They are the one part of the emergency
//  flow that cannot be allowed to fail.
//
//  US only. If the app ever ships outside the US these need to become
//  locale aware, and until then the emergency screen should say so.
//
//  Verified August 2026. Worth rechecking before each release.
//

import Foundation

struct PoisonResource: Identifiable {
    let id = UUID()
    let name: String
    let phone: String        // display form
    let dialString: String   // digits only, for tel://
    let detail: String
    let audience: Audience

    enum Audience {
        case pet
        case human
    }

    var telURL: URL? { URL(string: "tel://\(dialString)") }
}

enum PoisonResources {

    static let all: [PoisonResource] = [
        PoisonResource(
            name: "ASPCA Animal Poison Control",
            phone: "(888) 426-4435",
            dialString: "8884264435",
            detail: "24 hours, every day. A consultation fee may apply.",
            audience: .pet
        ),
        PoisonResource(
            name: "Pet Poison Helpline",
            phone: "(855) 764-7661",
            dialString: "8557647661",
            detail: "24 hours, every day. A consultation fee may apply.",
            audience: .pet
        ),
        PoisonResource(
            name: "Poison Control (people)",
            phone: "1-800-222-1222",
            dialString: "18002221222",
            detail: "24 hours, every day. Free and confidential.",
            audience: .human
        )
    ]

    static func forAudience(_ audience: PoisonResource.Audience) -> [PoisonResource] {
        all.filter { $0.audience == audience }
    }
}

/// Who was exposed. Chooses which hotlines to show first and shapes the
/// intake questions, since poison control asks different things about a
/// forty pound dog than about a toddler.
enum ExposureSubject: String, CaseIterable, Identifiable {
    case dog, cat, otherAnimal, child, adult

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dog:         return "Dog"
        case .cat:         return "Cat"
        case .otherAnimal: return "Other animal"
        case .child:       return "Child"
        case .adult:       return "Adult"
        }
    }

    var isAnimal: Bool {
        self == .dog || self == .cat || self == .otherAnimal
    }

    var audience: PoisonResource.Audience {
        isAnimal ? .pet : .human
    }
}
