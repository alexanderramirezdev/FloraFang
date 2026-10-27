//
//  DuoSpread.swift
//  FloraFang
//
//  iPhone Duo's unfolded inner display, treated as a two-page spread.
//
//  Unfolded, the Duo runs every app in landscape at about 950 x 670pt,
//  portrait-only apps included, and the fold sits down the middle like
//  the gutter of a book. FloraFang uses it as two pages: the
//  viewfinder stays live on the left page and each identification lands
//  on the right page, so the next scan is one tap away instead of behind
//  a full screen result.
//

import SwiftUI
import SwiftData

extension EnvironmentValues {
    /// True on iPhone Duo's unfolded display. Set once at the root by
    /// `detectsDuoSpread()`, so a screen deep in the hierarchy (or in a
    /// sheet) can tell, whatever its own width happens to be.
    @Entry var isDuoSpread: Bool = false

    /// True on iPhone Duo's outer (folded) display, where the status bar
    /// and tab bar live in a rail down the right edge instead of along the
    /// top and bottom. Content there starts right at the top of the screen.
    @Entry var isDuoOuter: Bool = false
}

extension View {
    /// Measures the window and publishes `isDuoSpread`. Apply at the root.
    func detectsDuoSpread() -> some View {
        modifier(DuoSpreadDetector())
    }
}

private struct DuoSpreadDetector: ViewModifier {
    @State private var isSpread = false
    @State private var isOuter = false

    func body(content: Content) -> some View {
        content
            .environment(\.isDuoSpread, isSpread)
            .environment(\.isDuoOuter, isOuter)
            // The outer display is the only portrait iPhone screen with a
            // system rail down the trailing edge, which shows up as a
            // trailing safe-area inset no other iPhone has in portrait.
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.height > proxy.size.width
                    && proxy.safeAreaInsets.trailing > 30
            } action: { isOuter = $0 }
            // Both dimensions, not just width: a Pro Max in landscape is
            // as wide as the Duo unfolded (about 956pt) but only about
            // 440pt tall, and gets nothing from a two-page layout.
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width >= 760 && proxy.size.height >= 560
            } action: { isSpread = $0 }
    }
}

// MARK: Centered titles

extension View {
    /// A navigation title centered over the content. iOS 27 leads inline
    /// titles at the left edge, which on iPhone Duo leaves them hugging
    /// one side with the system rail on the other, so the screen reads as
    /// lopsided. Keeps `navigationTitle` for the back button and VoiceOver.
    func centeredTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.parchment)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

// MARK: Scan results page

/// The right-hand page before anything has been scanned, or after a result
/// is closed: how to use the spread, then today's finds so far, a running
/// tally of the walk that a full-screen result flow never had room for.
struct ScanResultEmptyPage: View {
    @Query(sort: \FieldEntry.capturedAt, order: .reverse) private var entries: [FieldEntry]

    private var todaysFinds: [FieldEntry] {
        Array(entries.prefix { Calendar.current.isDateInToday($0.capturedAt) }.prefix(6))
    }

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Centered on the page rather than leading: left-set
                    // text on the right-hand page sat pressed against the
                    // fold with the system rail empty beside it.
                    VStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Palette.ochre)
                            .padding(.bottom, 4)
                        Text("IDENTIFICATION")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .tracking(3)
                            .foregroundStyle(Palette.moss)
                        Text("Scan on the left. Read it here.")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.parchment)
                        Text("What it is, how much it matters, and what to do next open on this page, while the viewfinder stays live for the next leaf, stem, or spider.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Palette.parchment.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .frame(maxWidth: .infinity)

                    if !todaysFinds.isEmpty {
                        Divider().overlay(Palette.moss.opacity(0.3))

                        Text("TODAY'S FINDS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Palette.ochre)

                        ForEach(todaysFinds) { entry in
                            findRow(entry)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Centered vertically too while the page is short; scrolls
            // from the top once today's finds fill it.
            .defaultScrollAnchor(.center, for: .alignment)
        }
    }

    private func findRow(_ entry: FieldEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let data = entry.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Palette.surface
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.headline.isEmpty ? entry.rawLabel : entry.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.parchment)
                    .lineLimit(1)
                Text(entry.capturedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.parchment.opacity(0.6))
            }

            Spacer()

            Circle()
                .fill(tint(for: entry.hazard))
                .frame(width: 10, height: 10)
                .accessibilityLabel(entry.hazard.label)
        }
        .accessibilityElement(children: .combine)
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
