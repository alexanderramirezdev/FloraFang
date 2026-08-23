//
//  FloraFangApp.swift
//  FloraFang
//

import SwiftUI
import SwiftData

@main
struct FloraFangApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: FieldEntry.self)
    }
}

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabs()
            } else {
                OnboardingView { hasSeenOnboarding = true }
            }
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            CameraScreen()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            FieldLogScreen()
                .tabItem { Label("Field Log", systemImage: "book.closed") }

            // A tab rather than something tucked behind a menu. In an actual
            // poisoning nobody hunts for a feature, and a permanent tab costs
            // one slot to make it findable without thinking.
            EmergencyScreen()
                .tabItem { Label("Exposure", systemImage: "cross.case") }
        }
        .tint(Palette.ochre)
        .preferredColorScheme(.dark)
    }
}

/// Central place for the visual tokens so screens do not drift apart.
enum Palette {
    static let bark      = Color(red: 0.086, green: 0.102, blue: 0.075) // #161A13
    static let moss      = Color(red: 0.247, green: 0.361, blue: 0.247) // #3F5C3F
    static let ochre     = Color(red: 0.788, green: 0.498, blue: 0.122) // #C97F1F
    static let parchment = Color(red: 0.910, green: 0.863, blue: 0.753) // #E8DCC0
    static let rust      = Color(red: 0.549, green: 0.227, blue: 0.169) // #8C3A2B
    static let lichen    = Color(red: 0.490, green: 0.541, blue: 0.435) // #7D8A6F
}
