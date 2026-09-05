//
//  FieldGuidanceView.swift
//  FloraFang
//
//  Renders diagnostic field notes, visible markings, and photography retake
//  guidance in a structured, readable format rather than an unformatted text dump.
//

import SwiftUI

struct FieldGuidanceView: View {
    let notes: [String]
    let nextStep: String
    var wasRefusal: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Visual Observations (e.g. Apple Intelligence description)
            if let observation = observationNote {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.ochre)
                        Text("VISUAL OBSERVATION")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.lichen)
                    }

                    Text("\"\(cleanObservationText(observation))\"")
                        .font(.system(size: 12.5))
                        .italic()
                        .foregroundStyle(Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            }

            // Visible confirmed markings
            if !visibleFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.moss)
                        Text("CONFIRMED MARKINGS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.lichen)
                    }

                    ForEach(visibleFeatures, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(Palette.moss)
                            Text(item)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment.opacity(0.9))
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.moss.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            // Obscured / Missing Features (Cleaned up from raw enums)
            if !missingFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.ochre)
                        Text("OBSCURED IN THIS ANGLE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.lichen)
                    }

                    Text("Crucial safety markings could not be confirmed:")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.parchment.opacity(0.75))

                    FlowLayout(spacing: 6) {
                        ForEach(missingFeatures, id: \.self) { feature in
                            Text(feature)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Palette.moss.opacity(0.2), in: Capsule())
                                .overlay(Capsule().stroke(Palette.moss.opacity(0.4), lineWidth: 1))
                                .foregroundStyle(Palette.parchment)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }

            // Photography / Retake Advice
            if !photoAdvice.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.ochre)
                        Text(wasRefusal ? "TO GET A BETTER ANSWER" : "PHOTOGRAPHY ADVICE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.lichen)
                    }

                    ForEach(photoAdvice, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 7) {
                            Text("•").foregroundStyle(Palette.ochre)
                            Text(tip)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            }

            // Other general notes
            if !generalNotes.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(generalNotes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 7) {
                            Text("•").foregroundStyle(Palette.lichen)
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Next Step / External Community
            if !nextStep.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.ochre)
                        .padding(.top, 2)
                    Text(nextStep)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.lichen)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Classification Helpers

    private var observationNote: String? {
        notes.first { line in
            line.contains("Apple Intelligence observed:") || line.contains("Apple Intelligence:")
        }
    }

    private func cleanObservationText(_ text: String) -> String {
        var clean = text
        if let range = clean.range(of: "Apple Intelligence observed:") {
            clean = String(clean[range.upperBound...])
        } else if let range = clean.range(of: "Apple Intelligence:") {
            clean = String(clean[range.upperBound...])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private var visibleFeatures: [String] {
        notes.compactMap { line in
            if line.hasPrefix("Visible: ") {
                let text = String(line.dropFirst("Visible: ".count))
                return text.trimmingCharacters(in: .punctuationCharacters)
            }
            return nil
        }
    }

    private var missingFeatures: [String] {
        guard let line = notes.first(where: {
            $0.lowercased().contains("not visible in photo:") || $0.lowercased().contains("not visible in this photo:")
        }) else {
            return wasRefusal ? ["Underside of abdomen", "Violin marking behind head", "Eye arrangement"] : []
        }

        let prefix = line.contains("Not visible in photo:") ? "Not visible in photo:" : "Not visible in this photo:"
        guard let range = line.range(of: prefix) else { return [] }
        let rawList = String(line[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        let tokens = rawList.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let filtered = tokens.compactMap { humanizeDiagnosticFeature(String($0)) }

        // If the model reported only benign items or context, surface the 3 key views needed for safety triage
        if filtered.isEmpty && wasRefusal {
            return ["Underside of abdomen", "Violin marking behind head", "Eye arrangement"]
        }
        return filtered
    }

    /// Only maps critical, medically significant markers required for safety triage.
    /// Filters out benign anatomical noise (egg sacs, webs, leg banding, hairiness, etc.).
    private func humanizeDiagnosticFeature(_ raw: String) -> String? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean {
        case "sixEyesInThreePairs":
            return "Eye arrangement (six eyes)"
        case "violinShapeBehindHead":
            return "Violin marking behind head"
        case "redHourglassUnderside":
            return "Underside red hourglass"
        case "redOrOrangeSpotsOnBack":
            return "Red/orange dorsal spots"
        case "glossyBlackRoundAbdomen":
            return "Glossy black round abdomen"
        case "uniformTanOrBrownBody":
            return "Uniform tan/brown body"
        default:
            // Discard benign features and environmental context (egg sacs, webs, hairy body, etc.)
            return nil
        }
    }

    private var photoAdvice: [String] {
        notes.filter { line in
            let lower = line.lowercased()
            if lower.contains("apple intelligence") || lower.contains("not visible") || line.hasPrefix("Visible:") {
                return false
            }
            return lower.contains("retake") ||
                   lower.contains("angle") ||
                   lower.contains("underside") ||
                   lower.contains("light") ||
                   lower.contains("flash") ||
                   lower.contains("zoom") ||
                   lower.contains("shot from") ||
                   lower.contains("square")
        }
    }

    private var generalNotes: [String] {
        notes.filter { line in
            let lower = line.lowercased()
            if lower.contains("apple intelligence") ||
               lower.contains("not visible") ||
               line.hasPrefix("Visible:") ||
               lower.contains("retake") ||
               lower.contains("angle") ||
               lower.contains("underside") ||
               lower.contains("light") ||
               lower.contains("flash") ||
               lower.contains("zoom") ||
               lower.contains("shot from") ||
               lower.contains("square") {
                return false
            }
            return true
        }
    }
}

// MARK: - Flow Layout for Tag Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
