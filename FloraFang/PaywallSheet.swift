//
//  PaywallSheet.swift
//  FloraFang
//
//  The one-time unlock screen. Presented whenever a gated extra is tapped
//  while locked, never as an interruption on launch or on the camera/scan
//  flow — nothing safety related routes through this file.
//

import SwiftUI
import StoreKit

struct PaywallFeature: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

enum PaywallCatalog {
    static let features: [PaywallFeature] = [
        PaywallFeature(
            symbol: "sparkles",
            title: "Flora, the field naturalist",
            detail: "Ask follow-up questions about anything you've logged, like habitat, markings, or safe handling, answered on-device."
        ),
        PaywallFeature(
            symbol: "square.and.arrow.up",
            title: "Export your field log",
            detail: "Pull your full scan history out as a ZIP with photos and a CSV, yours to keep or hand off."
        ),
        PaywallFeature(
            symbol: "rectangle.portrait.on.rectangle.portrait",
            title: "Shareable ID cards",
            detail: "Turn any logged observation into a clean image card you can text, post, or save."
        ),
        PaywallFeature(
            symbol: "checklist",
            title: "Field checklist",
            detail: "Track which spiders and toxic plants you've actually encountered, checklist style."
        ),
        PaywallFeature(
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
            }
        }
        .padding(14)
        .background(Palette.moss.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
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
