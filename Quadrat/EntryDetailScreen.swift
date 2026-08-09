//
//  EntryDetailScreen.swift
//  Quadrat
//
//  Tapping a field log row. Shows what the app told you at the time, plus an
//  editable note and a zoomable photo.
//

import SwiftUI
import SwiftData

struct EntryDetailScreen: View {
    @Bindable var entry: FieldEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFullImage = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    photo
                    headline
                    hazardBox
                    if !entry.ruledOut.isEmpty { ruledOutBox }
                    notes
                    noteEditor
                    metadata
                    deleteButton
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bark, for: .navigationBar)
        .fullScreenCover(isPresented: $showFullImage) {
            if let data = entry.imageData, let image = UIImage(data: data) {
                ZoomableImageView(image: image)
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var photo: some View {
        if let data = entry.imageData, let image = UIImage(data: data) {
            Button { showFullImage = true } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.parchment)
                            .padding(7)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(9)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayGroup.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.lichen)
                Spacer()
                if !entry.tierRaw.isEmpty {
                    Text(entry.tierRaw)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.lichen.opacity(0.75))
                }
            }

            Text(entry.displayTitle)
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)

            // Same rule as the result screen: no confidence number on a refusal.
            if !entry.wasRefusal {
                Text("\(Int(entry.confidence * 100))% confidence")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)
            }
        }
    }

    private var hazardBox: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: entry.hazard.symbol)
                .foregroundStyle(hazardTint)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.hazard.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hazardTint)
                Text(entry.displayHazardNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(hazardTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hazardTint.opacity(0.5), lineWidth: 1))
    }

    private var ruledOutBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RULED OUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            ForEach(entry.ruledOut, id: \.self) { item in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.moss)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.parchment.opacity(0.85))
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.moss.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    private var hazardTint: Color {
        switch entry.hazard {
        case .safe:    return Palette.moss
        case .caution: return Palette.ochre
        case .avoid:   return Palette.rust
        case .unknown: return Palette.lichen
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.displayFieldNotes, id: \.self) { line in
                HStack(alignment: .top, spacing: 7) {
                    Text("—").foregroundStyle(Palette.ochre)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !entry.displayNextStep.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 11))
                    Text(entry.displayNextStep).font(.system(size: 11.5))
                }
                .foregroundStyle(Palette.lichen)
                .padding(.top, 4)
            }
        }
    }

    /// Editable in place — @Bindable writes straight through to SwiftData,
    /// so there's no explicit save call.
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YOUR NOTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            TextField("add a note…", text: $entry.note, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.parchment)
                .padding(9)
                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.capturedAt.formatted(date: .long, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen)
            Text("classifier label: \(entry.rawLabel)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.lichen.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Text("Delete entry")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(Palette.rust)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Palette.rust.opacity(0.5), lineWidth: 1)
                )
        }
        .padding(.top, 8)
    }
}

// MARK: - Full-screen zoomable photo

struct ZoomableImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), 6)
                        }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.25)) {
                        scale = scale > 1 ? 1 : 3
                        lastScale = scale
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding(18)
                }
                Spacer()
            }
        }
    }
}
