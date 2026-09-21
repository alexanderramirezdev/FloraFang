//
//  PaywallSheet.swift
//  FloraFang
//
//  The one-time unlock screen. Presented whenever a gated extra is tapped
//  while locked, never as an interruption on launch or on the camera/scan
//  flow — nothing safety related routes through this file.
//
//  Each feature gets a small concrete preview alongside its description
//  ("show, don't tell") instead of relying on a free trial to prove value.
//  Considered a trial and decided against it: this is a one-time unlock on
//  an occasional-use utility, not a subscription, and of the five gated
//  features only Flora (the chat) really benefits from being experienced
//  rather than described — a static sample exchange covers that instead.
//  The other four (export, ID card, checklist, catalog) are exactly as
//  self-explanatory as anything already free, once you can see one.
//

import SwiftUI
import StoreKit

enum PaywallFeatureKind {
    case chat, export, idCard, checklist, catalog
}

struct PaywallFeature: Identifiable {
    var id: String { title }
    let kind: PaywallFeatureKind
    let symbol: String
    let title: String
    let detail: String
}

enum PaywallCatalog {
    static let features: [PaywallFeature] = [
        PaywallFeature(
            kind: .chat,
            symbol: "sparkles",
            title: "Flora, the field naturalist",
            detail: "Ask follow-up questions about anything you've logged, like habitat, markings, or safe handling, answered on-device."
        ),
        PaywallFeature(
            kind: .export,
            symbol: "square.and.arrow.up",
            title: "Export your field log",
            detail: "Pull your full scan history out as a ZIP with photos and a CSV, yours to keep or hand off."
        ),
        PaywallFeature(
            kind: .idCard,
            symbol: "rectangle.portrait.on.rectangle.portrait",
            title: "Shareable ID cards",
            detail: "Turn any logged observation into a clean image card you can text, post, or save."
        ),
        PaywallFeature(
            kind: .checklist,
            symbol: "checklist",
            title: "Field checklist",
            detail: "Track which spiders and toxic plants you've actually encountered, checklist style."
        ),
        PaywallFeature(
            kind: .catalog,
            symbol: "books.vertical",
            title: "Full species catalog",
            detail: "Browse everything FloraFang can recognize, not just what you've already scanned."
        )
    ]
}

struct PaywallSheet: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var showUnlockCelebration = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        featureList
                        freeForeverNote
                        Spacer(minLength: 4)
                        buttons
                        legal
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Unlock FloraFang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(Palette.lichen)
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { purchases.lastError != nil },
                set: { if !$0 { purchases.lastError = nil } }
            )) {
                Button("OK") { purchases.lastError = nil }
            } message: {
                Text(purchases.lastError ?? "")
            }
            .onChange(of: purchases.isUnlocked) { _, unlocked in
                if unlocked { showUnlockCelebration = true }
            }
            .fullScreenCover(isPresented: $showUnlockCelebration) {
                UnlockCelebrationScreen(onContinue: { dismiss() })
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(Palette.ochre)
            Text("A one-time unlock, not a subscription")
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
            Text("Pay once, keep it forever. No account, no recurring charge.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.lichen)
        }
    }

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(PaywallCatalog.features) { feature in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.moss)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Palette.parchment)
                            Text(feature.detail)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.parchment.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    preview(for: feature.kind)
                        .padding(.leading, 34)
                }
                .padding(12)
                .background(Palette.moss.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private func preview(for kind: PaywallFeatureKind) -> some View {
        switch kind {
        case .chat:            chatPreview
        case .export:          exportPreview
        case .idCard:          idCardPreview
        case .checklist:       checklistPreview
        case .catalog:         catalogPreview
        }
    }

    private var chatPreview: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Is this safe to touch?")
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.parchment)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Palette.lichen.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))

            Text("Non-venomous to humans. Safe to observe — just give it space if it's guarding an egg sac.")
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.parchment)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Palette.moss.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var exportPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 18))
                .foregroundStyle(Palette.ochre)
            VStack(alignment: .leading, spacing: 1) {
                Text("florafang_export.zip")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.parchment)
                Text("Photos + observations.csv")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.lichen)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Palette.bark.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var idCardPreview: some View {
        HStack(spacing: 10) {
            Group {
                if let image = UIImage(named: "ref_wolf_spider") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.bark
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("SPIDER")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.lichen)
                Text("Wolf Spider")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.parchment)
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Palette.ochre)
                    Text("Identified with FloraFang")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Palette.lichen)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Palette.bark.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var checklistPreview: some View {
        VStack(alignment: .leading, spacing: 5) {
            checklistPreviewRow(title: "Wolf Spider", found: true)
            checklistPreviewRow(title: "Black Widow", found: false)
            checklistPreviewRow(title: "Poison Ivy", found: true)
        }
        .padding(8)
        .background(Palette.bark.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func checklistPreviewRow(title: String, found: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 11))
                .foregroundStyle(found ? Palette.moss : Palette.lichen.opacity(0.5))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(found ? Palette.parchment : Palette.lichen)
        }
    }

    private var catalogPreview: some View {
        HStack(spacing: 8) {
            catalogChip(name: "Bird", image: "ref_sub_bird_northern_cardinal")
            catalogChip(name: "Lizard", image: "ref_sub_lizard_gila_monster")
            catalogChip(name: "Plant", image: "ref_poison_ivy_oak")
            VStack(spacing: 2) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.lichen)
                Text("more")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Palette.lichen)
            }
            .frame(width: 40, height: 40)
            Spacer(minLength: 0)
        }
    }

    private func catalogChip(name: String, image: String) -> some View {
        VStack(spacing: 3) {
            Group {
                if let uiImage = UIImage(named: image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.bark
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(name)
                .font(.system(size: 8.5))
                .foregroundStyle(Palette.lichen)
        }
    }

    private var freeForeverNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Palette.safe)
            Text("Hazard identification, the exposure checklist, and exporting an exposure incident report stay free forever, unlocked or not.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Palette.safe.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.safe.opacity(0.35), lineWidth: 1))
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    isWorking = true
                    await purchases.purchase()
                    isWorking = false
                }
            } label: {
                HStack {
                    if isWorking || purchases.isPurchasing {
                        ProgressView().tint(Color.black)
                    }
                    Text(purchases.isLoadingProducts ? "Loading…" : "Unlock for \(purchases.priceText)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Palette.ochre, in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(Color.black)
            }
            .disabled(isWorking || purchases.isPurchasing || purchases.unlockProduct == nil)

            Button {
                Task {
                    isWorking = true
                    await purchases.restorePurchases()
                    isWorking = false
                }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.lichen)
            }
            .disabled(isWorking || purchases.isPurchasing)
        }
    }

    private var legal: some View {
        Text("One-time purchase, billed to your Apple ID. In TestFlight this uses Apple's sandbox and never charges real money.")
            .font(.system(size: 10))
            .foregroundStyle(Palette.lichen.opacity(0.7))
            .multilineTextAlignment(.leading)
    }
}

// MARK: Reusable locked-feature card

/// Drop-in replacement for a gated section's interactive content. States
/// what the feature is and why it's locked, with a single tap opening the
/// paywall — never a dead end that just disables a control silently.
struct PremiumLockCard: View {
    let title: String
    let message: String
    var symbol: String = "lock.fill"
    var onUnlockTapped: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ochre)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.parchment)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onUnlockTapped) {
                Text("Unlock")
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Palette.ochre, in: Capsule())
                    .foregroundStyle(Color.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }
}
