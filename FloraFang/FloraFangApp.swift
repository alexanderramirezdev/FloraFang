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
    @AppStorage("app_season_setting") private var seasonSetting = "auto"
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraScreen()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
                .tag(0)

            FieldLogScreen()
                .tabItem { Label("Field Log", systemImage: "book.closed") }
                .tag(1)

            // A tab rather than something tucked behind a menu. In an actual
            // poisoning nobody hunts for a feature, and a permanent tab costs
            // one slot to make it findable without thinking.
            EmergencyScreen()
                .tabItem { Label("Exposure", systemImage: "cross.case") }
                .tag(2)
        }
        .tint(Palette.ochre)
        .preferredColorScheme(.dark)
    }
}

// MARK: Seasonal Color System

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

    public var moodDescription: String {
        switch self {
        case .spring: return "Sprout clover, daffodil gold, and dewy botanical moss slate."
        case .summer: return "Lush emerald canopy, blazing sunflower amber, and deep shade."
        case .autumn: return "Smoky cedar peat, golden maple olive, and fiery harvest pumpkin."
        case .winter: return "Frosted arctic navy, crystalline glacial teal, and warm hearth gold."
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
    public let bark: Color       // Background: rich organic botanical slate (lifted from pitch black)
    public let moss: Color       // Primary accent, brand tone, safe indicator
    public let ochre: Color      // Attention, highlights, actionable buttons, caution indicator
    public let parchment: Color  // High legibility text, primary labels
    public let rust: Color       // Urgent warnings, alerts, avoid indicator
    public let lichen: Color     // Subtitle, secondary captions, borders, unknown indicator

    public static let spring = SeasonTheme(
        season: .spring,
        bark: Color(red: 0.043, green: 0.094, blue: 0.071),      // Deep sprout moss slate (#0A1712)
        moss: Color(red: 0.176, green: 0.831, blue: 0.471),      // Radiant spring clover (#2CD378)
        ochre: Color(red: 1.000, green: 0.820, blue: 0.231),     // Sunny daffodil gold (#FFD13A)
        parchment: Color(red: 0.957, green: 0.984, blue: 0.965), // Crisp clover ivory (#F4FAF6)
        rust: Color(red: 1.000, green: 0.302, blue: 0.259),      // Electric coral berry (#FF4D42)
        lichen: Color(red: 0.494, green: 0.878, blue: 0.639)     // Dewy apple mint sage (#7DDFA2)
    )

    public static let summer = SeasonTheme(
        season: .summer,
        bark: Color(red: 0.027, green: 0.090, blue: 0.078),      // Dense sunlit canopy slate (#061613)
        moss: Color(red: 0.020, green: 0.820, blue: 0.480),      // Intense radiant emerald (#05D17A)
        ochre: Color(red: 1.000, green: 0.690, blue: 0.125),     // Blazing solar sunflower (#FFAF1F)
        parchment: Color(red: 0.980, green: 0.984, blue: 0.969), // Sunlit bleached ivory (#F9FAF7)
        rust: Color(red: 1.000, green: 0.200, blue: 0.294),      // Wild strawberry crimson (#FF334A)
        lichen: Color(red: 0.369, green: 0.918, blue: 0.831)     // Sunlit silver eucalyptus (#5EEAD3)
    )

    public static let autumn = SeasonTheme(
        season: .autumn,
        bark: Color(red: 0.102, green: 0.063, blue: 0.035),      // Roasted cedar and peat bark (#1A1008)
        moss: Color(red: 0.518, green: 0.800, blue: 0.086),      // Golden maple and cedar moss (#84CC15)
        ochre: Color(red: 1.000, green: 0.478, blue: 0.000),     // Fiery harvest pumpkin (#FF7900)
        parchment: Color(red: 1.000, green: 0.957, blue: 0.902), // Warm pressed linen (#FFF4E6)
        rust: Color(red: 0.902, green: 0.224, blue: 0.000),      // Blazing sumac copper (#E63900)
        lichen: Color(red: 0.878, green: 0.663, blue: 0.427)     // Toasted hazel and cedar dust (#DFA96C)
    )

    public static let winter = SeasonTheme(
        season: .winter,
        bark: Color(red: 0.031, green: 0.063, blue: 0.094),      // Frosted arctic midnight navy (#071017)
        moss: Color(red: 0.133, green: 0.827, blue: 0.933),      // Crystalline glacial teal (#21D2ED)
        ochre: Color(red: 1.000, green: 0.663, blue: 0.302),     // Warm hearth candle gold (#FFA94D)
        parchment: Color(red: 0.941, green: 0.976, blue: 1.000), // Brilliant snowdrift white (#EFF8FF)
        rust: Color(red: 1.000, green: 0.165, blue: 0.333),      // Frosted winterberry (#FF2A54)
        lichen: Color(red: 0.576, green: 0.773, blue: 0.992)     // Glacial arctic mist (#92C5FC)
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
