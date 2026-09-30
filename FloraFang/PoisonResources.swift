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
import UIKit
import UniformTypeIdentifiers

/// Copies exposure summaries (patient type, weight, symptoms, what was
/// eaten) without letting them outlive the phone call. Local only keeps it
/// off Universal Clipboard, so it doesn't sync to the person's Mac or iPad,
/// and it expires after 10 minutes instead of sitting in the pasteboard
/// for whatever app reads it next.
enum SensitiveClipboard {
    static let lifetime: TimeInterval = 600

    @MainActor
    static func copy(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(lifetime)
            ]
        )
    }
}

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

    /// Non optional form for Link(destination:). Safe to unwrap because
    /// dialString is digits only, which PoisonResourcesTests enforces.
    var callURL: URL { telURL! }
}

enum PoisonResources {

    // The single source for every hotline number in the app. Every screen
    // that shows or dials one reads it from here, so a number can only be
    // wrong in one place, and PoisonResourcesTests pins every digit.

    static let aspca = PoisonResource(
        name: "ASPCA Animal Poison Control",
        phone: "(888) 426 4435",
        dialString: "8884264435",
        detail: "24 hours, every day. A consultation fee may apply.",
        audience: .pet
    )

    static let petPoisonHelpline = PoisonResource(
        name: "Pet Poison Helpline",
        phone: "(855) 764 7661",
        dialString: "8557647661",
        detail: "24 hours, every day. A consultation fee may apply.",
        audience: .pet
    )

    static let human = PoisonResource(
        name: "Poison Control (people)",
        phone: "(800) 222 1222",
        dialString: "18002221222",
        detail: "24 hours, every day. Free and confidential.",
        audience: .human
    )

    static let all: [PoisonResource] = [aspca, petPoisonHelpline, human]

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
        case .otherAnimal: return "Other"
        case .child:       return "Child"
        case .adult:       return "Adult"
        }
    }

    var placeholderDetail: String {
        switch self {
        case .dog:         return "60 lb lab, 4 years"
        case .cat:         return "9 lb domestic shorthair, 3 years"
        case .otherAnimal: return "25 lb pet, unknown age"
        case .child:       return "35 lbs, 4 years old"
        case .adult:       return "Adult, approx 160 lbs"
        }
    }

    var isAnimal: Bool {
        self == .dog || self == .cat || self == .otherAnimal
    }

    var audience: PoisonResource.Audience {
        isAnimal ? .pet : .human
    }
}
