//
//  SpeciesLifeListScreen.swift
//  FloraFang
//
//  A checklist of the named species FloraFang can call out by name — which
//  ones have actually turned up in your field log, and which haven't yet.
//  Premium: this only reads your own already-logged entries. It changes
//  nothing about what a live scan tells you.
//

import SwiftUI
import SwiftData

struct SpeciesLifeListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FieldEntry.capturedAt) private var entries: [FieldEntry]

    private var loggedSpiderLabels: Set<String> {
        Set(entries.filter { $0.categoryKey == "spider" }.map { $0.rawLabel.lowercased() })
    }

    private var loggedPlantLabels: Set<String> {
        Set(entries.filter { $0.categoryKey == "plant" }.map { $0.rawLabel.lowercased() })
    }

    // Excludes the catch-all and negative classes (otherSpider, notASpider,
    // notMedicallySignificant, notKnownToxic) — those aren't species, so a
    // checklist of them would be meaningless.
    private var spiderSpecies: [SpiderClass] {
        SpiderClass.allCases.filter {
            $0 != .otherSpider && $0 != .notASpider && $0 != .notMedicallySignificant
        }
    }

    private var plantSpecies: [PlantClass] {
        PlantClass.allCases.filter { $0 != .notKnownToxic }
    }

    private var foundSpiderCount: Int {
        spiderSpecies.filter { loggedSpiderLabels.contains($0.trainingLabel) }.count
    }

    private var foundPlantCount: Int {
        plantSpecies.filter { loggedPlantLabels.contains($0.trainingLabel) }.count
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

                    Section {
                        progressRow(title: "Spiders", found: foundSpiderCount, total: spiderSpecies.count)
                        progressRow(title: "Toxic plants", found: foundPlantCount, total: plantSpecies.count)
                    }
                    .listRowBackground(Palette.surface)

                    Section("SPIDERS") {
                        ForEach(spiderSpecies, id: \.self) { species in
                            row(
                                title: species.displayName,
                                subtitle: species.genus,
                                found: loggedSpiderLabels.contains(species.trainingLabel)
                            )
                        }
                    }
                    .listRowBackground(Palette.surface)

                    Section("TOXIC PLANTS") {
                        ForEach(plantSpecies, id: \.self) { species in
                            row(
                                title: species.displayName,
                                subtitle: species.scientificName,
                                found: loggedPlantLabels.contains(species.trainingLabel)
                            )
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Field Checklist")
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

    private func progressRow(title: String, found: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.parchment)
            Spacer()
            Text("\(found) of \(total) found")
                .font(.system(size: 12))
                .foregroundStyle(Palette.lichen)
        }
    }

    private func row(title: String, subtitle: String, found: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(found ? Palette.moss : Palette.lichen.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(found ? Palette.parchment : Palette.lichen)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .italic()
                        .foregroundStyle(Palette.lichen.opacity(0.7))
                }
            }
            Spacer()
        }
        .opacity(found ? 1 : 0.6)
    }
}
