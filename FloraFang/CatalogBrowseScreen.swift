//
//  CatalogBrowseScreen.swift
//  FloraFang
//
//  Everything FloraFang can put a name to, browsable without pointing a
//  camera at anything. Premium: pure reference material. The live hazard
//  verdict for something you actually scan never routes through this
//  screen or checks the unlock — it's read straight off Catalog.swift,
//  SpiderClasses.swift and PlantClasses.swift either way.
//

import SwiftUI

private enum CatalogDetailTarget: Identifiable, Hashable {
    case spider(SpiderClass)
    case plant(PlantClass)
    case general(CatalogEntry)

    var id: String {
        switch self {
        case .spider(let s):  return "spider-\(s.rawValue)"
        case .plant(let p):   return "plant-\(p.rawValue)"
        case .general(let g): return "general-\(g.id)"
        }
    }
}

struct CatalogBrowseScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: CatalogDetailTarget?

    private var spiderSpecies: [SpiderClass] {
        SpiderClass.allCases.filter {
            $0 != .otherSpider && $0 != .notASpider && $0 != .notMedicallySignificant
        }
    }

    private var plantSpecies: [PlantClass] {
        PlantClass.allCases.filter { $0 != .notKnownToxic }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()
                List {
                    Section("SPIDERS") {
                        ForEach(spiderSpecies, id: \.self) { species in
                            Button { selection = .spider(species) } label: {
                                catalogRow(title: species.displayName, hazard: species.hazard)
                            }
                        }
                    }
                    .listRowBackground(Palette.surface)

                    Section("TOXIC PLANTS") {
                        ForEach(plantSpecies, id: \.self) { species in
                            Button { selection = .plant(species) } label: {
                                catalogRow(title: species.displayName, hazard: species.hazard)
                            }
                        }
                    }
                    .listRowBackground(Palette.surface)

                    Section("GENERAL CATEGORIES") {
                        ForEach(Catalog.all) { entry in
                            Button { selection = .general(entry) } label: {
                                catalogRow(title: entry.displayName, hazard: entry.hazard)
                            }
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Species Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.ochre)
                }
            }
            .sheet(item: $selection) { target in
                CatalogDetailSheet(target: target)
            }
        }
    }

    private func catalogRow(title: String, hazard: Hazard) -> some View {
        HStack {
            Image(systemName: hazard.symbol)
                .foregroundStyle(tint(for: hazard))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.parchment)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen.opacity(0.6))
        }
    }

    private func tint(for hazard: Hazard) -> Color {
        switch hazard {
        case .safe:    return Palette.safe
        case .caution: return Palette.warn
        case .avoid:   return Palette.danger
        case .unknown: return Palette.lichen
        }
    }
}

private struct CatalogDetailSheet: View {
    let target: CatalogDetailTarget
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch target {
        case .spider(let s):  return s.displayName
        case .plant(let p):   return p.displayName
        case .general(let g): return g.displayName
        }
    }

    private var subtitle: String? {
        switch target {
        case .spider(let s):  return s.genus
        case .plant(let p):   return p.scientificName.isEmpty ? nil : p.scientificName
        case .general:        return nil
        }
    }

    private var hazard: Hazard {
        switch target {
        case .spider(let s):  return s.hazard
        case .plant(let p):   return p.hazard
        case .general(let g): return g.hazard
        }
    }

    private var hazardNote: String {
        switch target {
        case .spider(let s):  return s.hazardNote
        case .plant(let p):   return p.hazardNote
        case .general(let g): return g.hazardNote
        }
    }

    private var fieldNotes: [String] {
        switch target {
        case .spider(let s):  return s.fieldNotes
        case .plant(let p):   return p.fieldNotes
        case .general(let g): return g.fieldNotes
        }
    }

    private var nextStep: String {
        switch target {
        case .spider(let s):  return s.nextStep
        case .plant(let p):   return p.nextStep
        case .general(let g): return g.nextStep
        }
    }

    private var hazardTint: Color {
        switch hazard {
        case .safe:    return Palette.safe
        case .caution: return Palette.warn
        case .avoid:   return Palette.danger
        case .unknown: return Palette.lichen
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(Palette.parchment)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .italic()
                                    .foregroundStyle(Palette.lichen)
                            }
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: hazard.symbol)
                                .foregroundStyle(hazardTint)
                            Text(hazardNote)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Palette.parchment.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .background(hazardTint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))

                        if !fieldNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FIELD NOTES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(Palette.lichen)
                                ForEach(fieldNotes, id: \.self) { note in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•").foregroundStyle(Palette.moss)
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.parchment.opacity(0.85))
                                    }
                                }
                            }
                        }

                        if !nextStep.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEXT STEP")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(Palette.lichen)
                                Text(nextStep)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Palette.parchment)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.ochre)
                }
            }
        }
    }
}
