//
//  ResultScreen.swift
//  Quadrat
//

import SwiftUI

struct ResultScreen: View {
    let assessment: Assessment
    let image: UIImage?
    let trace: [String]
    let onSave: (String) -> Void
    let onDiscard: () -> Void

    @State private var note = ""
    @State private var showTrace = false

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 14) {
                        headline
                        hazardBox
                        if !assessment.ruledOut.isEmpty { ruledOutBox }
                        notes
                        noteField
                        buttons
                        traceToggle
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Palette.moss
                }
            }
            .frame(height: 230)
            .clipped()

            Button(action: onDiscard) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Palette.parchment)
                    .padding(9)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(14)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(assessment.group.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.lichen)
                Spacer()
                Text(assessment.tier.rawValue)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.lichen.opacity(0.75))
            }

            Text(assessment.headline)
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)

            // Deliberately no confidence number on a refusal. A percentage next
            // to "couldn't determine" reads as partial certainty, which is
            // exactly the wrong takeaway.
            if !assessment.isRefusal {
                Text("\(Int(assessment.confidence * 100))% confidence")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)
            }
        }
    }

    // MARK: - Hazard

    private var hazardBox: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: assessment.hazard.symbol)
                .foregroundStyle(hazardTint)
            VStack(alignment: .leading, spacing: 3) {
                Text(assessment.hazard.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hazardTint)
                Text(assessment.hazardNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(hazardTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hazardTint.opacity(0.5), lineWidth: 1))
    }

    /// The differentiator: state plainly what was excluded.
    private var ruledOutBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RULED OUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            ForEach(assessment.ruledOut, id: \.self) { item in
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
        switch assessment.hazard {
        case .safe:    return Palette.moss
        case .caution: return Palette.ochre
        case .avoid:   return Palette.rust
        case .unknown: return Palette.lichen
        }
    }

    // MARK: - Notes

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            if assessment.isRefusal {
                Text("TO GET A BETTER ANSWER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.lichen)
            }

            ForEach(assessment.fieldNotes, id: \.self) { line in
                HStack(alignment: .top, spacing: 7) {
                    Text("—").foregroundStyle(Palette.ochre)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.turn.down.right").font(.system(size: 11))
                Text(assessment.nextStep).font(.system(size: 11.5))
            }
            .foregroundStyle(Palette.lichen)
            .padding(.top, 4)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YOUR NOTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            TextField("where you found it, what it was doing…", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.parchment)
                .padding(9)
                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var buttons: some View {
        VStack(spacing: 9) {
            Button { onSave(note) } label: {
                Text("ADD TO FIELD LOG")
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.parchment)
            }
            Button("Discard", action: onDiscard)
                .font(.system(size: 12))
                .foregroundStyle(Palette.lichen)
        }
        .padding(.top, 4)
    }

    /// Developer affordance. Shows which tiers ran and what each said — this is
    /// what you'll read constantly while calibrating the gate.
    private var traceToggle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation { showTrace.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showTrace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                    Text("cascade trace")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(Palette.lichen.opacity(0.7))
            }

            if showTrace {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(trace, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.lichen.opacity(0.8))
                    }
                    Text("label: \(assessment.rawLabel)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.lichen.opacity(0.6))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.top, 8)
    }
}
