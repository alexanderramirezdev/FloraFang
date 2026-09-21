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
//  Reference photos: each species/category can carry a bundled imageset in
//  Assets.xcassets, named per CatalogDetailTarget.referenceImageName below.
//  Nothing crashes or shows a broken image if one's missing yet; the photo
//  block just doesn't render until an asset with that name exists.
//
//  Sub-species drill-down: bird, mammal, and lizard also expose a "top 10"
//  species list (CatalogSubSpecies.swift) instead of a single generic
//  photo, since those are the categories most worth splitting further. See
//  that file for why this stays reference-only and is never a live-scan
//  result — there's no bird/mammal/lizard classifier model behind it.
//

import SwiftUI
import UIKit

private enum CatalogDetailTarget: Identifiable, Hashable {
    case spider(SpiderClass)
    case plant(PlantClass)
    case general(CatalogEntry)
    case subSpecies(CatalogSubEntry, category: String)

    var id: String {
        switch self {
        case .spider(let s):               return "spider-\(s.rawValue)"
        case .plant(let p):                return "plant-\(p.rawValue)"
        case .general(let g):              return "general-\(g.id)"
        case .subSpecies(let sub, let c):   return "sub-\(c)-\(sub.id)"
        }
    }

    /// Matches an imageset name dropped into Assets.xcassets by hand, one
    /// per species/category, picked from Scripts/fetch_reference_photos.py's
    /// candidates. Spider rawValues and plant trainingLabels already match
    /// that script's class_name keys (both are training-data snake_case);
    /// general categories and sub-species get their own prefix so nothing
    /// collides. No image dropped in yet just means this lookup misses and
    /// the detail screen skips the photo, so this is safe to ship before
    /// the images exist.
    var referenceImageName: String {
        switch self {
        case .spider(let s):               return "ref_\(s.rawValue)"
        case .plant(let p):                return "ref_\(p.trainingLabel)"
        case .general(let g):              return "ref_general_\(g.id)"
        case .subSpecies(let sub, let c):   return "ref_sub_\(c)_\(sub.id)"
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
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.shield")
                                .foregroundStyle(Palette.warn)
                            Text("Reference only. Never approach, handle, or corner wildlife or an unfamiliar plant to get a closer look or a photo — observe from a safe distance.")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Palette.surface)

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
                            if let subSpecies = CatalogSubSpecies.byCategory[entry.id] {
                                NavigationLink {
                                    CatalogSubSpeciesListScreen(
                                        category: entry,
                                        subSpecies: subSpecies,
                                        selection: $selection
                                    )
                                } label: {
                                    // NavigationLink already draws its own disclosure
                                    // chevron inside a List, so the row skips its own
                                    // to avoid the double-arrow this had before.
                                    catalogRow(title: entry.displayName, hazard: entry.hazard, showChevron: false)
                                }
                            } else {
                                Button { selection = .general(entry) } label: {
                                    catalogRow(title: entry.displayName, hazard: entry.hazard)
                                }
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

    private func catalogRow(title: String, hazard: Hazard, showChevron: Bool = true) -> some View {
        HStack {
            Image(systemName: hazard.symbol)
                .foregroundStyle(tint(for: hazard))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.parchment)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen.opacity(0.6))
            }
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

/// Pushed onto the nav stack (not sheeted) when a general category has a
/// "top 10" species breakdown. Tapping a species still sets the same
/// `selection` binding CatalogBrowseScreen's `.sheet(item:)` is watching, so
/// the detail sheet opens over this screen exactly like it does for a
/// spider or plant row.
private struct CatalogSubSpeciesListScreen: View {
    let category: CatalogEntry
    let subSpecies: [CatalogSubEntry]
    @Binding var selection: CatalogDetailTarget?

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()
            List {
                Section {
                    Text(category.hazardNote)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment.opacity(0.85))
                        .padding(.vertical, 4)
                }
                .listRowBackground(Palette.surface)

                Section("COMMON \(category.displayName.uppercased())S") {
                    ForEach(subSpecies) { sub in
                        Button { selection = .subSpecies(sub, category: category.id) } label: {
                            HStack {
                                Image(systemName: sub.hazard.symbol)
                                    .foregroundStyle(tint(for: sub.hazard))
                                    .frame(width: 20)
                                Text(sub.displayName)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Palette.parchment)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.lichen.opacity(0.6))
                            }
                        }
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bark, for: .navigationBar)
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
        case .spider(let s):        return s.displayName
        case .plant(let p):         return p.displayName
        case .general(let g):       return g.displayName
        case .subSpecies(let s, _): return s.displayName
        }
    }

    private var subtitle: String? {
        switch target {
        case .spider(let s):        return s.genus
        case .plant(let p):         return p.scientificName.isEmpty ? nil : p.scientificName
        case .general:              return nil
        case .subSpecies(let s, _): return s.scientificName
        }
    }

    private var hazard: Hazard {
        switch target {
        case .spider(let s):        return s.hazard
        case .plant(let p):         return p.hazard
        case .general(let g):       return g.hazard
        case .subSpecies(let s, _): return s.hazard
        }
    }

    private var hazardNote: String {
        switch target {
        case .spider(let s):        return s.hazardNote
        case .plant(let p):         return p.hazardNote
        case .general(let g):       return g.hazardNote
        case .subSpecies(let s, _): return s.note
        }
    }

    private var fieldNotes: [String] {
        switch target {
        case .spider(let s):  return s.fieldNotes
        case .plant(let p):   return p.fieldNotes
        case .general(let g): return g.fieldNotes
        case .subSpecies:     return []
        }
    }

    private var nextStep: String {
        switch target {
        case .spider(let s):  return s.nextStep
        case .plant(let p):   return p.nextStep
        case .general(let g): return g.nextStep
        case .subSpecies:     return ""
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

                        if let refImage = UIImage(named: target.referenceImageName) {
                            // scaledToFit (not fill) on purpose: these are
                            // reference photos, and a center-crop fill was
                            // cutting the actual animal/plant out of frame
                            // whenever the source photo wasn't tightly
                            // composed. A letterboxed full photo beats an
                            // edge-to-edge crop of empty background.
                            Image(uiImage: refImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .background(Palette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Palette.moss.opacity(0.4), lineWidth: 1)
                                )
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
