//
//  ExposureReport.swift
//  FloraFang
//
//  What the person reads off to poison control.
//
//  This is the actual value of the emergency flow. The plant identification
//  may be wrong or absent, but a caller who already has the weight, the
//  timing, the amount, and the symptom list turns a slow panicked call into
//  a fast one. That value does not depend on the model being right, which is
//  exactly why the feature is built around it.
//
//  The fields mirror what ASPCA Animal Poison Control asks for: the animal's
//  details, what was eaten and how much, and whether signs have started.
//

import Foundation

struct ExposureReport {

    var subject: ExposureSubject = .dog

    /// Free text so a user can put "60 lb lab mix" or "3 year old, 35 lbs".
    /// A picker here would slow down someone in a panic for no benefit.
    var subjectDetail: String = ""

    /// Suspected plant, if the model produced one. Optional on purpose.
    var suspectedPlant: PlantClass?

    /// What the classifier actually emitted, kept for the relay summary so
    /// the vet hears the raw match rather than only our label for it.
    var rawLabel: String = ""
    var confidence: Double = 0

    var partEaten: PlantPart = .unknown
    var amount: String = ""
    var timeOfExposure: Date = .now
    var symptoms: Set<Symptom> = []
    var otherNotes: String = ""

    enum PlantPart: String, CaseIterable, Identifiable {
        case leaf, berryOrSeed, flower, stemOrBark, root, unknown
        var id: String { rawValue }

        var label: String {
            switch self {
            case .leaf:        return "Leaf"
            case .berryOrSeed: return "Berry or seed"
            case .flower:      return "Flower"
            case .stemOrBark:  return "Stem or bark"
            case .root:        return "Root or bulb"
            case .unknown:     return "Not sure"
            }
        }
    }

    /// Kept short and plain. This is a checklist for a phone call, not a
    /// diagnostic instrument, and FloraFang does not interpret these.
    enum Symptom: String, CaseIterable, Identifiable {
        case vomiting
        case drooling
        case lethargy
        case notEating
        case tremors
        case troubleBreathing
        case diarrhea
        case collapse

        var id: String { rawValue }

        var label: String {
            switch self {
            case .vomiting:         return "Vomiting"
            case .drooling:         return "Drooling"
            case .lethargy:         return "Lethargic or weak"
            case .notEating:        return "Not eating"
            case .tremors:          return "Tremors or shaking"
            case .troubleBreathing: return "Trouble breathing"
            case .diarrhea:         return "Diarrhea"
            case .collapse:         return "Collapse or seizure"
            }
        }
    }

    /// Formatted for reading aloud. Deliberately plain and ordered the way
    /// the call tends to go.
    func relaySummary() -> String {
        var lines: [String] = []

        lines.append("WHO: \(subject.label)\(subjectDetail.isEmpty ? "" : ", \(subjectDetail)")")

        if let plant = suspectedPlant {
            let pct = Int(confidence * 100)
            lines.append("POSSIBLE PLANT: \(plant.displayName)"
                         + (plant.scientificName.isEmpty ? "" : " (\(plant.scientificName))")
                         + " — unconfirmed photo match, \(pct)% model confidence")
        } else {
            lines.append("POSSIBLE PLANT: not identified. Photo available.")
        }

        lines.append("PART: \(partEaten.label)")
        if !amount.isEmpty {
            lines.append("AMOUNT: \(amount)")
        }

        let elapsed = Date.now.timeIntervalSince(timeOfExposure)
        let minutes = max(0, Int(elapsed / 60))
        lines.append("WHEN: \(timeOfExposure.formatted(date: .omitted, time: .shortened)), about \(minutes) minutes ago")

        if symptoms.isEmpty {
            lines.append("SIGNS: none noticed yet")
        } else {
            let list = Symptom.allCases
                .filter { symptoms.contains($0) }
                .map(\.label)
                .joined(separator: ", ")
            lines.append("SIGNS: \(list)")
        }

        if !otherNotes.isEmpty {
            lines.append("NOTES: \(otherNotes)")
        }

        return lines.joined(separator: "\n")
    }
}
