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

    private var activeTheme: SeasonTheme {
        SeasonTheme.theme(for: seasonSetting)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraScreen(isActive: selectedTab == 0)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
                .tag(0)

            // Center thumb target for fastest access during urgent incidents
            EmergencyScreen()
                .tabItem { Label("Exposure", systemImage: "cross.case") }
                .tag(1)

            FieldLogScreen()
                .tabItem { Label("Log", systemImage: "book.closed") }
                .tag(2)
        }
        .tint(activeTheme.accent)
        .preferredColorScheme(.dark)
        .onChange(of: seasonSetting, initial: true) { _, newSetting in
            let theme = SeasonTheme.theme(for: newSetting)
            updateTabBarAppearance(tint: theme.accent)
        }
    }

    private func updateTabBarAppearance(tint: Color) {
        let uiColor = UIColor(tint)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = uiColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: uiColor]
        appearance.inlineLayoutAppearance.selected.iconColor = uiColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: uiColor]
        appearance.compactInlineLayoutAppearance.selected.iconColor = uiColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: uiColor]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = uiColor
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
        case .autumn: return "Autumn Harvest"
        case .winter: return "Winter Stillness"
        }
    }

    public var moodDescription: String {
        switch self {
        case .spring:
            return "Golden honeybees and warm morning sunlight return to the waking wild. Bright green shoots break through thawed earth, framed by soft cherry blossom petals."
        case .summer:
            return "Peak forest canopy and high vitality. Sunlit leaves, dense emerald cover, sun breaking through the branches, and cool deep shade on the forest floor."
        case .autumn:
            return "The turn of the wild and golden harvest. Warm pumpkin hues, turning leaves, rich amber gold, and cozy roasted earth as the canopy prepares for rest."
        case .winter:
            return "Somber stillness and quiet clarity. Pale morning ice, frost dusted branches, cold grey skies, and calm winter dormancy before the cycle begins again."
        }
    }

    public static var current: Season {
        let calendar = Calendar.current
        let now = Date.now
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let monthDay = month * 100 + day

        switch monthDay {
        case 320..<621:
            return .spring
        case 621..<922:
            return .summer
        case 922..<1221:
            return .autumn
        default:
            return .winter
        }
    }
}

public struct SeasonTheme {
    public let season: Season
    public let bg: Color
    public let surface: Color
    public let accent: Color
    public let accentAlt: Color
    public let warm: Color
    public let cool: Color
    public let text: Color
    public let secondary: Color

    public let safe: Color
    public let warn: Color
    public let danger: Color

    // Backward-compatible accessors
    public var bark: Color { bg }
    public var cardBackground: Color { surface }
    public var moss: Color { accent }
    public var ochre: Color { accentAlt }
    public var parchment: Color { text }
    public var rust: Color { danger }
    public var lichen: Color { secondary }

    // Spring: blossom, bees returning, sun coming back, new life
    public static let spring = SeasonTheme(
        season: .spring,
        bg: Color(hex: "122017"),
        surface: Color(hex: "1B3023"),
        accent: Color(hex: "F08CB4"),
        accentAlt: Color(hex: "E8C15A"),
        warm: Color(hex: "C77FA0"),
        cool: Color(hex: "7FA35C"),
        text: Color(hex: "F7C8DD"),
        secondary: Color(hex: "C99FB0"),
        safe: Color(hex: "5BC46A"),
        warn: Color(hex: "F5C842"),
        danger: Color(hex: "E8503F")
    )

    // Summer: all shades of green, sun through the canopy
    public static let summer = SeasonTheme(
        season: .summer,
        bg: Color(hex: "0C1408"),
        surface: Color(hex: "152012"),
        accent: Color(hex: "9BE04F"),
        accentAlt: Color(hex: "D9E85C"),
        warm: Color(hex: "6E9C34"),
        cool: Color(hex: "3E6B2C"),
        text: Color(hex: "E9F2DC"),
        secondary: Color(hex: "8FA97C"),
        safe: Color(hex: "3DBF5C"),
        warn: Color(hex: "FFD426"),
        danger: Color(hex: "F0392B")
    )

    // Autumn: pumpkin, leaves turning, cozy
    public static let autumn = SeasonTheme(
        season: .autumn,
        bg: Color(hex: "150F0A"),
        surface: Color(hex: "1E1610"),
        accent: Color(hex: "F26A1B"),
        accentAlt: Color(hex: "E8A93C"),
        warm: Color(hex: "9A8B3C"),
        cool: Color(hex: "6B7F3A"),
        text: Color(hex: "F0E2CE"),
        secondary: Color(hex: "A89078"),
        safe: Color(hex: "6BB258"),
        warn: Color(hex: "F2BC33"),
        danger: Color(hex: "D93A22")
    )

    // Winter: grey, still, somber but not dead
    public static let winter = SeasonTheme(
        season: .winter,
        bg: Color(hex: "0E1216"),
        surface: Color(hex: "171D22"),
        accent: Color(hex: "A8C4D6"),
        accentAlt: Color(hex: "8FA6B5"),
        warm: Color(hex: "7C8894"),
        cool: Color(hex: "5E6B75"),
        text: Color(hex: "E4EBF0"),
        secondary: Color(hex: "8A98A3"),
        safe: Color(hex: "6FAF7A"),
        warn: Color(hex: "E8C55C"),
        danger: Color(hex: "E0453C")
    )

    public static func theme(for setting: String) -> SeasonTheme {
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

    public static var active: SeasonTheme {
        let setting = UserDefaults.standard.string(forKey: "app_season_setting") ?? "auto"
        return theme(for: setting)
    }
}

/// Central visual design tokens.
/// Dynamically updates background, surface, accents, and warning colors according
/// to the natural calendar season or user preference.
enum Palette {
    static var currentTheme: SeasonTheme { SeasonTheme.active }

    static var bark: Color           { currentTheme.bg }
    static var surface: Color        { currentTheme.surface }
    static var cardBackground: Color { currentTheme.surface }
    static var accent: Color         { currentTheme.accent }
    static var accentAlt: Color      { currentTheme.accentAlt }
    static var warm: Color           { currentTheme.warm }
    static var cool: Color           { currentTheme.cool }
    static var parchment: Color      { currentTheme.text }
    static var lichen: Color         { currentTheme.secondary }

    // Warning / Hazard tokens
    static var safe: Color           { currentTheme.safe }
    static var warn: Color           { currentTheme.warn }
    static var danger: Color         { currentTheme.danger }

    // Standard tokens mapped to seasonal accent system
    static var moss: Color           { currentTheme.accent }
    static var ochre: Color          { currentTheme.accentAlt }
    static var rust: Color           { currentTheme.danger }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch clean.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
