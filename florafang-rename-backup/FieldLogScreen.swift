//
//  FieldLogScreen.swift
//  FloraFang
//

import SwiftUI
import SwiftData

struct FieldLogScreen: View {
    @Environment(\.modelContext) private var modelContext

    // @Query is SwiftData's live-updating fetch. The view re-renders on its own
    // when rows change — no manual refresh call needed.
    @Query(sort: \FieldEntry.capturedAt, order: .reverse)
    private var entries: [FieldEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryDetailScreen(entry: entry)
                            } label: {
                                row(entry)
                            }
                            .listRowBackground(Palette.bark)
                            .listRowSeparatorTint(Palette.moss.opacity(0.4))
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Field Log")
            .toolbarBackground(Palette.bark, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 34))
                .foregroundStyle(Palette.moss)
            Text("Nothing logged yet")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
            Text("Scan something and it'll show up here.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(Palette.lichen)
        }
    }

    private func row(_ entry: FieldEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let data = entry.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Palette.moss
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.parchment)
                    .lineLimit(2)
                Text(entry.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(Palette.lichen.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: entry.hazard.symbol)
                .font(.system(size: 13))
                .foregroundStyle(tint(for: entry.hazard))
        }
        .padding(.vertical, 3)
    }

    private func tint(for hazard: Hazard) -> Color {
        switch hazard {
        case .safe:    return Palette.moss
        case .caution: return Palette.ochre
        case .avoid:   return Palette.rust
        case .unknown: return Palette.lichen
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}
