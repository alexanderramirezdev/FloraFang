//
//  OnboardingView.swift
//  FloraFang
//
//  Four splash cards shown on first launch:
//    1. What the app is for (Purpose & offline hazard detection)
//    2. How to use it (Framing, zoom vs close-up, and lighting)
//    3. What it does not do (Safety boundaries, refusal, never says safe to eat)
//    4. Emergency protocol (Call first, exposure intake logging)
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    private let totalPages = 4

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with Skip
                HStack {
                    Spacer()
                    if page < totalPages - 1 {
                        Button("Skip", action: onFinish)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.lichen)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }

                // Cards carousel
                TabView(selection: $page) {
                    pagePurpose.tag(0)
                    pageHowToUse.tag(1)
                    pageWhatItDoesNotDo.tag(2)
                    pageEmergency.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom Action Button
                VStack(spacing: 12) {
                    Button {
                        if page < totalPages - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                        } else {
                            onFinish()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(page < totalPages - 1 ? "NEXT" : "GET STARTED")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.4)
                            if page < totalPages - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.moss, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Palette.parchment)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Page 1: Purpose

    private var pagePurpose: some View {
        cardLayout(
            badge: "WHAT FLORAFANG IS FOR",
            badgeColor: Palette.moss,
            symbol: "leaf.fill",
            symbolColor: Palette.moss,
            title: "Know what's harmful in the wild",
            description: "FloraFang is an offline hazard scanner designed to recognize medically significant spiders and toxic plants before you touch them.",
            points: [
                OnboardingPoint(
                    icon: "exclamationmark.shield.fill",
                    color: Palette.ochre,
                    headline: "Medically Significant Groups",
                    detail: "Specialized models screen specifically for widows (Latrodectus), recluses (Loxosceles), and toxic botanical classes."
                ),
                OnboardingPoint(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    color: Palette.moss,
                    headline: "100% On-Device & Private",
                    detail: "Every scan, feature check, and log runs directly on your iPhone. Works deep in the backcountry with zero signal."
                ),
                OnboardingPoint(
                    icon: "book.closed.fill",
                    color: Palette.lichen,
                    headline: "Persistent Field Notebook",
                    detail: "Every observation is saved locally with your location, notes, and photos for later review or community confirmation."
                )
            ]
        )
    }

    // MARK: - Page 2: How to Use

    private var pageHowToUse: some View {
        cardLayout(
            badge: "HOW TO USE THE APP",
            badgeColor: Palette.ochre,
            symbol: "camera.viewfinder",
            symbolColor: Palette.ochre,
            title: "Fill the square and tap to focus",
            description: "To give on-device models the best chance to spot fine diagnostic markings, follow three simple rules:",
            points: [
                OnboardingPoint(
                    icon: "plus.magnifyingglass",
                    color: Palette.ochre,
                    headline: "Use the Zoom Slider",
                    detail: "Do not move too close — phone lenses cannot focus below ~10 cm. Stand back and use the slider to zoom until the subject fills the square."
                ),
                OnboardingPoint(
                    icon: "sun.max.fill",
                    color: Palette.parchment,
                    headline: "Steady Ambient Lighting",
                    detail: "Harsh flash washes out fine eye patterns and violin head markings. Soft, even daylight produces the most reliable classifications."
                ),
                OnboardingPoint(
                    icon: "arrow.up.and.down.and.sparkles",
                    color: Palette.moss,
                    headline: "Key Angles Matter",
                    detail: "A shot from directly above captures dorsal markings. If safely possible, viewing the underside of the abdomen is the deciding factor."
                )
            ]
        )
    }

    // MARK: - Page 3: Boundaries

    private var pageWhatItDoesNotDo: some View {
        cardLayout(
            badge: "WHAT IT NEVER DOES",
            badgeColor: Palette.rust,
            symbol: "exclamationmark.triangle.fill",
            symbolColor: Palette.rust,
            title: "Strict safety boundaries and refusal",
            description: "Most apps guess blindly and present uncertain answers as fact. FloraFang is built around calibrated honesty:",
            points: [
                OnboardingPoint(
                    icon: "fork.knife.circle.fill",
                    color: Palette.rust,
                    headline: "Never Declares Plants 'Safe to Eat'",
                    detail: "Visual appearance alone cannot confirm edibility. FloraFang will never declare a wild plant safe for human or animal consumption."
                ),
                OnboardingPoint(
                    icon: "xmark.shield.fill",
                    color: Palette.rust,
                    headline: "No Toxic Match ≠ Harmless",
                    detail: "Finding no toxic match only means the specimen did not match our high-confidence hazard list — not that it is safe."
                ),
                OnboardingPoint(
                    icon: "questionmark.circle.fill",
                    color: Palette.ochre,
                    headline: "Refuses Rather Than Guesses",
                    detail: "When lighting, angles, or diagnostic markings are ambiguous, the app refuses to guess and tells you what to photograph next."
                )
            ]
        )
    }

    // MARK: - Page 4: Emergency Protocol

    private var pageEmergency: some View {
        cardLayout(
            badge: "EMERGENCY PROTOCOL",
            badgeColor: Palette.rust,
            symbol: "cross.case.fill",
            symbolColor: Palette.rust,
            title: "If something is eaten, call first",
            description: "FloraFang is not an emergency medical service and does not provide bite, sting, or symptom treatments.",
            points: [
                OnboardingPoint(
                    icon: "phone.fill",
                    color: Palette.rust,
                    headline: "Do Not Wait for a Scan",
                    detail: "Call Poison Control (1-800-222-1222) or ASPCA Pet Poison ((888) 426-4435) immediately while opening the app."
                ),
                OnboardingPoint(
                    icon: "list.clipboard.fill",
                    color: Palette.ochre,
                    headline: "Exposure Intake Checklist",
                    detail: "The Exposure tab helps you log weight, time, part eaten, and signs so you have exact details ready for the specialist."
                ),
                OnboardingPoint(
                    icon: "clock.badge.checkmark.fill",
                    color: Palette.moss,
                    headline: "Saved Incident Records",
                    detail: "Saved exposure reports are preserved in your local incident log so you can easily reference or share them with ER doctors or vets."
                )
            ]
        )
    }

    // MARK: - Card Layout Helper

    private func cardLayout(
        badge: String,
        badgeColor: Color,
        symbol: String,
        symbolColor: Color,
        title: String,
        description: String,
        points: [OnboardingPoint]
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header badge + icon
                HStack {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(badgeColor.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(badgeColor.opacity(0.6), lineWidth: 1))
                        .foregroundStyle(Palette.parchment)

                    Spacer()

                    Image(systemName: symbol)
                        .font(.system(size: 24))
                        .foregroundStyle(symbolColor)
                }
                .padding(.top, 4)

                // Title
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.parchment)
                    .fixedSize(horizontal: false, vertical: true)

                // Subtitle / Intro
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.parchment.opacity(0.85))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)

                // Structured bullet points
                VStack(spacing: 10) {
                    ForEach(points) { pt in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: pt.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(pt.color)
                                .frame(width: 22, height: 22)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(pt.headline)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.parchment)
                                Text(pt.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.lichen)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 8)
        }
    }
}

struct OnboardingPoint: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let headline: String
    let detail: String
}
