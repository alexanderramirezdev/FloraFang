//
//  ShareableIDCard.swift
//  FloraFang
//
//  Renders a FieldEntry as a single shareable image: photo, headline, and
//  hazard note, framed like a small field-guide card. Premium feature —
//  purely a nice-to-have for sharing what you found. Nothing about a
//  hazard verdict lives here; the card just displays what EntryDetailScreen
//  already computed and saved on the entry.
//

import SwiftUI

struct IdentificationCardView: View {
    let entry: FieldEntry

    private var hazardTint: Color {
        switch entry.hazard {
        case .safe:    return Palette.safe
        case .caution: return Palette.warn
        case .avoid:   return Palette.danger
        case .unknown: return Palette.lichen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = entry.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 260)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.displayGroup.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.lichen)

                Text(entry.displayTitle)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.parchment)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: entry.hazard.symbol)
                        .foregroundStyle(hazardTint)
                    Text(entry.displayHazardNote)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(hazardTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.ochre)
                    Text("Identified with FloraFang")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.lichen)
                    Spacer()
                    Text(entry.capturedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.lichen.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Palette.bark)
        .frame(width: 360)
    }
}

@MainActor
enum IdentificationCardRenderer {
    /// Renders off the visible view hierarchy at a fixed width so the card
    /// looks the same regardless of the device it's generated on.
    static func render(_ entry: FieldEntry) -> UIImage? {
        let view = IdentificationCardView(entry: entry)
        let renderer = ImageRenderer(content: view)
        // Fixed at 3x rather than reading the device's actual scale:
        // UIScreen.main is deprecated (iOS 26) in favor of a screen
        // reached through view context, which a static renderer with
        // no view in the hierarchy doesn't have. A shared image card
        // doesn't need to track the exact device anyway.
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
