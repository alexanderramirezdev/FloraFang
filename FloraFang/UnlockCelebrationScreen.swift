//
//  UnlockCelebrationScreen.swift
//  FloraFang
//
//  Shown once, immediately after a successful purchase (or a successful
//  restore), so "you paid for something" resolves into "here's exactly
//  what you can now do" instead of just the paywall quietly closing.
//  Reuses PaywallCatalog.features (PaywallSheet.swift) as the single
//  source of truth for what's gated, so this can never drift out of sync
//  with what the paywall itself advertises.
//

import SwiftUI

struct UnlockCelebrationScreen: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    featureList
                    Spacer(minLength: 4)
                    continueButton
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.ochre)
            Text("You're unlocked")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
            Text("Thanks for supporting FloraFang. Everything below is yours now, forever, no extra steps.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(PaywallCatalog.features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.safe)
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

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Start exploring")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Palette.ochre, in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(Color.black)
        }
    }
}
