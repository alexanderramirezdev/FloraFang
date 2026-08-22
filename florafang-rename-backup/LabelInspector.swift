//
//  LabelInspector.swift
//  FloraFang
//
//  Development tool. Shows Vision's full ranked label list, not just the one
//  the catalog happened to match.
//
//  This is the more useful view while tuning Catalog.swift, because it shows
//  you the labels you MISSED. The cascade trace only tells you what hit.
//

import SwiftUI

struct RankedLabel: Identifiable, Hashable {
    let identifier: String
    let confidence: Double
    var id: String { identifier }

    /// Whether Catalog.match would currently catch this label.
    var isMatched: Bool { Catalog.match(rawLabel: identifier) != nil }

    var matchedEntry: String? { Catalog.match(rawLabel: identifier)?.displayName }
}

struct LabelInspectorSheet: View {
    let labels: [RankedLabel]
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Text("Vision's ranked labels. Green means Catalog.match already catches it; grey means it falls through. Grey labels with high confidence are the ones worth adding to matchTerms.")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.lichen)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(labels) { label in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(label.isMatched ? Palette.moss : Palette.lichen.opacity(0.35))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(label.identifier)
                                        .font(.system(size: 12.5, design: .monospaced))
                                        .foregroundStyle(Palette.parchment)
                                    if let matched = label.matchedEntry {
                                        Text("→ \(matched)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Palette.moss)
                                    }
                                }

                                Spacer()

                                Text(String(format: "%.3f", label.confidence))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Palette.lichen)
                            }
                            .padding(.vertical, 3)
                        }

                        if labels.isEmpty {
                            Text("No labels returned.")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.lichen)
                        }

                        Button {
                            UIPasteboard.general.string = labels
                                .map { "\($0.identifier)\t\(String(format: "%.4f", $0.confidence))" }
                                .joined(separator: "\n")
                        } label: {
                            Label("Copy as TSV", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.top, 8)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Raw labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.ochre)
                }
            }
            .toolbarBackground(Palette.bark, for: .navigationBar)
        }
    }
}
