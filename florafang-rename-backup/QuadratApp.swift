//
//  QuadratApp.swift
//  Quadrat
//

import SwiftUI
import SwiftData

@main
struct QuadratApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // SwiftData sets up the whole persistence stack from this one line.
        // Think of it like registering a DbContext in Program.cs — everything
        // downstream gets it injected via the environment.
        .modelContainer(for: FieldEntry.self)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            CameraScreen()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            FieldLogScreen()
                .tabItem { Label("Field Log", systemImage: "book.closed") }
        }
        .tint(Palette.ochre)
        .preferredColorScheme(.dark)
    }
}

/// Central place for the visual tokens so screens don't drift apart.
enum Palette {
    static let bark      = Color(red: 0.086, green: 0.102, blue: 0.075) // #161A13
    static let moss      = Color(red: 0.247, green: 0.361, blue: 0.247) // #3F5C3F
    static let ochre     = Color(red: 0.788, green: 0.498, blue: 0.122) // #C97F1F
    static let parchment = Color(red: 0.910, green: 0.863, blue: 0.753) // #E8DCC0
    static let rust      = Color(red: 0.549, green: 0.227, blue: 0.169) // #8C3A2B
    static let lichen    = Color(red: 0.490, green: 0.541, blue: 0.435) // #7D8A6F
}
