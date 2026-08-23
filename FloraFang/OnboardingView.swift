//
//  OnboardingView.swift
//  FloraFang
//
//  Three screens, shown once.
//
//  The second one is the reason this exists. An app whose entire premise is
//  calibrated honesty about uncertainty cannot leave that unsaid until the
//  user hits their first refusal and reads it as a bug. Telling people up
//  front what the app will not do is the feature, not a disclaimer.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    pageOne.tag(0)
                    pageTwo.tag(1)
                    pageThree.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < 2 ? "NEXT" : "START")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.moss, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(Palette.parchment)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)

                if page < 2 {
                    Button("Skip", action: onFinish)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.lichen)
                        .padding(.bottom, 18)
                }
            }
        }
    }

    // MARK: - Pages

    private var pageOne: some View {
        page(
            symbol: "camera.viewfinder",
            title: "Point at what worries you",
            body: "FloraFang looks at a spider or a plant and tells you whether it belongs to a group that can hurt you. Fill the square with your subject and tap the shutter. Everything runs on your iPhone, with no account and no network."
        )
    }

    private var pageTwo: some View {
        page(
            symbol: "questionmark.circle",
            title: "It will tell you when it does not know",
            body: "Most apps in this category name a species at low confidence and present it as fact. This one refuses instead, and tells you how to get a better answer.\n\nTwo things it will never do. It will never say a plant is safe to eat, at any confidence. And when it finds no toxic match, that means no match was found, not that the plant is safe. Most toxic plants are not on its list."
        )
    }

    private var pageThree: some View {
        page(
            symbol: "cross.case",
            title: "If something has been eaten, call first",
            body: "The Exposure tab puts poison control one tap away and helps you give them what they will ask for. Do not wait on an identification. Call, then let the app help you describe what happened.\n\nFloraFang is not a safety authority and not medical advice."
        )
    }

    private func page(symbol: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()

            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(Palette.ochre)

            Text(title)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(Palette.parchment.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
