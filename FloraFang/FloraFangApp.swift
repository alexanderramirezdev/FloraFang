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
        .modelContainer(for: [FieldEntry.self, ExposureIncident.self])
    }
}

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("app_season_setting") private var seasonSetting = "auto"

    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabs()
                    .id(seasonSetting)
            } else {
                OnboardingView { hasSeenOnboarding = true }
                    .id(seasonSetting)
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

// MARK: - Seasonal Color System

public enum Season: String, CaseIterable, Identifiable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .autumn: return "leaf.arrow.triangle.circlepath"
        case .winter: return "snowflake"
        }
    }

    public var moodTitle: String {
        switch self {
        case .spring: return "Spring Awakening"
        case .summer: return "Summer Canopy"
        case .autumn: return "Autumn Cedar"
        case .winter: return "Winter Spruce"
        }
    }

    public static var current: Season {
        let month = Calendar.current.component(.month, from: .now)
        switch month {
        case 3...5:  return .spring
        case 6...8:  return .summer
        case 9...11: return .autumn
        default:     return .winter
        }
    }
}

public struct SeasonTheme {
    public let season: Season
    public let bark: Color       // Background - rich organic botanical slate (lifted from pitch black)
    public let moss: Color       // Primary accent / brand tone
    public let ochre: Color      // Attention / highlights / actionable buttons
    public let parchment: Color  // High-legibility text / primary labels
    public let rust: Color       // Urgent warnings / alerts
    public let lichen: Color     // Subtitle / secondary captions / borders

    public static let spring = SeasonTheme(
        season: .spring,
        bark: Color(red: 0.075, green: 0.118, blue: 0.090),      // Fresh deep sprout slate
        moss: Color(red: 0.200, green: 0.520, blue: 0.345),      // Fresh spring fern moss
        ochre: Color(red: 0.910, green: 0.655, blue: 0.210),     // Daffodil & meadow amber
        parchment: Color(red: 0.950, green: 0.970, blue: 0.945), // Crisp white clover ivory
        rust: Color(red: 0.790, green: 0.280, blue: 0.230),      // Sprouting berry red
        lichen: Color(red: 0.575, green: 0.670, blue: 0.610)     // Dewy leaf sage
    )

    public static let summer = SeasonTheme(
        season: .summer,
        bark: Color(red: 0.068, green: 0.112, blue: 0.092),      // Deep lush canopy slate
        moss: Color(red: 0.185, green: 0.495, blue: 0.335),      // Vibrant emerald canopy
        ochre: Color(red: 0.925, green: 0.630, blue: 0.165),     // Sunflower golden amber
        parchment: Color(red: 0.960, green: 0.975, blue: 0.950), // Sunlit botanical ivory
        rust: Color(red: 0.810, green: 0.265, blue: 0.210),      // Wild strawberry red
        lichen: Color(red: 0.560, green: 0.665, blue: 0.600)     // Warm silver eucalyptus
    )

    public static let autumn = SeasonTheme(
        season: .autumn,
        bark: Color(red: 0.095, green: 0.095, blue: 0.080),      // Warm roasted cedar & peat slate
        moss: Color(red: 0.265, green: 0.435, blue: 0.300),      // Golden cedar moss
        ochre: Color(red: 0.875, green: 0.540, blue: 0.145),     // Harvest amber & golden oak
        parchment: Color(red: 0.965, green: 0.955, blue: 0.925), // Warm pressed linen ivory
        rust: Color(red: 0.780, green: 0.265, blue: 0.190),      // Autumn sumac & bittersweet red
        lichen: Color(red: 0.640, green: 0.625, blue: 0.570)     // Dried lichen & hazel sage
    )

    public static let winter = SeasonTheme(
        season: .winter,
        bark: Color(red: 0.078, green: 0.096, blue: 0.110),      // Frosted spruce slate
        moss: Color(red: 0.195, green: 0.400, blue: 0.355),      // Deep frosted pine & blue spruce
        ochre: Color(red: 0.845, green: 0.530, blue: 0.225),     // Winter sol amber & rowan berry
        parchment: Color(red: 0.945, green: 0.960, blue: 0.968), // Frosted snow ivory
        rust: Color(red: 0.755, green: 0.235, blue: 0.220),      // Winterberry crimson
        lichen: Color(red: 0.560, green: 0.620, blue: 0.630)     // Glacial silver lichen
    )

    public static var active: SeasonTheme {
        let setting = UserDefaults.standard.string(forKey: "app_season_setting") ?? "auto"
        let season: Season
        if setting == "auto" {
            season = Season.current
        } else {
            season = Season(rawValue: setting) ?? Season.current
        }
        switch season {
        case .spring: return spring
        case .summer: return summer
        case .autumn: return autumn
        case .winter: return winter
        }
    }
}

/// Central place for visual tokens.
/// Dynamically shifts palette hues according to the current natural season
/// or user override, keeping the app atmospheric, high-contrast, and lifted from pitch black.
enum Palette {
    static var currentTheme: SeasonTheme { SeasonTheme.active }

    static var bark: Color      { currentTheme.bark }
    static var moss: Color      { currentTheme.moss }
    static var ochre: Color     { currentTheme.ochre }
    static var parchment: Color { currentTheme.parchment }
    static var rust: Color      { currentTheme.rust }
    static var lichen: Color    { currentTheme.lichen }
}
