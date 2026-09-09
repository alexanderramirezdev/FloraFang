//
//  SeasonalAtmosphereView.swift
//  FloraFang
//
//  Atmospheric seasonal ambient background layer.
//  Renders subtle drifting organic elements behind content
//  without interfering with touches or content legibility.
//

import SwiftUI

public struct SeasonalAtmosphereView: View {
    @AppStorage("app_season_setting") private var seasonSetting = "auto"
    @AppStorage("autumn_visitor_setting") private var autumnVisitorSetting = "auto"
    @AppStorage("winter_holiday_setting") private var winterHolidaySetting = "auto"
    @AppStorage("spring_holiday_setting") private var springHolidaySetting = "auto"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        let theme = SeasonTheme.theme(for: seasonSetting)

        GeometryReader { geometry in
            ZStack {
                switch theme.season {
                case .spring:
                    springAtmosphere(in: geometry.size, theme: theme)
                case .summer:
                    summerAtmosphere(in: geometry.size, theme: theme)
                case .autumn:
                    autumnAtmosphere(in: geometry.size, theme: theme)
                case .winter:
                    winterAtmosphere(in: geometry.size, theme: theme)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Spring Atmosphere (Cherry Blossom Tree, Petals, Honeybees)

    @ViewBuilder
    private func springAtmosphere(in size: CGSize, theme: SeasonTheme) -> some View {
        // Cherry blossom tree anchored to right edge
        SpringCherryBlossomTree()
            .frame(width: size.width, height: size.height)

        // Drifting cherry blossom petals
        ForEach(0..<14, id: \.self) { index in
            DriftingPetalItem(
                index: index,
                totalCount: 14,
                containerSize: size,
                color: theme.accent,
                reduceMotion: reduceMotion
            )
        }

        // Gentle hovering honeybees
        HoneybeeAmbientItem(
            startPoint: CGPoint(x: size.width * 0.18, y: size.height * 0.28),
            driftRange: CGSize(width: 25, height: 18),
            size: 17,
            reduceMotion: reduceMotion
        )

        HoneybeeAmbientItem(
            startPoint: CGPoint(x: size.width * 0.82, y: size.height * 0.42),
            driftRange: CGSize(width: -28, height: 22),
            size: 16,
            reduceMotion: reduceMotion
        )

        HoneybeeAmbientItem(
            startPoint: CGPoint(x: size.width * 0.32, y: size.height * 0.72),
            driftRange: CGSize(width: 22, height: -18),
            size: 15,
            reduceMotion: reduceMotion
        )

        // Easter Spring Holiday Overlay
        let month = Calendar.current.component(.month, from: .now)
        let isEaster = (springHolidaySetting == "easter") || (springHolidaySetting == "auto" && (month == 3 || month == 4))

        if isEaster {
            // Fluffy Easter Bunny perched directly on the tab menu top rim
            EasterBunnyItem(
                position: CGPoint(x: size.width * 0.70, y: size.height - 96 - 18),
                reduceMotion: reduceMotion
            )

            // Decorated pastel Easter eggs nestled beside bunny on the tab menu
            EasterEggsItem(
                position: CGPoint(x: size.width * 0.82, y: size.height - 96 - 12)
            )
        }
    }

    // MARK: Summer Atmosphere (Meadow Grass, Wind Streams, Butterflies)

    @ViewBuilder
    private func summerAtmosphere(in size: CGSize, theme: SeasonTheme) -> some View {
        // Blades of grass along bottom edge
        SummerGrassSilhouette(theme: theme)
            .frame(width: size.width, height: 60)
            .position(x: size.width * 0.5, y: size.height - 30)

        // Gentle warm summer wind streams drifting across meadow
        SummerWindStreamItem(
            startPoint: CGPoint(x: 30, y: size.height * 0.18),
            driftDistance: size.width * 0.50,
            duration: 7.2,
            curveFactor: -8,
            reduceMotion: reduceMotion
        )

        SummerWindStreamItem(
            startPoint: CGPoint(x: size.width * 0.35, y: size.height * 0.28),
            driftDistance: size.width * 0.55,
            duration: 8.5,
            curveFactor: 10,
            reduceMotion: reduceMotion
        )

        SummerWindStreamItem(
            startPoint: CGPoint(x: 40, y: size.height * 0.72),
            driftDistance: size.width * 0.52,
            duration: 7.8,
            curveFactor: -6,
            reduceMotion: reduceMotion
        )

        // Monarch Butterfly fluttering in the upper canopy
        SummerButterflyItem(
            kind: .monarch,
            startPoint: CGPoint(x: size.width * 0.78, y: size.height * 0.22),
            driftRange: CGSize(width: -140, height: 70),
            size: 38,
            flightAngle: -10,
            durationX: 5.4,
            durationY: 7.0,
            reduceMotion: reduceMotion
        )

        // Eastern Tiger Swallowtail Butterfly fluttering mid screen
        SummerButterflyItem(
            kind: .tigerSwallowtail,
            startPoint: CGPoint(x: size.width * 0.18, y: size.height * 0.42),
            driftRange: CGSize(width: 155, height: -60),
            size: 38,
            flightAngle: 12,
            durationX: 6.2,
            durationY: 7.8,
            reduceMotion: reduceMotion
        )

        // Second Monarch Butterfly hovering in the lower meadow
        SummerButterflyItem(
            kind: .monarch,
            startPoint: CGPoint(x: size.width * 0.68, y: size.height * 0.65),
            driftRange: CGSize(width: -120, height: -50),
            size: 32,
            flightAngle: -12,
            durationX: 4.8,
            durationY: 6.4,
            reduceMotion: reduceMotion
        )
    }

    // MARK: Autumn Atmosphere (Canopy Tree, Hedgehog, Falling Leaves, Pumpkin, Holiday Visitors)

    @ViewBuilder
    private func autumnAtmosphere(in size: CGSize, theme: SeasonTheme) -> some View {
        // Full canopy tree with rich turning autumn foliage
        AutumnLeafyCanopyTree()
            .frame(width: size.width, height: size.height)

        // Resident Autumn Hedgehog nestled securely on the thick tree bough
        AutumnHedgehogItem(
            branchPoint: CGPoint(x: size.width - 76, y: size.height - 232),
            reduceMotion: reduceMotion
        )

        // Month and preview logic for October and November visitors
        let month = Calendar.current.component(.month, from: .now)
        let isOctober = (autumnVisitorSetting == "october") || (autumnVisitorSetting == "auto" && month == 10)
        let isNovember = (autumnVisitorSetting == "november") || (autumnVisitorSetting == "auto" && month == 11)

        // Harvest Pumpkin nestled along the left shoulder of the tab menu
        AutumnPumpkinMark(
            size: 68,
            pumpkinColor: theme.accent,
            stemColor: theme.accentAlt,
            isJackOLantern: isOctober
        )
        .position(x: size.width * 0.16, y: size.height - 96 - 16)
        .opacity(0.95)

        // October Halloween Surprise: Bat swooping across sky
        if isOctober {
            OctoberBatItem(
                containerSize: size,
                reduceMotion: reduceMotion
            )

            // October Halloween Surprise: Vintage Silly Symphony dancing skeleton on top of tab menu
            OctoberSkeletonItem(
                containerSize: size,
                groundY: size.height - 96,
                reduceMotion: reduceMotion
            )
        }

        // November Harvest Surprise: Wild Turkey perched proudly on top of tab menu
        if isNovember {
            NovemberTurkeyItem(
                position: CGPoint(x: size.width * 0.32, y: size.height - 96 - 18),
                reduceMotion: reduceMotion
            )
        }

        // Vibrant falling and resting autumn leaves
        ForEach(0..<14, id: \.self) { index in
            DriftingAutumnLeafItem(
                index: index,
                totalCount: 14,
                containerSize: size,
                reduceMotion: reduceMotion
            )
        }
    }

    // MARK: Winter Atmosphere (Bare Frost Tree, Snowy Owl, Crystalline Snowflakes, Christmas Celebration)

    @ViewBuilder
    private func winterAtmosphere(in size: CGSize, theme: SeasonTheme) -> some View {
        // Bare frost dusted tree silhouette relocated from autumn
        WinterBareFrostTreeSilhouette()
            .frame(width: size.width, height: size.height)

        // Christmas Winter Holiday Overlay
        let month = Calendar.current.component(.month, from: .now)
        let day = Calendar.current.component(.day, from: .now)
        let isChristmas = (winterHolidaySetting == "christmas") || (winterHolidaySetting == "auto" && (month == 12 || (month == 1 && day <= 6)))

        if isChristmas {
            // Twinkling fairy lights draped along the frosted tree limbs
            WinterFairyLightsItem(
                containerSize: size,
                reduceMotion: reduceMotion
            )

            // Wrapped holiday gift boxes perched on top of the tab menu
            WinterGiftBoxesItem(
                position: CGPoint(x: size.width * 0.28, y: size.height - 96)
            )
        }

        // Arctic Snowy Owl visiting the frosted branch (wearing Santa hat if Christmas)
        WinterSnowyOwlItem(
            containerSize: size,
            hasSantaHat: isChristmas,
            reduceMotion: reduceMotion
        )

        // 20 crystalline snowflakes drifting quietly down
        ForEach(0..<20, id: \.self) { index in
            DriftingSnowflakeItem(
                index: index,
                totalCount: 20,
                containerSize: size,
                crystalColor: theme.accent,
                reduceMotion: reduceMotion
            )
        }
    }
}

// MARK: Cherry Blossom Petal Shape

public struct CherryBlossomPetalShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.15),
            control1: CGPoint(x: w * 0.05, y: h * 0.75),
            control2: CGPoint(x: 0, y: h * 0.35)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.28),
            control: CGPoint(x: w * 0.35, y: 0)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.15),
            control: CGPoint(x: w * 0.65, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.35),
            control2: CGPoint(x: w * 0.95, y: h * 0.75)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: Drifting Petal Item

private struct DriftingPetalItem: View {
    let index: Int
    let totalCount: Int
    let containerSize: CGSize
    let color: Color
    let reduceMotion: Bool

    @State private var animatedY: CGFloat = 0
    @State private var swayX: CGFloat = 0
    @State private var rotationDeg: Double = 0

    private var initialX: CGFloat {
        let seed = Double((index * 137) % 100) / 100.0
        return containerSize.width * CGFloat(0.08 + seed * 0.84)
    }

    private var initialY: CGFloat {
        let seed = Double((index * 79) % 100) / 100.0
        return containerSize.height * CGFloat(seed)
    }

    private var petalSize: CGFloat {
        let sizes: [CGFloat] = [12, 14, 16, 18, 21, 13, 17]
        return sizes[index % sizes.count]
    }

    private var opacity: Double {
        let opacities = [0.18, 0.24, 0.28, 0.22, 0.32, 0.20, 0.26]
        return opacities[index % opacities.count]
    }

    private var duration: Double {
        return 9.0 + Double(index % 5) * 2.2
    }

    var body: some View {
        CherryBlossomPetalShape()
            .fill(color)
            .opacity(opacity)
            .frame(width: petalSize * 1.1, height: petalSize * 1.5)
            .rotationEffect(.degrees(rotationDeg))
            .position(
                x: initialX + swayX,
                y: reduceMotion ? initialY : (initialY + animatedY).truncatingRemainder(dividingBy: containerSize.height + 40)
            )
            .onAppear {
                rotationDeg = Double((index * 47) % 360)
                guard !reduceMotion else { return }

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    animatedY = containerSize.height + 50
                }
                withAnimation(.easeInOut(duration: 3.5 + Double(index % 3)).repeatForever(autoreverses: true)) {
                    swayX = 16
                    rotationDeg += 40
                }
            }
    }
}

// MARK: Honeybee Ambient Item

private struct HoneybeeAmbientItem: View {
    let startPoint: CGPoint
    let driftRange: CGSize
    let size: CGFloat
    let reduceMotion: Bool

    @State private var currentOffset: CGSize = .zero
    @State private var wingFlutter = false

    var body: some View {
        ZStack {
            // Translucent wings
            HStack(spacing: 1) {
                Ellipse()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size * 0.40, height: size * 0.65)
                    .rotationEffect(.degrees(wingFlutter ? -26 : -10))
                Ellipse()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: size * 0.36, height: size * 0.58)
                    .rotationEffect(.degrees(wingFlutter ? 24 : 8))
            }
            .offset(y: -size * 0.30)

            // Golden striped bee body
            ZStack {
                Capsule()
                    .fill(Palette.ochre)
                    .frame(width: size, height: size * 0.62)

                HStack(spacing: size * 0.16) {
                    Rectangle()
                        .fill(Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.75))
                        .frame(width: size * 0.12, height: size * 0.56)
                    Rectangle()
                        .fill(Color(red: 0.12, green: 0.08, blue: 0.05).opacity(0.75))
                        .frame(width: size * 0.12, height: size * 0.56)
                }
            }
        }
        .position(x: startPoint.x + currentOffset.width, y: startPoint.y + currentOffset.height)
        .opacity(0.85)
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                wingFlutter = true
            }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                currentOffset = driftRange
            }
        }
    }
}

// MARK: Summer Butterfly Views (Monarch and Tiger Swallowtail)

private enum SummerButterflyKind {
    case monarch
    case tigerSwallowtail
}

private struct SummerButterflyItem: View {
    let kind: SummerButterflyKind
    let startPoint: CGPoint
    let driftRange: CGSize
    let size: CGFloat
    let flightAngle: Double
    let durationX: Double
    let durationY: Double
    let reduceMotion: Bool

    @State private var wingScale: CGFloat = 1.0
    @State private var wanderX: CGFloat = 0
    @State private var wanderY: CGFloat = 0
    @State private var flapBob: CGFloat = 0
    @State private var bankAngle: Double = 0

    var body: some View {
        ZStack {
            switch kind {
            case .monarch:
                MonarchButterflyMark(size: size, wingScale: wingScale)
            case .tigerSwallowtail:
                TigerSwallowtailButterflyMark(size: size, wingScale: wingScale)
            }
        }
        .rotationEffect(.degrees(flightAngle + bankAngle))
        .position(x: startPoint.x + wanderX, y: startPoint.y + wanderY + flapBob)
        .onAppear {
            guard !reduceMotion else { return }

            // Continuous rapid wing flutter
            withAnimation(.easeInOut(duration: 0.16 + Double(Int(startPoint.x) % 4) * 0.02).repeatForever(autoreverses: true)) {
                wingScale = 0.28
            }

            // Bobbing motion with flap cycle
            withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                flapBob = -7
            }

            // Wide horizontal swoop across canopy
            withAnimation(.easeInOut(duration: durationX).repeatForever(autoreverses: true)) {
                wanderX = driftRange.width
                bankAngle = driftRange.width > 0 ? 15 : -15
            }

            // Wide vertical drift
            withAnimation(.easeInOut(duration: durationY).repeatForever(autoreverses: true)) {
                wanderY = driftRange.height
            }
        }
    }
}

private struct MonarchButterflyMark: View {
    let size: CGFloat
    let wingScale: CGFloat

    private let orangeDeep = Color(red: 0.92, green: 0.39, blue: 0.08)
    private let orangeBright = Color(red: 0.98, green: 0.55, blue: 0.12)
    private let darkBorder = Color(red: 0.08, green: 0.06, blue: 0.06)

    var body: some View {
        ZStack {
            HStack(spacing: 0.5) {
                monarchWingHalf(isLeft: true)
                    .scaleEffect(x: wingScale, anchor: .trailing)

                monarchWingHalf(isLeft: false)
                    .scaleEffect(x: wingScale, anchor: .leading)
            }

            Capsule()
                .fill(darkBorder)
                .frame(width: size * 0.08, height: size * 0.65)

            HStack(spacing: size * 0.25) {
                Circle().fill(darkBorder).frame(width: 2, height: 2)
                Circle().fill(darkBorder).frame(width: 2, height: 2)
            }
            .offset(y: -size * 0.38)
        }
        .frame(width: size, height: size * 0.75)
    }

    private func monarchWingHalf(isLeft: Bool) -> some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let dir: CGFloat = isLeft ? -1 : 1
            let baseX: CGFloat = isLeft ? w : 0

            var fwPath = Path()
            fwPath.move(to: CGPoint(x: baseX, y: h * 0.4))
            fwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.95, y: h * 0.05),
                control1: CGPoint(x: baseX + dir * w * 0.3, y: h * 0.1),
                control2: CGPoint(x: baseX + dir * w * 0.7, y: 0)
            )
            fwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.75, y: h * 0.65),
                control1: CGPoint(x: baseX + dir * w, y: h * 0.3),
                control2: CGPoint(x: baseX + dir * w * 0.9, y: h * 0.55)
            )
            fwPath.addCurve(
                to: CGPoint(x: baseX, y: h * 0.45),
                control1: CGPoint(x: baseX + dir * w * 0.45, y: h * 0.6),
                control2: CGPoint(x: baseX + dir * w * 0.2, y: h * 0.5)
            )
            fwPath.closeSubpath()

            var hwPath = Path()
            hwPath.move(to: CGPoint(x: baseX, y: h * 0.45))
            hwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.7, y: h * 0.6),
                control1: CGPoint(x: baseX + dir * w * 0.35, y: h * 0.5),
                control2: CGPoint(x: baseX + dir * w * 0.6, y: h * 0.5)
            )
            hwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.45, y: h * 0.95),
                control1: CGPoint(x: baseX + dir * w * 0.75, y: h * 0.8),
                control2: CGPoint(x: baseX + dir * w * 0.6, y: h * 0.95)
            )
            hwPath.addCurve(
                to: CGPoint(x: baseX, y: h * 0.7),
                control1: CGPoint(x: baseX + dir * w * 0.25, y: h * 0.95),
                control2: CGPoint(x: baseX, y: h * 0.85)
            )
            hwPath.closeSubpath()

            context.fill(hwPath, with: .color(orangeDeep))
            context.stroke(hwPath, with: .color(darkBorder), lineWidth: 1.8)

            var hwVeins = Path()
            hwVeins.move(to: CGPoint(x: baseX, y: h * 0.5))
            hwVeins.addLine(to: CGPoint(x: baseX + dir * w * 0.5, y: h * 0.7))
            hwVeins.move(to: CGPoint(x: baseX, y: h * 0.5))
            hwVeins.addLine(to: CGPoint(x: baseX + dir * w * 0.4, y: h * 0.85))
            context.stroke(hwVeins, with: .color(darkBorder), lineWidth: 1.0)

            context.fill(fwPath, with: .color(orangeBright))
            context.stroke(fwPath, with: .color(darkBorder), lineWidth: 1.8)

            var fwVeins = Path()
            fwVeins.move(to: CGPoint(x: baseX, y: h * 0.4))
            fwVeins.addLine(to: CGPoint(x: baseX + dir * w * 0.6, y: h * 0.28))
            fwVeins.move(to: CGPoint(x: baseX, y: h * 0.4))
            fwVeins.addLine(to: CGPoint(x: baseX + dir * w * 0.68, y: h * 0.48))
            context.stroke(fwVeins, with: .color(darkBorder), lineWidth: 1.0)

            var apex = Path()
            apex.move(to: CGPoint(x: baseX + dir * w * 0.75, y: h * 0.15))
            apex.addLine(to: CGPoint(x: baseX + dir * w * 0.95, y: h * 0.05))
            apex.addLine(to: CGPoint(x: baseX + dir * w * 0.88, y: h * 0.35))
            apex.closeSubpath()
            context.fill(apex, with: .color(darkBorder))

            let dot1 = CGRect(x: baseX + dir * w * 0.86 - 1, y: h * 0.14 - 1, width: 2, height: 2)
            let dot2 = CGRect(x: baseX + dir * w * 0.80 - 1, y: h * 0.22 - 1, width: 2, height: 2)
            context.fill(Path(ellipseIn: dot1), with: .color(.white.opacity(0.85)))
            context.fill(Path(ellipseIn: dot2), with: .color(.white.opacity(0.85)))
        }
        .frame(width: size * 0.48, height: size * 0.72)
        .drawingGroup()
    }
}

private struct TigerSwallowtailButterflyMark: View {
    let size: CGFloat
    let wingScale: CGFloat

    private let yellowWarm = Color(red: 0.98, green: 0.84, blue: 0.16)
    private let yellowBright = Color(red: 1.0, green: 0.90, blue: 0.28)
    private let darkBorder = Color(red: 0.08, green: 0.06, blue: 0.06)
    private let blueAccent = Color(red: 0.24, green: 0.52, blue: 0.90)
    private let orangeAccent = Color(red: 0.92, green: 0.40, blue: 0.12)

    var body: some View {
        ZStack {
            HStack(spacing: 0.5) {
                swallowtailWingHalf(isLeft: true)
                    .scaleEffect(x: wingScale, anchor: .trailing)

                swallowtailWingHalf(isLeft: false)
                    .scaleEffect(x: wingScale, anchor: .leading)
            }

            Capsule()
                .fill(darkBorder)
                .frame(width: size * 0.08, height: size * 0.70)
                .overlay(
                    Capsule()
                        .fill(yellowBright)
                        .frame(width: 1.2, height: size * 0.45)
                )

            HStack(spacing: size * 0.25) {
                Circle().fill(darkBorder).frame(width: 2, height: 2)
                Circle().fill(darkBorder).frame(width: 2, height: 2)
            }
            .offset(y: -size * 0.40)
        }
        .frame(width: size, height: size * 0.85)
    }

    private func swallowtailWingHalf(isLeft: Bool) -> some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let dir: CGFloat = isLeft ? -1 : 1
            let baseX: CGFloat = isLeft ? w : 0

            var fwPath = Path()
            fwPath.move(to: CGPoint(x: baseX, y: h * 0.38))
            fwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.98, y: h * 0.04),
                control1: CGPoint(x: baseX + dir * w * 0.3, y: h * 0.08),
                control2: CGPoint(x: baseX + dir * w * 0.7, y: 0)
            )
            fwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.74, y: h * 0.62),
                control1: CGPoint(x: baseX + dir * w * 1.02, y: h * 0.28),
                control2: CGPoint(x: baseX + dir * w * 0.88, y: h * 0.52)
            )
            fwPath.addCurve(
                to: CGPoint(x: baseX, y: h * 0.42),
                control1: CGPoint(x: baseX + dir * w * 0.45, y: h * 0.58),
                control2: CGPoint(x: baseX + dir * w * 0.2, y: h * 0.48)
            )
            fwPath.closeSubpath()

            var hwPath = Path()
            hwPath.move(to: CGPoint(x: baseX, y: h * 0.42))
            hwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.72, y: h * 0.55),
                control1: CGPoint(x: baseX + dir * w * 0.35, y: h * 0.48),
                control2: CGPoint(x: baseX + dir * w * 0.62, y: h * 0.48)
            )
            hwPath.addCurve(
                to: CGPoint(x: baseX + dir * w * 0.54, y: h * 0.82),
                control1: CGPoint(x: baseX + dir * w * 0.76, y: h * 0.68),
                control2: CGPoint(x: baseX + dir * w * 0.66, y: h * 0.78)
            )
            hwPath.addLine(to: CGPoint(x: baseX + dir * w * 0.48, y: h * 0.98))
            hwPath.addLine(to: CGPoint(x: baseX + dir * w * 0.42, y: h * 0.84))

            hwPath.addCurve(
                to: CGPoint(x: baseX, y: h * 0.65),
                control1: CGPoint(x: baseX + dir * w * 0.28, y: h * 0.85),
                control2: CGPoint(x: baseX, y: h * 0.78)
            )
            hwPath.closeSubpath()

            context.fill(hwPath, with: .color(yellowWarm))
            context.stroke(hwPath, with: .color(darkBorder), lineWidth: 1.8)

            let blueDot = CGRect(x: baseX + dir * w * 0.50 - 2, y: h * 0.75 - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: blueDot), with: .color(blueAccent))
            let orangeDot = CGRect(x: baseX + dir * w * 0.32 - 1.5, y: h * 0.76 - 1.5, width: 3, height: 3)
            context.fill(Path(ellipseIn: orangeDot), with: .color(orangeAccent))

            context.fill(fwPath, with: .color(yellowBright))
            context.stroke(fwPath, with: .color(darkBorder), lineWidth: 1.8)

            var stripes = Path()
            stripes.move(to: CGPoint(x: baseX + dir * w * 0.25, y: h * 0.30))
            stripes.addLine(to: CGPoint(x: baseX + dir * w * 0.32, y: h * 0.15))
            stripes.move(to: CGPoint(x: baseX + dir * w * 0.40, y: h * 0.35))
            stripes.addLine(to: CGPoint(x: baseX + dir * w * 0.52, y: h * 0.18))
            stripes.move(to: CGPoint(x: baseX + dir * w * 0.55, y: h * 0.42))
            stripes.addLine(to: CGPoint(x: baseX + dir * w * 0.72, y: h * 0.22))
            context.stroke(stripes, with: .color(darkBorder), lineWidth: 2.0)
        }
        .frame(width: size * 0.48, height: size * 0.82)
        .drawingGroup()
    }
}

// MARK: Summer Grass Silhouette

private struct SummerGrassSilhouette: View {
    let theme: SeasonTheme

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let grassDark = Color(red: 0.12, green: 0.22, blue: 0.10).opacity(0.50)
            let grassLight = Color(red: 0.22, green: 0.42, blue: 0.18).opacity(0.35)

            var pathDark = Path()
            var pathLight = Path()

            // Draw series of grass blades along the base
            var x: CGFloat = 0
            var i = 0
            while x < w {
                let bladeHeight: CGFloat = 20.0 + CGFloat((i * 17) % 28)
                let lean: CGFloat = CGFloat(((i * 7) % 24) - 12)

                if i % 2 == 0 {
                    pathDark.move(to: CGPoint(x: x, y: h))
                    pathDark.addQuadCurve(
                        to: CGPoint(x: x + lean, y: h - bladeHeight),
                        control: CGPoint(x: x + lean * 0.5, y: h - bladeHeight * 0.6)
                    )
                } else {
                    pathLight.move(to: CGPoint(x: x, y: h))
                    pathLight.addQuadCurve(
                        to: CGPoint(x: x + lean, y: h - bladeHeight),
                        control: CGPoint(x: x + lean * 0.5, y: h - bladeHeight * 0.6)
                    )
                }

                x += 7.0
                i += 1
            }

            context.stroke(pathDark, with: .color(grassDark), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.stroke(pathLight, with: .color(grassLight), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }
}

// MARK: Spring Cherry Blossom Tree (Vigorous Blooming Boughs & New Beginnings)

private struct SpringCherryBlossomTree: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barkColor = Color(red: 0.36, green: 0.22, blue: 0.16).opacity(0.68)

            // Sturdy, thick cherry wood trunk anchored to the right margin
            var trunk = Path()
            trunk.move(to: CGPoint(x: w + 12, y: h))
            trunk.addLine(to: CGPoint(x: w - 44, y: h))
            trunk.addQuadCurve(
                to: CGPoint(x: w - 24, y: h - 190),
                control: CGPoint(x: w - 38, y: h - 85)
            )
            trunk.addQuadCurve(
                to: CGPoint(x: w - 16, y: h - 450),
                control: CGPoint(x: w - 22, y: h - 310)
            )
            trunk.addLine(to: CGPoint(x: w + 12, y: h - 450))
            trunk.closeSubpath()
            context.fill(trunk, with: .color(barkColor))

            // Primary sculpted branch boughs with substantial thickness
            var limb1 = Path()
            limb1.move(to: CGPoint(x: w - 26, y: h - 170))
            limb1.addCurve(
                to: CGPoint(x: w - 96, y: h - 252),
                control1: CGPoint(x: w - 46, y: h - 205),
                control2: CGPoint(x: w - 74, y: h - 232)
            )
            context.stroke(limb1, with: .color(barkColor), style: StrokeStyle(lineWidth: 13.0, lineCap: .round))

            var twig1a = Path()
            twig1a.move(to: CGPoint(x: w - 62, y: h - 224))
            twig1a.addCurve(
                to: CGPoint(x: w - 116, y: h - 308),
                control1: CGPoint(x: w - 85, y: h - 258),
                control2: CGPoint(x: w - 105, y: h - 286)
            )
            context.stroke(twig1a, with: .color(barkColor), style: StrokeStyle(lineWidth: 7.0, lineCap: .round))

            var twig1b = Path()
            twig1b.move(to: CGPoint(x: w - 80, y: h - 245))
            twig1b.addCurve(
                to: CGPoint(x: w - 58, y: h - 296),
                control1: CGPoint(x: w - 75, y: h - 270),
                control2: CGPoint(x: w - 64, y: h - 286)
            )
            context.stroke(twig1b, with: .color(barkColor), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

            var limb2 = Path()
            limb2.move(to: CGPoint(x: w - 20, y: h - 280))
            limb2.addCurve(
                to: CGPoint(x: w - 102, y: h - 386),
                control1: CGPoint(x: w - 50, y: h - 325),
                control2: CGPoint(x: w - 82, y: h - 358)
            )
            context.stroke(limb2, with: .color(barkColor), style: StrokeStyle(lineWidth: 11.0, lineCap: .round))

            var twig2a = Path()
            twig2a.move(to: CGPoint(x: w - 64, y: h - 342))
            twig2a.addCurve(
                to: CGPoint(x: w - 118, y: h - 435),
                control1: CGPoint(x: w - 90, y: h - 380),
                control2: CGPoint(x: w - 110, y: h - 410)
            )
            context.stroke(twig2a, with: .color(barkColor), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))

            var twig2b = Path()
            twig2b.move(to: CGPoint(x: w - 85, y: h - 370))
            twig2b.addCurve(
                to: CGPoint(x: w - 54, y: h - 430),
                control1: CGPoint(x: w - 74, y: h - 400),
                control2: CGPoint(x: w - 60, y: h - 415)
            )
            context.stroke(twig2b, with: .color(barkColor), style: StrokeStyle(lineWidth: 5.0, lineCap: .round))

            var limb3 = Path()
            limb3.move(to: CGPoint(x: w - 16, y: h - 410))
            limb3.addCurve(
                to: CGPoint(x: w - 84, y: h - 515),
                control1: CGPoint(x: w - 42, y: h - 455),
                control2: CGPoint(x: w - 68, y: h - 488)
            )
            context.stroke(limb3, with: .color(barkColor), style: StrokeStyle(lineWidth: 9.0, lineCap: .round))

            var twig3a = Path()
            twig3a.move(to: CGPoint(x: w - 54, y: h - 475))
            twig3a.addCurve(
                to: CGPoint(x: w - 100, y: h - 570),
                control1: CGPoint(x: w - 78, y: h - 515),
                control2: CGPoint(x: w - 92, y: h - 545)
            )
            context.stroke(twig3a, with: .color(barkColor), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

            var twig3b = Path()
            twig3b.move(to: CGPoint(x: w - 32, y: h - 485))
            twig3b.addCurve(
                to: CGPoint(x: w - 24, y: h - 565),
                control1: CGPoint(x: w - 28, y: h - 520),
                control2: CGPoint(x: w - 26, y: h - 545)
            )
            context.stroke(twig3b, with: .color(barkColor), style: StrokeStyle(lineWidth: 4.8, lineCap: .round))

            // Fresh Spring Shoots & Leaf Buds
            let shootGreen = Color(red: 0.48, green: 0.82, blue: 0.28).opacity(0.85)
            let tenderLeaf = Color(red: 0.62, green: 0.88, blue: 0.35).opacity(0.80)

            let springShoots: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (w - 114, h - 308, 16, 8, -0.6),
                (w - 120, h - 318, 17, 9, -1.1),
                (w - 92,  h - 248, 15, 8, -0.4),
                (w - 60,  h - 296, 16, 8, -0.8),
                (w - 116, h - 432, 17, 9, -1.3),
                (w - 122, h - 442, 16, 8, -0.7),
                (w - 96,  h - 382, 16, 8, -0.5),
                (w - 52,  h - 430, 15, 7, -0.9),
                (w - 100, h - 568, 17, 8, -1.2),
                (w - 78,  h - 512, 16, 8, -0.6),
                (w - 22,  h - 562, 15, 7, -0.3)
            ]

            for (sx, sy, slen, sw, rot) in springShoots {
                let cosA = CGFloat(cos(rot))
                let sinA = CGFloat(sin(rot))
                let perpX = -sinA
                let perpY = cosA

                var shoot = Path()
                shoot.move(to: CGPoint(x: sx, y: sy))
                shoot.addQuadCurve(
                    to: CGPoint(x: sx + cosA * slen, y: sy + sinA * slen),
                    control: CGPoint(x: sx + cosA * slen * 0.5 + perpX * sw * 0.5, y: sy + sinA * slen * 0.5 + perpY * sw * 0.5)
                )
                shoot.addQuadCurve(
                    to: CGPoint(x: sx, y: sy),
                    control: CGPoint(x: sx + cosA * slen * 0.5 - perpX * sw * 0.5, y: sy + sinA * slen * 0.5 - perpY * sw * 0.5)
                )
                context.fill(shoot, with: .color(shootGreen))

                var pair = Path()
                pair.move(to: CGPoint(x: sx + 2, y: sy))
                pair.addQuadCurve(
                    to: CGPoint(x: sx + cosA * slen * 0.8 + perpX * sw * 0.7, y: sy + sinA * slen * 0.8 + perpY * sw * 0.7),
                    control: CGPoint(x: sx + perpX * sw, y: sy + perpY * sw)
                )
                pair.addQuadCurve(
                    to: CGPoint(x: sx + 2, y: sy),
                    control: CGPoint(x: sx + cosA * slen * 0.4, y: sy + sinA * slen * 0.4)
                )
                context.fill(pair, with: .color(tenderLeaf))
            }

            // Pronounced Blooming Sakura Florets
            let sakuraLight = Color(red: 1.00, green: 0.90, blue: 0.94).opacity(0.85)
            let sakuraBlush = Color(red: 0.98, green: 0.70, blue: 0.82).opacity(0.82)
            let sakuraRose  = Color(red: 0.94, green: 0.46, blue: 0.64).opacity(0.78)
            let pistilGold  = Color(red: 1.00, green: 0.84, blue: 0.28).opacity(0.95)

            // Large, vibrant five petal sakura flowers
            let sakuraBlooms: [(CGFloat, CGFloat, CGFloat, Double)] = [
                // Lower limb sprays
                (w - 52, h - 200, 26, 12),
                (w - 76, h - 240, 30, 34),
                (w - 98, h - 256, 28, 52),
                (w - 62, h - 275, 25, 20),
                (w - 92, h - 288, 27, 45),
                (w - 110, h - 305, 30, 10),
                (w - 42, h - 246, 24, 60),

                // Middle bough sprays
                (w - 48, h - 316, 28, 18),
                (w - 72, h - 352, 32, 40),
                (w - 96, h - 382, 29, 25),
                (w - 112, h - 422, 31, 55),
                (w - 82, h - 402, 26, 15),
                (w - 58, h - 418, 27, 48),
                (w - 34, h - 372, 25, 30),

                // Upper bough crown sprays
                (w - 42, h - 452, 27, 22),
                (w - 68, h - 492, 30, 38),
                (w - 82, h - 522, 28, 50),
                (w - 96, h - 558, 29, 15),
                (w - 56, h - 538, 25, 42),
                (w - 28, h - 528, 26, 10),
                (w - 20, h - 558, 24, 62)
            ]

            for (fx, fy, fsz, rot) in sakuraBlooms {
                let petalLen = fsz * 0.50
                let petalW = fsz * 0.38
                for a in 0..<5 {
                    let angle = Double(a) * 72.0 + rot
                    let rad = angle * .pi / 180.0
                    let px = fx + CGFloat(cos(rad)) * petalLen
                    let py = fy + CGFloat(sin(rad)) * petalLen

                    var petal = Path()
                    petal.addEllipse(in: CGRect(
                        x: px - petalW * 0.5,
                        y: py - petalW * 0.5,
                        width: petalW,
                        height: petalW * 1.35
                    ))
                    context.fill(petal, with: .color(a % 2 == 0 ? sakuraLight : sakuraBlush))
                }

                // Inner rose flower ring and golden pistil center
                let innerRect = CGRect(x: fx - fsz * 0.22, y: fy - fsz * 0.22, width: fsz * 0.44, height: fsz * 0.44)
                context.fill(Path(ellipseIn: innerRect), with: .color(sakuraRose.opacity(0.70)))

                let centerRect = CGRect(x: fx - fsz * 0.12, y: fy - fsz * 0.12, width: fsz * 0.24, height: fsz * 0.24)
                context.fill(Path(ellipseIn: centerRect), with: .color(pistilGold))
            }

            // Drifting cherry blossom petals
            let individualPetals: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                (w - 64, h - 215, 8.5, 12.5, sakuraBlush),
                (w - 100, h - 265, 8.0, 12.0, sakuraLight),
                (w - 48, h - 280, 8.5, 13.0, sakuraRose),
                (w - 88, h - 325, 8.0, 11.5, sakuraLight),
                (w - 106, h - 355, 8.5, 12.5, sakuraBlush),
                (w - 70, h - 435, 8.0, 12.0, sakuraRose),
                (w - 92, h - 465, 8.5, 12.5, sakuraLight),
                (w - 50, h - 495, 8.0, 11.5, sakuraBlush),
                (w - 78, h - 540, 8.5, 12.5, sakuraLight),
                (w - 18, h - 490, 8.0, 12.0, sakuraRose),
                (w - 20, h - 320, 8.0, 11.5, sakuraLight),
                (w - 24, h - 190, 8.5, 12.5, sakuraBlush)
            ]

            for (px, py, pw, ph, color) in individualPetals {
                var petalPath = Path()
                petalPath.addEllipse(in: CGRect(x: px - pw * 0.5, y: py - ph * 0.5, width: pw, height: ph))
                context.fill(petalPath, with: .color(color))
            }
        }
        .drawingGroup()
    }
}

// MARK: Summer Wind Stream

private struct SummerWindStreamItem: View {
    let startPoint: CGPoint
    let driftDistance: CGFloat
    let duration: Double
    let curveFactor: CGFloat
    let reduceMotion: Bool

    @State private var driftX: CGFloat = 0

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let streamColor = Color(red: 0.85, green: 0.95, blue: 0.78).opacity(0.18)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: h * 0.5))
            path.addCurve(
                to: CGPoint(x: w, y: h * 0.5 + curveFactor),
                control1: CGPoint(x: w * 0.35, y: h * 0.5 - curveFactor),
                control2: CGPoint(x: w * 0.70, y: h * 0.5 + curveFactor * 1.5)
            )
            context.stroke(path, with: .color(streamColor), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            var secondary = Path()
            secondary.move(to: CGPoint(x: w * 0.15, y: h * 0.5 + 5))
            secondary.addCurve(
                to: CGPoint(x: w * 0.65, y: h * 0.5 + 5 + curveFactor * 0.8),
                control1: CGPoint(x: w * 0.35, y: h * 0.5 + 5 - curveFactor * 0.6),
                control2: CGPoint(x: w * 0.55, y: h * 0.5 + 5 + curveFactor)
            )
            context.stroke(secondary, with: .color(streamColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(width: 140, height: 30)
        .position(x: startPoint.x + driftX, y: startPoint.y)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                driftX = driftDistance
            }
        }
    }
}

// MARK: Autumn Items (Pronounced Tree Silhouette, Left Pumpkin, Falling Leaves)

private struct AutumnPumpkinMark: View {
    let size: CGFloat
    let pumpkinColor: Color
    let stemColor: Color
    var isJackOLantern: Bool = false

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            // Stem: curved harvest amber stem centered at top
            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.46, y: h * 0.28))
            stem.addQuadCurve(
                to: CGPoint(x: w * 0.54, y: h * 0.06),
                control: CGPoint(x: w * 0.44, y: h * 0.14)
            )
            stem.addLine(to: CGPoint(x: w * 0.62, y: h * 0.08))
            stem.addQuadCurve(
                to: CGPoint(x: w * 0.56, y: h * 0.28),
                control: CGPoint(x: w * 0.52, y: h * 0.16)
            )
            stem.closeSubpath()
            context.fill(stem, with: .color(stemColor))

            // Ground shadow
            let shadowRect = CGRect(x: w * 0.06, y: h * 0.84, width: w * 0.88, height: h * 0.14)
            context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.22)))

            // Outer lobes (darker burnt harvest orange)
            let lobeDark = Color(red: 0.82, green: 0.24, blue: 0.12).opacity(0.92)
            context.fill(Path(ellipseIn: CGRect(x: w * 0.06, y: h * 0.24, width: w * 0.38, height: h * 0.64)), with: .color(lobeDark))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.56, y: h * 0.24, width: w * 0.38, height: h * 0.64)), with: .color(lobeDark))

            // Middle lobes (signature harvest pumpkin hue)
            context.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.20, width: w * 0.38, height: h * 0.70)), with: .color(pumpkinColor))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.44, y: h * 0.20, width: w * 0.38, height: h * 0.70)), with: .color(pumpkinColor))

            // Central front lobe
            context.fill(Path(ellipseIn: CGRect(x: w * 0.30, y: h * 0.22, width: w * 0.40, height: h * 0.68)), with: .color(pumpkinColor.opacity(0.95)))

            // Carved glowing Jack o Lantern face when Halloween is active
            if isJackOLantern {
                let candleGold = Color(red: 1.0, green: 0.88, blue: 0.25).opacity(0.98)
                let glowHalo = Color(red: 1.0, green: 0.72, blue: 0.15).opacity(0.35)

                // Left triangular eye centered on middle left lobe
                var leftEye = Path()
                leftEye.move(to: CGPoint(x: w * 0.36, y: h * 0.40))
                leftEye.addLine(to: CGPoint(x: w * 0.44, y: h * 0.52))
                leftEye.addLine(to: CGPoint(x: w * 0.28, y: h * 0.52))
                leftEye.closeSubpath()
                context.stroke(leftEye, with: .color(glowHalo), style: StrokeStyle(lineWidth: 3.5))
                context.fill(leftEye, with: .color(candleGold))

                // Right triangular eye centered on middle right lobe
                var rightEye = Path()
                rightEye.move(to: CGPoint(x: w * 0.64, y: h * 0.40))
                rightEye.addLine(to: CGPoint(x: w * 0.72, y: h * 0.52))
                rightEye.addLine(to: CGPoint(x: w * 0.56, y: h * 0.52))
                rightEye.closeSubpath()
                context.stroke(rightEye, with: .color(glowHalo), style: StrokeStyle(lineWidth: 3.5))
                context.fill(rightEye, with: .color(candleGold))

                // Small center triangular nose
                var nose = Path()
                nose.move(to: CGPoint(x: w * 0.50, y: h * 0.53))
                nose.addLine(to: CGPoint(x: w * 0.55, y: h * 0.60))
                nose.addLine(to: CGPoint(x: w * 0.45, y: h * 0.60))
                nose.closeSubpath()
                context.stroke(nose, with: .color(glowHalo), style: StrokeStyle(lineWidth: 2.5))
                context.fill(nose, with: .color(candleGold))

                // Broad carved grinning toothy mouth
                var mouth = Path()
                mouth.move(to: CGPoint(x: w * 0.26, y: h * 0.66))
                mouth.addLine(to: CGPoint(x: w * 0.34, y: h * 0.73))
                mouth.addLine(to: CGPoint(x: w * 0.40, y: h * 0.67))
                mouth.addLine(to: CGPoint(x: w * 0.50, y: h * 0.74))
                mouth.addLine(to: CGPoint(x: w * 0.60, y: h * 0.67))
                mouth.addLine(to: CGPoint(x: w * 0.66, y: h * 0.73))
                mouth.addLine(to: CGPoint(x: w * 0.74, y: h * 0.66))
                mouth.addLine(to: CGPoint(x: w * 0.68, y: h * 0.79))
                mouth.addLine(to: CGPoint(x: w * 0.50, y: h * 0.83))
                mouth.addLine(to: CGPoint(x: w * 0.32, y: h * 0.79))
                mouth.closeSubpath()
                context.stroke(mouth, with: .color(glowHalo), style: StrokeStyle(lineWidth: 3.5))
                context.fill(mouth, with: .color(candleGold))
            }
        }
        .frame(width: size, height: size * 0.85)
        .drawingGroup()
    }
}

// MARK: Autumn Leafy Canopy Tree (Thick Sculpted Boughs and Pronounced Botanical Leaves)

private struct AutumnLeafyCanopyTree: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barkColor = Color(red: 0.34, green: 0.20, blue: 0.14).opacity(0.68)

            // Main trunk anchored to the right edge with substantial thickness
            var trunk = Path()
            trunk.move(to: CGPoint(x: w + 12, y: h))
            trunk.addLine(to: CGPoint(x: w - 46, y: h))
            trunk.addQuadCurve(
                to: CGPoint(x: w - 24, y: h - 200),
                control: CGPoint(x: w - 40, y: h - 90)
            )
            trunk.addQuadCurve(
                to: CGPoint(x: w - 16, y: h - 450),
                control: CGPoint(x: w - 22, y: h - 310)
            )
            trunk.addLine(to: CGPoint(x: w + 12, y: h - 450))
            trunk.closeSubpath()
            context.fill(trunk, with: .color(barkColor))

            // Primary limbs on right perimeter
            var limb1 = Path()
            limb1.move(to: CGPoint(x: w - 26, y: h - 180))
            limb1.addCurve(
                to: CGPoint(x: w - 110, y: h - 265),
                control1: CGPoint(x: w - 50, y: h - 220),
                control2: CGPoint(x: w - 85, y: h - 242)
            )
            context.stroke(limb1, with: .color(barkColor), style: StrokeStyle(lineWidth: 15.0, lineCap: .round))

            var fork1 = Path()
            fork1.move(to: CGPoint(x: w - 70, y: h - 235))
            fork1.addCurve(
                to: CGPoint(x: w - 105, y: h - 325),
                control1: CGPoint(x: w - 88, y: h - 270),
                control2: CGPoint(x: w - 98, y: h - 298)
            )
            context.stroke(fork1, with: .color(barkColor), style: StrokeStyle(lineWidth: 8.0, lineCap: .round))

            var limb2 = Path()
            limb2.move(to: CGPoint(x: w - 20, y: h - 280))
            limb2.addCurve(
                to: CGPoint(x: w - 106, y: h - 415),
                control1: CGPoint(x: w - 55, y: h - 340),
                control2: CGPoint(x: w - 86, y: h - 382)
            )
            context.stroke(limb2, with: .color(barkColor), style: StrokeStyle(lineWidth: 12.0, lineCap: .round))

            var limb3 = Path()
            limb3.move(to: CGPoint(x: w - 16, y: h - 390))
            limb3.addCurve(
                to: CGPoint(x: w - 84, y: h - 520),
                control1: CGPoint(x: w - 46, y: h - 450),
                control2: CGPoint(x: w - 68, y: h - 485)
            )
            context.stroke(limb3, with: .color(barkColor), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))

            // Pronounced botanical autumn leaves with stems and veins
            let scarletRed = Color(red: 0.88, green: 0.22, blue: 0.14).opacity(0.85)
            let goldenAspen = Color(red: 0.98, green: 0.78, blue: 0.16).opacity(0.85)
            let burntOrange = Color(red: 0.94, green: 0.46, blue: 0.12).opacity(0.85)
            let plumWine = Color(red: 0.82, green: 0.22, blue: 0.28).opacity(0.82)
            let amberOchre = Color(red: 0.88, green: 0.60, blue: 0.18).opacity(0.82)
            let russetChestnut = Color(red: 0.70, green: 0.36, blue: 0.16).opacity(0.80)

            // Leaf sprays along upper limbs and twigs (Leaving branch at w-76, h-232 clean for hedgehog)
            let treeLeaves: [(CGFloat, CGFloat, CGFloat, CGFloat, Double, Color)] = [
                // Upper crown canopy (crimson, scarlet, golden)
                (w - 24, h - 575, 26, 15, -0.6, scarletRed),
                (w - 44, h - 560, 24, 14, -0.9, goldenAspen),
                (w - 16, h - 542, 25, 15, -0.3, burntOrange),
                (w - 56, h - 535, 27, 16, -1.2, scarletRed),
                (w - 36, h - 518, 25, 14, -0.7, plumWine),
                (w - 74, h - 508, 26, 15, -1.4, amberOchre),
                (w - 88, h - 498, 24, 14, -1.6, goldenAspen),
                (w - 60, h - 482, 25, 15, -1.0, burntOrange),
                (w - 28, h - 476, 26, 15, -0.5, scarletRed),

                // Middle bough foliage (amber, pumpkin, russet, plum)
                (w - 46, h - 442, 28, 16, -0.8, amberOchre),
                (w - 70, h - 432, 27, 15, -1.3, burntOrange),
                (w - 92, h - 422, 26, 14, -1.7, goldenAspen),
                (w - 110, h - 406, 28, 16, -2.0, scarletRed),
                (w - 84, h - 392, 27, 15, -1.5, plumWine),
                (w - 58, h - 382, 26, 14, -0.9, russetChestnut),
                (w - 36, h - 372, 27, 15, -0.6, burntOrange),
                (w - 18, h - 356, 25, 14, -0.4, goldenAspen),

                // Lower canopy twigs (Kept away from hedgehog perch at w-76, h-232)
                (w - 64, h - 342, 27, 15, -1.1, amberOchre),
                (w - 85, h - 332, 26, 14, -1.5, scarletRed),
                (w - 104, h - 316, 28, 16, -1.9, burntOrange),
                (w - 98, h - 282, 26, 14, -2.2, plumWine),
                (w - 114, h - 266, 25, 13, -2.4, goldenAspen),
                (w - 48, h - 312, 26, 14, -0.8, russetChestnut),
                (w - 26, h - 296, 25, 13, -0.5, scarletRed),
                (w - 40, h - 262, 26, 14, -0.7, amberOchre),
                (w - 20, h - 232, 25, 13, -0.4, burntOrange)
            ]

            for (lx, ly, llen, lw, rot, color) in treeLeaves {
                let cosA = CGFloat(cos(rot))
                let sinA = CGFloat(sin(rot))
                let perpX = -sinA
                let perpY = cosA

                let tipX = lx + cosA * llen
                let tipY = ly + sinA * llen
                let midX = lx + cosA * (llen * 0.45)
                let midY = ly + sinA * (llen * 0.45)

                let leftX = midX + perpX * (lw * 0.5)
                let leftY = midY + perpY * (lw * 0.5)
                let rightX = midX - perpX * (lw * 0.5)
                let rightY = midY - perpY * (lw * 0.5)

                var leaf = Path()
                leaf.move(to: CGPoint(x: lx, y: ly))
                leaf.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: leftX, y: leftY))
                leaf.addQuadCurve(to: CGPoint(x: lx, y: ly), control: CGPoint(x: rightX, y: rightY))
                leaf.closeSubpath()
                context.fill(leaf, with: .color(color))

                var vein = Path()
                vein.move(to: CGPoint(x: lx, y: ly))
                vein.addLine(to: CGPoint(x: tipX, y: tipY))
                context.stroke(vein, with: .color(Color.black.opacity(0.22)), lineWidth: 1.0)
            }
        }
        .drawingGroup()
    }
}

// MARK: Winter Bare Frost Tree Silhouette

private struct WinterBareFrostTreeSilhouette: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barkColor = Color(red: 0.19, green: 0.15, blue: 0.13).opacity(0.35)
            let frostColor = Color(red: 0.82, green: 0.90, blue: 0.98).opacity(0.32)

            // Main trunk anchored to the right edge
            var trunk = Path()
            trunk.move(to: CGPoint(x: w + 10, y: h))
            trunk.addLine(to: CGPoint(x: w - 30, y: h))
            trunk.addQuadCurve(
                to: CGPoint(x: w - 18, y: h - 180),
                control: CGPoint(x: w - 26, y: h - 80)
            )
            trunk.addQuadCurve(
                to: CGPoint(x: w - 10, y: h - 380),
                control: CGPoint(x: w - 16, y: h - 280)
            )
            trunk.addLine(to: CGPoint(x: w + 10, y: h - 380))
            context.fill(trunk, with: .color(barkColor))

            // Lower limb where the owl perches
            var limb1 = Path()
            limb1.move(to: CGPoint(x: w - 22, y: h - 160))
            limb1.addCurve(
                to: CGPoint(x: w - 100, y: h - 245),
                control1: CGPoint(x: w - 60, y: h - 210),
                control2: CGPoint(x: w - 85, y: h - 235)
            )
            context.stroke(limb1, with: .color(barkColor), style: StrokeStyle(lineWidth: 5.0, lineCap: .round))

            // Frost highlight along upper edge of lower limb
            var limb1Frost = Path()
            limb1Frost.move(to: CGPoint(x: w - 22, y: h - 163))
            limb1Frost.addCurve(
                to: CGPoint(x: w - 100, y: h - 248),
                control1: CGPoint(x: w - 60, y: h - 213),
                control2: CGPoint(x: w - 85, y: h - 238)
            )
            context.stroke(limb1Frost, with: .color(frostColor), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // Fork on lower limb
            var fork1 = Path()
            fork1.move(to: CGPoint(x: w - 60, y: h - 215))
            fork1.addCurve(
                to: CGPoint(x: w - 85, y: h - 280),
                control1: CGPoint(x: w - 75, y: h - 245),
                control2: CGPoint(x: w - 82, y: h - 265)
            )
            context.stroke(fork1, with: .color(barkColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

            var fork1Frost = Path()
            fork1Frost.move(to: CGPoint(x: w - 60, y: h - 217))
            fork1Frost.addCurve(
                to: CGPoint(x: w - 85, y: h - 282),
                control1: CGPoint(x: w - 75, y: h - 247),
                control2: CGPoint(x: w - 82, y: h - 267)
            )
            context.stroke(fork1Frost, with: .color(frostColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            // Mid limb
            var limb2 = Path()
            limb2.move(to: CGPoint(x: w - 14, y: h - 260))
            limb2.addCurve(
                to: CGPoint(x: w - 90, y: h - 390),
                control1: CGPoint(x: w - 55, y: h - 325),
                control2: CGPoint(x: w - 75, y: h - 365)
            )
            context.stroke(limb2, with: .color(barkColor), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))

            var limb2Frost = Path()
            limb2Frost.move(to: CGPoint(x: w - 14, y: h - 263))
            limb2Frost.addCurve(
                to: CGPoint(x: w - 90, y: h - 393),
                control1: CGPoint(x: w - 55, y: h - 328),
                control2: CGPoint(x: w - 75, y: h - 368)
            )
            context.stroke(limb2Frost, with: .color(frostColor), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

            // Upper limb reaching into sky
            var limb3 = Path()
            limb3.move(to: CGPoint(x: w - 10, y: h - 370))
            limb3.addCurve(
                to: CGPoint(x: w - 60, y: h - 490),
                control1: CGPoint(x: w - 35, y: h - 430),
                control2: CGPoint(x: w - 50, y: h - 465)
            )
            context.stroke(limb3, with: .color(barkColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

            var limb3Frost = Path()
            limb3Frost.move(to: CGPoint(x: w - 10, y: h - 372))
            limb3Frost.addCurve(
                to: CGPoint(x: w - 60, y: h - 492),
                control1: CGPoint(x: w - 35, y: h - 432),
                control2: CGPoint(x: w - 50, y: h - 467)
            )
            context.stroke(limb3Frost, with: .color(frostColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .drawingGroup()
    }
}

// MARK: Winter Snowy Owl View

private struct WinterSnowyOwlView: View {
    let isPerched: Bool
    let wingFlap: CGFloat
    var hasSantaHat: Bool = false

    private let whitePlumage = Color(red: 0.98, green: 0.99, blue: 1.0)
    private let softBarring = Color(red: 0.45, green: 0.49, blue: 0.54).opacity(0.82)
    private let slateOutline = Color(red: 0.82, green: 0.86, blue: 0.90).opacity(0.70)
    private let goldenIris = Color(red: 1.0, green: 0.80, blue: 0.04)
    private let darkPupil = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let darkBeak = Color(red: 0.16, green: 0.17, blue: 0.20)
    private let clawColor = Color(red: 0.22, green: 0.24, blue: 0.27)

    var body: some View {
        Canvas { context, size in
            let ox = size.width * 0.5
            let oy: CGFloat = 52.0

            // Tail
            if isPerched {
                var tail = Path()
                tail.move(to: CGPoint(x: ox - 5, y: oy - 4))
                tail.addLine(to: CGPoint(x: ox + 5, y: oy - 4))
                tail.addLine(to: CGPoint(x: ox + 4, y: oy + 13))
                tail.addLine(to: CGPoint(x: ox - 4, y: oy + 13))
                tail.closeSubpath()
                context.fill(tail, with: .color(whitePlumage.opacity(0.92)))

                var tailBars = Path()
                tailBars.move(to: CGPoint(x: ox - 4, y: oy + 4))
                tailBars.addLine(to: CGPoint(x: ox + 4, y: oy + 4))
                tailBars.move(to: CGPoint(x: ox - 3, y: oy + 8))
                tailBars.addLine(to: CGPoint(x: ox + 3, y: oy + 8))
                context.stroke(tailBars, with: .color(softBarring), lineWidth: 1.0)
            } else {
                var tail = Path()
                tail.move(to: CGPoint(x: ox - 6, y: oy - 4))
                tail.addLine(to: CGPoint(x: ox + 6, y: oy - 4))
                tail.addLine(to: CGPoint(x: ox + 8, y: oy + 8))
                tail.addLine(to: CGPoint(x: ox - 8, y: oy + 8))
                tail.closeSubpath()
                context.fill(tail, with: .color(whitePlumage.opacity(0.92)))

                var tailBars = Path()
                tailBars.move(to: CGPoint(x: ox - 5, y: oy + 3))
                tailBars.addLine(to: CGPoint(x: ox + 5, y: oy + 3))
                context.stroke(tailBars, with: .color(softBarring), lineWidth: 1.0)
            }

            // Wings
            if isPerched {
                // Folded wings along flanks
                var leftWing = Path()
                leftWing.move(to: CGPoint(x: ox - 13, y: oy - 26))
                leftWing.addLine(to: CGPoint(x: ox - 5, y: oy - 24))
                leftWing.addLine(to: CGPoint(x: ox - 7, y: oy - 2))
                leftWing.addLine(to: CGPoint(x: ox - 13, y: oy - 8))
                leftWing.closeSubpath()
                context.fill(leftWing, with: .color(whitePlumage.opacity(0.95)))
                context.stroke(leftWing, with: .color(slateOutline), lineWidth: 0.8)

                var rightWing = Path()
                rightWing.move(to: CGPoint(x: ox + 13, y: oy - 26))
                rightWing.addLine(to: CGPoint(x: ox + 5, y: oy - 24))
                rightWing.addLine(to: CGPoint(x: ox + 7, y: oy - 2))
                rightWing.addLine(to: CGPoint(x: ox + 13, y: oy - 8))
                rightWing.closeSubpath()
                context.fill(rightWing, with: .color(whitePlumage.opacity(0.95)))
                context.stroke(rightWing, with: .color(slateOutline), lineWidth: 0.8)
            } else {
                // Majestic curved flight wings
                let flapOffset = wingFlap * 12.0

                // Left wing
                var leftWing = Path()
                leftWing.move(to: CGPoint(x: ox - 7, y: oy - 22))
                leftWing.addCurve(
                    to: CGPoint(x: ox - 48, y: oy - 18 + flapOffset),
                    control1: CGPoint(x: ox - 18, y: oy - 30 + flapOffset * 0.7),
                    control2: CGPoint(x: ox - 36, y: oy - 28 + flapOffset * 0.9)
                )
                leftWing.addQuadCurve(
                    to: CGPoint(x: ox - 46, y: oy - 6 + flapOffset * 0.8),
                    control: CGPoint(x: ox - 50, y: oy - 11 + flapOffset * 0.9)
                )
                leftWing.addCurve(
                    to: CGPoint(x: ox - 7, y: oy - 6),
                    control1: CGPoint(x: ox - 34, y: oy + 2 + flapOffset * 0.4),
                    control2: CGPoint(x: ox - 18, y: oy + 2 + flapOffset * 0.2)
                )
                leftWing.closeSubpath()
                context.fill(leftWing, with: .color(whitePlumage))
                context.stroke(leftWing, with: .color(slateOutline), lineWidth: 0.8)

                // Slate primary feather markings on left wing
                var leftTips = Path()
                for i in 0..<4 {
                    let fx = ox - 26 - CGFloat(i) * 4.5
                    let fy = oy - 20 + flapOffset * 0.8 + CGFloat(i) * 2.8
                    leftTips.move(to: CGPoint(x: fx, y: fy))
                    leftTips.addLine(to: CGPoint(x: fx - 4.0, y: fy + 5.0))
                }
                context.stroke(leftTips, with: .color(softBarring), lineWidth: 1.5)

                // Right wing
                var rightWing = Path()
                rightWing.move(to: CGPoint(x: ox + 7, y: oy - 22))
                rightWing.addCurve(
                    to: CGPoint(x: ox + 48, y: oy - 18 + flapOffset),
                    control1: CGPoint(x: ox + 18, y: oy - 30 + flapOffset * 0.7),
                    control2: CGPoint(x: ox + 36, y: oy - 28 + flapOffset * 0.9)
                )
                rightWing.addQuadCurve(
                    to: CGPoint(x: ox + 46, y: oy - 6 + flapOffset * 0.8),
                    control: CGPoint(x: ox + 50, y: oy - 11 + flapOffset * 0.9)
                )
                rightWing.addCurve(
                    to: CGPoint(x: ox + 7, y: oy - 6),
                    control1: CGPoint(x: ox + 34, y: oy + 2 + flapOffset * 0.4),
                    control2: CGPoint(x: ox + 18, y: oy + 2 + flapOffset * 0.2)
                )
                rightWing.closeSubpath()
                context.fill(rightWing, with: .color(whitePlumage))
                context.stroke(rightWing, with: .color(slateOutline), lineWidth: 0.8)

                // Slate primary feather markings on right wing
                var rightTips = Path()
                for i in 0..<4 {
                    let fx = ox + 26 + CGFloat(i) * 4.5
                    let fy = oy - 20 + flapOffset * 0.8 + CGFloat(i) * 2.8
                    rightTips.move(to: CGPoint(x: fx, y: fy))
                    rightTips.addLine(to: CGPoint(x: fx + 4.0, y: fy + 5.0))
                }
                context.stroke(rightTips, with: .color(softBarring), lineWidth: 1.5)
            }

            // Main body identical in both flight and perched
            let bodyRect = CGRect(x: ox - 14, y: oy - 32, width: 28, height: 32)
            context.fill(Path(ellipseIn: bodyRect), with: .color(whitePlumage))
            context.stroke(Path(ellipseIn: bodyRect), with: .color(slateOutline), lineWidth: 1.0)

            // Soft slate chevron flecks on chest
            var barPaths = Path()
            barPaths.addArc(center: CGPoint(x: ox - 6, y: oy - 18), radius: 3.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            barPaths.addArc(center: CGPoint(x: ox + 6, y: oy - 18), radius: 3.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            barPaths.addArc(center: CGPoint(x: ox - 5, y: oy - 12), radius: 3.0, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            barPaths.addArc(center: CGPoint(x: ox + 5, y: oy - 12), radius: 3.0, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            barPaths.addArc(center: CGPoint(x: ox - 4, y: oy - 6), radius: 2.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            barPaths.addArc(center: CGPoint(x: ox + 4, y: oy - 6), radius: 2.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(barPaths, with: .color(softBarring), lineWidth: 1.2)

            // Head identical in both flight and perched
            let hx = ox
            let hy = oy - 30.0
            let headRect = CGRect(x: hx - 12.5, y: hy - 12, width: 25, height: 22)
            context.fill(Path(ellipseIn: headRect), with: .color(whitePlumage))
            context.stroke(Path(ellipseIn: headRect), with: .color(slateOutline), lineWidth: 1.0)

            // Festive red and white Santa hat when Christmas celebration is active
            if hasSantaHat {
                let hatRed = Color(red: 0.90, green: 0.14, blue: 0.12)
                let hatWhite = Color.white
                let hatShadow = Color(red: 0.70, green: 0.10, blue: 0.10)

                // White plush fur cuff across forehead
                let cuffRect = CGRect(x: hx - 13.0, y: hy - 13.5, width: 26.0, height: 6.5)
                context.fill(Path(roundedRect: cuffRect, cornerRadius: 3.2), with: .color(hatWhite))
                context.stroke(Path(roundedRect: cuffRect, cornerRadius: 3.2), with: .color(Color.black.opacity(0.12)), lineWidth: 0.8)

                // Red stocking cone curving upward and draping to the right
                var cone = Path()
                cone.move(to: CGPoint(x: hx - 11.0, y: hy - 11.5))
                cone.addCurve(
                    to: CGPoint(x: hx + 18.0, y: hy - 2.0),
                    control1: CGPoint(x: hx - 4.0, y: hy - 22.0),
                    control2: CGPoint(x: hx + 15.0, y: hy - 18.0)
                )
                cone.addLine(to: CGPoint(x: hx + 12.0, y: hy - 4.0))
                cone.addCurve(
                    to: CGPoint(x: hx + 9.5, y: hy - 11.5),
                    control1: CGPoint(x: hx + 10.0, y: hy - 15.0),
                    control2: CGPoint(x: hx + 6.0, y: hy - 16.0)
                )
                cone.closeSubpath()
                context.fill(cone, with: .color(hatRed))

                // Inner fold shadow for depth
                var fold = Path()
                fold.move(to: CGPoint(x: hx + 7.5, y: hy - 12.0))
                fold.addQuadCurve(to: CGPoint(x: hx + 15.5, y: hy - 3.0), control: CGPoint(x: hx + 13.5, y: hy - 14.0))
                context.stroke(fold, with: .color(hatShadow), lineWidth: 1.2)

                // Fluffy white pompom at dangling tip
                let pompomRect = CGRect(x: hx + 13.5, y: hy - 6.5, width: 8.5, height: 8.5)
                context.fill(Path(ellipseIn: pompomRect), with: .color(hatWhite))
                context.stroke(Path(ellipseIn: pompomRect), with: .color(Color.black.opacity(0.12)), lineWidth: 0.8)
            }

            // Symmetrical facial feather discs
            var discPath = Path()
            discPath.addArc(center: CGPoint(x: hx - 4.5, y: hy - 1), radius: 5.5, startAngle: .degrees(30), endAngle: .degrees(330), clockwise: false)
            discPath.addArc(center: CGPoint(x: hx + 4.5, y: hy - 1), radius: 5.5, startAngle: .degrees(210), endAngle: .degrees(150), clockwise: true)
            context.stroke(discPath, with: .color(slateOutline.opacity(0.6)), lineWidth: 0.8)

            // Golden yellow eyes with black pupils and specular reflections
            let eyeY = hy - 1.5
            let leftEyeRect = CGRect(x: hx - 7.5, y: eyeY - 3.5, width: 7, height: 7)
            context.fill(Path(ellipseIn: leftEyeRect), with: .color(goldenIris))
            let leftPupilRect = CGRect(x: hx - 5.8, y: eyeY - 1.8, width: 3.6, height: 3.6)
            context.fill(Path(ellipseIn: leftPupilRect), with: .color(darkPupil))
            let leftGlintRect = CGRect(x: hx - 6.2, y: eyeY - 2.2, width: 1.4, height: 1.4)
            context.fill(Path(ellipseIn: leftGlintRect), with: .color(.white))

            let rightEyeRect = CGRect(x: hx + 0.5, y: eyeY - 3.5, width: 7, height: 7)
            context.fill(Path(ellipseIn: rightEyeRect), with: .color(goldenIris))
            let rightPupilRect = CGRect(x: hx + 2.2, y: eyeY - 1.8, width: 3.6, height: 3.6)
            context.fill(Path(ellipseIn: rightPupilRect), with: .color(darkPupil))
            let rightGlintRect = CGRect(x: hx + 1.8, y: eyeY - 2.2, width: 1.4, height: 1.4)
            context.fill(Path(ellipseIn: rightGlintRect), with: .color(.white))

            // Hooked dark beak
            var beak = Path()
            beak.move(to: CGPoint(x: hx, y: eyeY + 1.2))
            beak.addLine(to: CGPoint(x: hx - 1.8, y: eyeY + 5.2))
            beak.addLine(to: CGPoint(x: hx + 1.8, y: eyeY + 5.2))
            beak.closeSubpath()
            context.fill(beak, with: .color(darkBeak))

            // Talons clutching the branch when perched
            if isPerched {
                var claws = Path()
                claws.move(to: CGPoint(x: ox - 5, y: oy - 1))
                claws.addLine(to: CGPoint(x: ox - 5, y: oy + 3.5))
                claws.move(to: CGPoint(x: ox - 2.5, y: oy - 1))
                claws.addLine(to: CGPoint(x: ox - 2.5, y: oy + 4.0))
                claws.move(to: CGPoint(x: ox + 2.5, y: oy - 1))
                claws.addLine(to: CGPoint(x: ox + 2.5, y: oy + 4.0))
                claws.move(to: CGPoint(x: ox + 5, y: oy - 1))
                claws.addLine(to: CGPoint(x: ox + 5, y: oy + 3.5))
                context.stroke(claws, with: .color(clawColor), lineWidth: 1.6)
            }
        }
        .frame(width: isPerched ? 52 : 100, height: 74)
    }
}

// MARK: Winter Snowy Owl Item

private struct WinterSnowyOwlItem: View {
    let containerSize: CGSize
    var hasSantaHat: Bool = false
    let reduceMotion: Bool

    @State private var position: CGPoint = .zero
    @State private var isPerched: Bool = true
    @State private var wingFlap: CGFloat = 0
    @State private var flightRotation: Double = 0

    private var perchPoint: CGPoint {
        CGPoint(x: containerSize.width - 80, y: containerSize.height - 248)
    }

    var body: some View {
        WinterSnowyOwlView(
            isPerched: isPerched,
            wingFlap: wingFlap,
            hasSantaHat: hasSantaHat
        )
        .rotationEffect(.degrees(flightRotation))
        .position(position)
        .task {
            // Start directly perched on the frosted branch
            position = perchPoint
            isPerched = true

            if reduceMotion { return }

            while !Task.isCancelled {
                // 1. Perched: rest peacefully on the branch
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }

                // 2. Take off: spread wings and start flapping
                withAnimation(.easeIn(duration: 0.35)) {
                    isPerched = false
                }
                withAnimation(.easeInOut(duration: 0.36).repeatForever(autoreverses: true)) {
                    wingFlap = -0.22
                }

                // 3. Waypoint 1: Swoop upward and left into open sky
                withAnimation(.easeInOut(duration: 2.5)) {
                    position = CGPoint(x: containerSize.width * 0.40, y: containerSize.height * 0.38)
                    flightRotation = -12
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { break }

                // 4. Waypoint 2: Soar along the left sky perimeter
                withAnimation(.easeInOut(duration: 2.8)) {
                    position = CGPoint(x: 75, y: containerSize.height * 0.24)
                    flightRotation = -6
                }
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                guard !Task.isCancelled else { break }

                // 5. Waypoint 3: Circle across the upper sky
                withAnimation(.easeInOut(duration: 2.8)) {
                    position = CGPoint(x: containerSize.width * 0.52, y: containerSize.height * 0.16)
                    flightRotation = 8
                }
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                guard !Task.isCancelled else { break }

                // 6. Waypoint 4: Sweep down the right perimeter
                withAnimation(.easeInOut(duration: 2.6)) {
                    position = CGPoint(x: containerSize.width - 70, y: containerSize.height * 0.28)
                    flightRotation = 10
                }
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { break }

                // 7. Waypoint 5: Wide circling loop back through mid left
                withAnimation(.easeInOut(duration: 2.8)) {
                    position = CGPoint(x: 90, y: containerSize.height * 0.34)
                    flightRotation = -10
                }
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                guard !Task.isCancelled else { break }

                // 8. Waypoint 6: Soar through top center
                withAnimation(.easeInOut(duration: 2.6)) {
                    position = CGPoint(x: containerSize.width * 0.46, y: containerSize.height * 0.20)
                    flightRotation = 4
                }
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { break }

                // 9. Waypoint 7: Line up glide toward the tree bough
                withAnimation(.easeInOut(duration: 2.4)) {
                    position = CGPoint(x: containerSize.width * 0.62, y: containerSize.height - 290)
                    flightRotation = 6
                }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { break }

                // 10. Smooth glide in to touch down on the branch
                withAnimation(.easeOut(duration: 1.8)) {
                    position = perchPoint
                    flightRotation = 0
                }
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled else { break }

                // 11. Touchdown and fold wings
                wingFlap = 0
                withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                    isPerched = true
                }
            }
        }
    }
}

// MARK: Autumn Falling and Resting Leaves

private struct DriftingAutumnLeafItem: View {
    let index: Int
    let totalCount: Int
    let containerSize: CGSize
    let reduceMotion: Bool

    @State private var currentY: CGFloat = -40
    @State private var swayX: CGFloat = 0
    @State private var rotationDeg: Double = 0
    @State private var opacity: Double = 0

    // Six rich botanical autumn tones
    private var leafColor: Color {
        let colors: [Color] = [
            Color(red: 0.88, green: 0.22, blue: 0.14), // Scarlet Maple Red
            Color(red: 0.96, green: 0.76, blue: 0.16), // Golden Aspen Yellow
            Color(red: 0.92, green: 0.44, blue: 0.10), // Burnt Orange Oak
            Color(red: 0.80, green: 0.20, blue: 0.26), // Plum Wine
            Color(red: 0.86, green: 0.58, blue: 0.16), // Warm Amber Ochre
            Color(red: 0.68, green: 0.34, blue: 0.14)  // Russet Chestnut
        ]
        return colors[index % colors.count]
    }

    private var leafSize: CGFloat {
        let sizes: [CGFloat] = [13, 16, 19, 14, 17, 21]
        return sizes[index % sizes.count]
    }

    private var startX: CGFloat {
        let seed = Double((index * 131) % 100) / 100.0
        return containerSize.width * CGFloat(0.06 + seed * 0.88)
    }

    private var groundY: CGFloat {
        let variance = CGFloat((index * 17) % 18)
        return containerSize.height - 24 - variance
    }

    private var fallDuration: Double {
        7.5 + Double((index * 7) % 5) * 1.2
    }

    private var restDuration: Double {
        2.5 + Double((index * 3) % 4) * 0.8
    }

    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: leafSize))
            .foregroundStyle(leafColor.opacity(0.52))
            .rotationEffect(.degrees(rotationDeg))
            .position(x: startX + swayX, y: currentY)
            .opacity(opacity)
            .task {
                guard !reduceMotion else {
                    currentY = groundY
                    opacity = 0.40
                    return
                }

                // Initial stagger so leaves fall in a natural sequence
                let initialDelay = Double(index) * 0.75
                try? await Task.sleep(for: .seconds(initialDelay))

                while !Task.isCancelled {
                    currentY = -30
                    opacity = 0
                    swayX = 0
                    rotationDeg = Double((index * 47) % 360)

                    // 1. Fade in and start falling
                    withAnimation(.easeIn(duration: 0.6)) {
                        opacity = 0.52
                    }

                    // 2. Swaying and fluttering during the fall
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        swayX = CGFloat(((index % 2 == 0) ? 1 : -1) * 18)
                        rotationDeg += 45
                    }

                    // 3. Fall down to the ground
                    withAnimation(.easeInOut(duration: fallDuration)) {
                        currentY = groundY
                    }

                    // Wait for fall to complete
                    try? await Task.sleep(for: .seconds(fallDuration))

                    // 4. Rest on the ground
                    try? await Task.sleep(for: .seconds(restDuration))

                    // 5. Fade out before recycling
                    withAnimation(.easeOut(duration: 0.8)) {
                        opacity = 0
                    }
                    try? await Task.sleep(for: .seconds(0.9))
                }
            }
    }
}

// MARK: Autumn Hedgehog (Storybook Cute Nestled on Tree Bough)

private struct AutumnHedgehogMark: View {
    let size: CGFloat
    let breathe: Bool

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            let quillDark = Color(red: 0.38, green: 0.22, blue: 0.12)
            let quillTan = Color(red: 0.72, green: 0.54, blue: 0.36)
            let quillLight = Color(red: 0.88, green: 0.76, blue: 0.58)
            let faceCream = Color(red: 0.96, green: 0.91, blue: 0.82)
            let innerEarPink = Color(red: 0.96, green: 0.68, blue: 0.75)
            let cheekBlush = Color(red: 0.98, green: 0.55, blue: 0.60).opacity(0.42)
            let berryRed = Color(red: 0.88, green: 0.18, blue: 0.16)
            let leafGreen = Color(red: 0.45, green: 0.75, blue: 0.35)
            let darkEye = Color(red: 0.12, green: 0.08, blue: 0.10)
            let darkNose = Color(red: 0.18, green: 0.10, blue: 0.10)

            // Ground bark shadow
            let shadowRect = CGRect(x: w * 0.12, y: h * 0.82, width: w * 0.74, height: h * 0.14)
            context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.20)))

            // Hedgehog Spiny Dome
            let domeRect = CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.68, height: h * 0.68)
            context.fill(Path(ellipseIn: domeRect), with: .color(quillDark))

            // Layered quill spine tips radiating outward along the back
            let quillSpines: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                // Outer perimeter spines
                (w * 0.14, h * 0.32, w * 0.04, h * 0.22, quillLight),
                (w * 0.24, h * 0.22, w * 0.18, h * 0.08, quillTan),
                (w * 0.38, h * 0.16, w * 0.35, h * 0.04, quillLight),
                (w * 0.52, h * 0.18, w * 0.54, h * 0.06, quillTan),
                (w * 0.64, h * 0.26, w * 0.70, h * 0.14, quillLight),
                (w * 0.10, h * 0.48, w * 0.01, h * 0.44, quillTan),
                (w * 0.10, h * 0.64, w * 0.02, h * 0.66, quillLight),
                (w * 0.14, h * 0.76, w * 0.08, h * 0.84, quillTan),
                // Inner layered highlights
                (w * 0.26, h * 0.36, w * 0.22, h * 0.26, quillLight),
                (w * 0.40, h * 0.30, w * 0.40, h * 0.18, quillTan),
                (w * 0.54, h * 0.34, w * 0.58, h * 0.24, quillLight),
                (w * 0.24, h * 0.52, w * 0.16, h * 0.48, quillLight),
                (w * 0.36, h * 0.46, w * 0.34, h * 0.38, quillTan),
                (w * 0.48, h * 0.48, w * 0.52, h * 0.40, quillLight),
                (w * 0.22, h * 0.68, w * 0.15, h * 0.70, quillTan),
                (w * 0.34, h * 0.62, w * 0.30, h * 0.58, quillLight)
            ]

            for (x0, y0, x1, y1, col) in quillSpines {
                var spine = Path()
                spine.move(to: CGPoint(x: x0, y: y0))
                spine.addLine(to: CGPoint(x: x1, y: y1))
                context.stroke(spine, with: .color(col), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }

            // Plump soft face and snout
            var face = Path()
            face.move(to: CGPoint(x: w * 0.48, y: h * 0.40))
            face.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.56),
                control1: CGPoint(x: w * 0.65, y: h * 0.38),
                control2: CGPoint(x: w * 0.82, y: h * 0.48)
            )
            face.addCurve(
                to: CGPoint(x: w * 0.52, y: h * 0.82),
                control1: CGPoint(x: w * 0.84, y: h * 0.72),
                control2: CGPoint(x: w * 0.68, y: h * 0.82)
            )
            face.closeSubpath()
            context.fill(face, with: .color(faceCream))

            // Rosy chubby cheek blush
            let blushRect = CGRect(x: w * 0.64, y: h * 0.62, width: 9, height: 6)
            context.fill(Path(ellipseIn: blushRect), with: .color(cheekBlush))

            // Cute small round ear with pink interior
            let earOuter = CGRect(x: w * 0.46, y: h * 0.36, width: 8.5, height: 8.5)
            context.fill(Path(ellipseIn: earOuter), with: .color(faceCream))
            let earInner = CGRect(x: w * 0.48, y: h * 0.38, width: 5.0, height: 5.0)
            context.fill(Path(ellipseIn: earInner), with: .color(innerEarPink))

            // Large glossy storybook eye with twin specular highlights
            let eyeRect = CGRect(x: w * 0.66, y: h * 0.48, width: 7.2, height: 7.2)
            context.fill(Path(ellipseIn: eyeRect), with: .color(darkEye))
            let glint1 = CGRect(x: w * 0.66 + 1.2, y: h * 0.48 + 1.0, width: 2.6, height: 2.6)
            context.fill(Path(ellipseIn: glint1), with: .color(.white))
            let glint2 = CGRect(x: w * 0.66 + 4.2, y: h * 0.48 + 4.0, width: 1.4, height: 1.4)
            context.fill(Path(ellipseIn: glint2), with: .color(.white))

            // Shiny button nose at tip of snout
            let noseRect = CGRect(x: w * 0.88, y: h * 0.53, width: 4.2, height: 4.0)
            context.fill(Path(ellipseIn: noseRect), with: .color(darkNose))

            // Autumn red berry held in front paws
            let berryRect = CGRect(x: w * 0.74, y: h * 0.68, width: 9.0, height: 9.0)
            context.fill(Path(ellipseIn: berryRect), with: .color(berryRed))
            var berryLeaf = Path()
            berryLeaf.addEllipse(in: CGRect(x: w * 0.77, y: h * 0.65, width: 4.5, height: 3.0))
            context.fill(berryLeaf, with: .color(leafGreen))

            // Little cream front paws hugging the berry
            let paw1 = CGRect(x: w * 0.68, y: h * 0.70, width: 6.5, height: 5.5)
            context.fill(Path(ellipseIn: paw1), with: .color(faceCream))
            let paw2 = CGRect(x: w * 0.76, y: h * 0.74, width: 6.0, height: 5.0)
            context.fill(Path(ellipseIn: paw2), with: .color(faceCream))

            // Little hind foot planted on the bough
            let footRect = CGRect(x: w * 0.34, y: h * 0.78, width: 9.0, height: 5.5)
            context.fill(Path(ellipseIn: footRect), with: .color(faceCream))
        }
        .frame(width: size, height: size * 0.82)
        .scaleEffect(y: breathe ? 1.03 : 0.98, anchor: .bottom)
        .drawingGroup()
    }
}

private struct AutumnHedgehogItem: View {
    let branchPoint: CGPoint
    let reduceMotion: Bool

    @State private var breathe = false

    var body: some View {
        AutumnHedgehogMark(size: 46, breathe: breathe)
            .position(x: branchPoint.x, y: branchPoint.y)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}

// MARK: October Halloween Bat

private struct OctoberBatMark: View {
    let size: CGFloat
    let wingScale: CGFloat

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let batColor = Color(red: 0.16, green: 0.12, blue: 0.18).opacity(0.85)

            // Center head and body
            var bodyPath = Path()
            bodyPath.addEllipse(in: CGRect(x: w * 0.44, y: h * 0.28, width: w * 0.12, height: h * 0.52))

            // Pointed bat ears
            var ears = Path()
            ears.move(to: CGPoint(x: w * 0.44, y: h * 0.32))
            ears.addLine(to: CGPoint(x: w * 0.42, y: h * 0.15))
            ears.addLine(to: CGPoint(x: w * 0.48, y: h * 0.28))
            ears.move(to: CGPoint(x: w * 0.52, y: h * 0.28))
            ears.addLine(to: CGPoint(x: w * 0.58, y: h * 0.15))
            ears.addLine(to: CGPoint(x: w * 0.56, y: h * 0.32))
            ears.closeSubpath()

            // Left scalloped wing
            var leftWing = Path()
            leftWing.move(to: CGPoint(x: w * 0.45, y: h * 0.38))
            leftWing.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.20), control: CGPoint(x: w * 0.25, y: h * 0.05))
            leftWing.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.55), control: CGPoint(x: w * 0.08, y: h * 0.42))
            leftWing.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.65), control: CGPoint(x: w * 0.20, y: h * 0.62))
            leftWing.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.68), control: CGPoint(x: w * 0.36, y: h * 0.70))
            leftWing.closeSubpath()

            // Right scalloped wing
            var rightWing = Path()
            rightWing.move(to: CGPoint(x: w * 0.55, y: h * 0.38))
            rightWing.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.20), control: CGPoint(x: w * 0.75, y: h * 0.05))
            rightWing.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.55), control: CGPoint(x: w * 0.92, y: h * 0.42))
            rightWing.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.65), control: CGPoint(x: w * 0.80, y: h * 0.62))
            rightWing.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.68), control: CGPoint(x: w * 0.64, y: h * 0.70))
            rightWing.closeSubpath()

            context.fill(bodyPath, with: .color(batColor))
            context.fill(ears, with: .color(batColor))
            context.fill(leftWing, with: .color(batColor))
            context.fill(rightWing, with: .color(batColor))
        }
        .scaleEffect(y: wingScale, anchor: .center)
        .frame(width: size, height: size * 0.62)
        .drawingGroup()
    }
}

private struct OctoberBatItem: View {
    let containerSize: CGSize
    let reduceMotion: Bool

    @State private var flightProgress: CGFloat = -0.2
    @State private var wingFlap: CGFloat = 1.0
    @State private var isVisible = false

    var body: some View {
        let x = containerSize.width * flightProgress
        let y = containerSize.height * 0.18 + CGFloat(sin(Double(flightProgress) * .pi * 2.0)) * 22

        OctoberBatMark(size: 36, wingScale: wingFlap)
            .rotationEffect(.degrees(sin(Double(flightProgress) * .pi * 2.0) * 15.0))
            .position(x: x, y: y)
            .opacity(isVisible ? 0.85 : 0)
            .task {
                guard !reduceMotion else { return }

                withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                    wingFlap = 0.45
                }

                while !Task.isCancelled {
                    // Fly across the sky every 16 seconds
                    flightProgress = -0.15
                    isVisible = true

                    withAnimation(.easeInOut(duration: 5.5)) {
                        flightProgress = 1.15
                    }

                    try? await Task.sleep(for: .seconds(5.5))
                    isVisible = false
                    try? await Task.sleep(for: .seconds(11.0))
                }
            }
    }
}

// MARK: October Halloween Silly Symphony Dancing Skeleton

private struct OctoberSkeletonMark: View {
    let size: CGFloat
    let walkPhase: CGFloat

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let bone = Color(red: 0.96, green: 0.94, blue: 0.88).opacity(0.95)
            let cavityDark = Color(red: 0.10, green: 0.08, blue: 0.12)

            let cx = w * 0.5
            let bounce = abs(sin(walkPhase)) * 3.5

            // 1. Bulbous cartoon skull
            let skullRect = CGRect(x: cx - 8.5, y: h * 0.06 - bounce, width: 17, height: 16)
            context.fill(Path(ellipseIn: skullRect), with: .color(bone))

            // Big dark oval hollow eye sockets
            context.fill(Path(ellipseIn: CGRect(x: cx - 6.5, y: h * 0.10 - bounce, width: 4.5, height: 5.5)), with: .color(cavityDark))
            context.fill(Path(ellipseIn: CGRect(x: cx + 2.0, y: h * 0.10 - bounce, width: 4.5, height: 5.5)), with: .color(cavityDark))

            // Triangular nasal cavity
            var nose = Path()
            nose.move(to: CGPoint(x: cx, y: h * 0.18 - bounce))
            nose.addLine(to: CGPoint(x: cx - 1.5, y: h * 0.22 - bounce))
            nose.addLine(to: CGPoint(x: cx + 1.5, y: h * 0.22 - bounce))
            nose.closeSubpath()
            context.fill(nose, with: .color(cavityDark))

            // Grinning teeth notches on jaw
            for t in -2...2 {
                let tx = cx + CGFloat(t) * 2.8
                var tooth = Path()
                tooth.move(to: CGPoint(x: tx, y: h * 0.23 - bounce))
                tooth.addLine(to: CGPoint(x: tx, y: h * 0.26 - bounce))
                context.stroke(tooth, with: .color(cavityDark), lineWidth: 1.0)
            }

            // 2. Neck and Spine
            var spine = Path()
            spine.move(to: CGPoint(x: cx, y: h * 0.26 - bounce))
            spine.addLine(to: CGPoint(x: cx, y: h * 0.54 - bounce))
            context.stroke(spine, with: .color(bone), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            // 3. Dark chest cavity background
            let chestRect = CGRect(x: cx - 9.0, y: h * 0.28 - bounce, width: 18, height: 16)
            context.fill(Path(roundedRect: chestRect, cornerRadius: 4), with: .color(cavityDark.opacity(0.70)))

            // Arched Ribs wrapping around
            for r in 0..<4 {
                let ry = h * 0.30 + CGFloat(r) * 3.8 - bounce
                let ribSpan = 8.5 - CGFloat(r) * 0.6
                var rib = Path()
                rib.move(to: CGPoint(x: cx - ribSpan, y: ry + 1.5))
                rib.addQuadCurve(
                    to: CGPoint(x: cx + ribSpan, y: ry + 1.5),
                    control: CGPoint(x: cx, y: ry - 2.0)
                )
                context.stroke(rib, with: .color(bone), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }

            // 4. Flared vintage cartoon pelvis bone
            var pelvis = Path()
            pelvis.move(to: CGPoint(x: cx - 8.0, y: h * 0.53 - bounce))
            pelvis.addQuadCurve(to: CGPoint(x: cx + 8.0, y: h * 0.53 - bounce), control: CGPoint(x: cx, y: h * 0.51 - bounce))
            pelvis.addQuadCurve(to: CGPoint(x: cx + 4.0, y: h * 0.60 - bounce), control: CGPoint(x: cx + 7.0, y: h * 0.58 - bounce))
            pelvis.addLine(to: CGPoint(x: cx - 4.0, y: h * 0.60 - bounce))
            pelvis.closeSubpath()
            context.fill(pelvis, with: .color(bone))

            // 5. Classic Silly Symphony pose: hands on hips with cocked elbows
            let elbowWiggle = sin(walkPhase) * 2.5
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: cx - 7.0, y: h * 0.28 - bounce))
            leftArm.addLine(to: CGPoint(x: cx - 14.0 - elbowWiggle, y: h * 0.40 - bounce))
            leftArm.addLine(to: CGPoint(x: cx - 7.0, y: h * 0.54 - bounce))
            context.stroke(leftArm, with: .color(bone), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var rightArm = Path()
            rightArm.move(to: CGPoint(x: cx + 7.0, y: h * 0.28 - bounce))
            rightArm.addLine(to: CGPoint(x: cx + 14.0 + elbowWiggle, y: h * 0.40 - bounce))
            rightArm.addLine(to: CGPoint(x: cx + 7.0, y: h * 0.54 - bounce))
            context.stroke(rightArm, with: .color(bone), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            // 6. High stepping cartoon dancing legs with knobby knee joints
            let legPhase = sin(walkPhase)
            let leftLegLift = max(0, -legPhase) * 10.0
            let rightLegLift = max(0, legPhase) * 10.0

            // Left leg
            var leftLeg = Path()
            leftLeg.move(to: CGPoint(x: cx - 4.0, y: h * 0.60 - bounce))
            let lKneeX = cx - 5.0 - legPhase * 5.0
            let lKneeY = h * 0.74 - leftLegLift - bounce * 0.5
            leftLeg.addLine(to: CGPoint(x: lKneeX, y: lKneeY))
            let lFootX = cx - 4.0 - legPhase * 8.0
            let lFootY = h * 0.95 - leftLegLift
            leftLeg.addLine(to: CGPoint(x: lFootX, y: lFootY))
            leftLeg.addLine(to: CGPoint(x: lFootX + 6.0, y: lFootY))
            context.stroke(leftLeg, with: .color(bone), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: lKneeX - 2, y: lKneeY - 2, width: 4, height: 4)), with: .color(bone))

            // Right leg
            var rightLeg = Path()
            rightLeg.move(to: CGPoint(x: cx + 4.0, y: h * 0.60 - bounce))
            let rKneeX = cx + 5.0 + legPhase * 5.0
            let rKneeY = h * 0.74 - rightLegLift - bounce * 0.5
            rightLeg.addLine(to: CGPoint(x: rKneeX, y: rKneeY))
            let rFootX = cx + 4.0 + legPhase * 8.0
            let rFootY = h * 0.95 - rightLegLift
            rightLeg.addLine(to: CGPoint(x: rFootX, y: rFootY))
            rightLeg.addLine(to: CGPoint(x: rFootX + 6.0, y: rFootY))
            context.stroke(rightLeg, with: .color(bone), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: rKneeX - 2, y: rKneeY - 2, width: 4, height: 4)), with: .color(bone))
        }
        .frame(width: size * 0.68, height: size)
        .drawingGroup()
    }
}

private struct OctoberSkeletonItem: View {
    let containerSize: CGSize
    let groundY: CGFloat
    let reduceMotion: Bool

    @State private var walkX: CGFloat = 0.32
    @State private var walkPhase: CGFloat = 0
    @State private var isFacingRight = true

    var body: some View {
        OctoberSkeletonMark(size: 54, walkPhase: walkPhase)
            .scaleEffect(x: isFacingRight ? 1 : -1, anchor: .center)
            .position(x: containerSize.width * walkX, y: groundY - 24)
            .task {
                guard !reduceMotion else {
                    walkX = 0.50
                    return
                }

                // Continuous walking dance cycle
                withAnimation(.linear(duration: 0.32).repeatForever(autoreverses: false)) {
                    walkPhase = .pi * 2
                }

                // Strolling and dancing back and forth across top rim of tab menu
                while !Task.isCancelled {
                    isFacingRight = true
                    withAnimation(.linear(duration: 8.0)) {
                        walkX = 0.68
                    }
                    try? await Task.sleep(for: .seconds(8.0))

                    try? await Task.sleep(for: .seconds(1.2))
                    isFacingRight = false
                    withAnimation(.linear(duration: 8.0)) {
                        walkX = 0.32
                    }
                    try? await Task.sleep(for: .seconds(8.0))
                    try? await Task.sleep(for: .seconds(1.2))
                }
            }
    }
}

// MARK: November Thanksgiving Harvest Turkey

private struct NovemberTurkeyMark: View {
    let size: CGFloat
    let headBob: Bool
    let tailFan: Bool

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            let featherColors: [Color] = [
                Color(red: 0.65, green: 0.22, blue: 0.12), // Burgundy
                Color(red: 0.82, green: 0.45, blue: 0.12), // Copper
                Color(red: 0.88, green: 0.68, blue: 0.16), // Gold
                Color(red: 0.45, green: 0.28, blue: 0.14)  // Chestnut
            ]
            let bodyBrown = Color(red: 0.44, green: 0.24, blue: 0.10)
            let headBlue = Color(red: 0.42, green: 0.52, blue: 0.62)
            let snoodRed = Color(red: 0.88, green: 0.18, blue: 0.16)
            let beakGold = Color(red: 0.96, green: 0.74, blue: 0.18)
            let feetColor = Color(red: 0.86, green: 0.62, blue: 0.15)

            // Fanned Tail Feathers
            let fanCount = 9
            for i in 0..<fanCount {
                let angle = Double(i) * 18.0 - 72.0
                let rad = angle * .pi / 180.0
                let len = (tailFan ? 1.05 : 0.95) * w * 0.42
                let fx = w * 0.32 + CGFloat(cos(rad)) * len
                let fy = h * 0.50 + CGFloat(sin(rad)) * len

                var feather = Path()
                feather.move(to: CGPoint(x: w * 0.32, y: h * 0.50))
                feather.addLine(to: CGPoint(x: fx, y: fy))
                context.stroke(feather, with: .color(featherColors[i % featherColors.count]), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

                let tipRect = CGRect(x: fx - 3, y: fy - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: tipRect), with: .color(beakGold))
            }

            // Plump Body
            let bodyRect = CGRect(x: w * 0.22, y: h * 0.38, width: w * 0.48, height: h * 0.46)
            context.fill(Path(ellipseIn: bodyRect), with: .color(bodyBrown))

            // Wing feather outline
            var wing = Path()
            wing.addQuadCurve(
                to: CGPoint(x: w * 0.56, y: h * 0.68),
                control: CGPoint(x: w * 0.42, y: h * 0.74)
            )
            context.stroke(wing, with: .color(Color(red: 0.30, green: 0.16, blue: 0.08)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // Legs and feet
            var leg1 = Path()
            leg1.move(to: CGPoint(x: w * 0.38, y: h * 0.80))
            leg1.addLine(to: CGPoint(x: w * 0.38, y: h * 0.95))
            leg1.addLine(to: CGPoint(x: w * 0.44, y: h * 0.95))
            context.stroke(leg1, with: .color(feetColor), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var leg2 = Path()
            leg2.move(to: CGPoint(x: w * 0.50, y: h * 0.80))
            leg2.addLine(to: CGPoint(x: w * 0.50, y: h * 0.95))
            leg2.addLine(to: CGPoint(x: w * 0.56, y: h * 0.95))
            context.stroke(leg2, with: .color(feetColor), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            // Head and Neck with bobbing
            let bobY = headBob ? -2.0 : 1.0
            var neck = Path()
            neck.move(to: CGPoint(x: w * 0.58, y: h * 0.52))
            neck.addQuadCurve(
                to: CGPoint(x: w * 0.68, y: h * 0.28 + bobY),
                control: CGPoint(x: w * 0.64, y: h * 0.38)
            )
            context.stroke(neck, with: .color(headBlue), style: StrokeStyle(lineWidth: 5.0, lineCap: .round))

            let headRect = CGRect(x: w * 0.64, y: h * 0.20 + bobY, width: w * 0.18, height: h * 0.18)
            context.fill(Path(ellipseIn: headRect), with: .color(headBlue))

            // Red Snood and Wattle
            var snood = Path()
            snood.move(to: CGPoint(x: w * 0.74, y: h * 0.28 + bobY))
            snood.addCurve(
                to: CGPoint(x: w * 0.72, y: h * 0.46 + bobY),
                control1: CGPoint(x: w * 0.78, y: h * 0.34 + bobY),
                control2: CGPoint(x: w * 0.76, y: h * 0.42 + bobY)
            )
            context.stroke(snood, with: .color(snoodRed), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

            // Beak
            var beak = Path()
            beak.move(to: CGPoint(x: w * 0.80, y: h * 0.26 + bobY))
            beak.addLine(to: CGPoint(x: w * 0.92, y: h * 0.30 + bobY))
            beak.addLine(to: CGPoint(x: w * 0.80, y: h * 0.34 + bobY))
            beak.closeSubpath()
            context.fill(beak, with: .color(beakGold))

            // Eye
            let eyeRect = CGRect(x: w * 0.72, y: h * 0.25 + bobY, width: 2.5, height: 2.5)
            context.fill(Path(ellipseIn: eyeRect), with: .color(.black))
        }
        .frame(width: size, height: size * 0.88)
        .drawingGroup()
    }
}

private struct NovemberTurkeyItem: View {
    let position: CGPoint
    let reduceMotion: Bool

    @State private var headBob = false
    @State private var tailFan = false

    var body: some View {
        NovemberTurkeyMark(size: 46, headBob: headBob, tailFan: tailFan)
            .position(x: position.x, y: position.y)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    headBob = true
                }
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                    tailFan = true
                }
            }
    }
}

// MARK: Winter Snowflake Item (Crisp Crystalline Flakes, No Dots)

private struct DriftingSnowflakeItem: View {
    let index: Int
    let totalCount: Int
    let containerSize: CGSize
    let crystalColor: Color
    let reduceMotion: Bool

    @State private var animatedY: CGFloat = 0
    @State private var swayX: CGFloat = 0
    @State private var rotationDeg: Double = 0

    private var initialX: CGFloat {
        let seed = Double((index * 127) % 100) / 100.0
        return containerSize.width * CGFloat(0.05 + seed * 0.90)
    }

    private var initialY: CGFloat {
        let seed = Double((index * 91) % 100) / 100.0
        return containerSize.height * CGFloat(seed)
    }

    private var itemSize: CGFloat {
        let sizes: [CGFloat] = [10, 13, 16, 19, 12, 15, 21]
        return sizes[index % sizes.count]
    }

    private var opacity: Double {
        let opacities = [0.24, 0.35, 0.42, 0.28, 0.38, 0.22, 0.32]
        return opacities[index % opacities.count]
    }

    private var duration: Double {
        9.0 + Double(index % 5) * 1.8
    }

    var body: some View {
        Image(systemName: "snowflake")
            .font(.system(size: itemSize))
            .foregroundStyle(crystalColor.opacity(opacity))
            .rotationEffect(.degrees(rotationDeg))
            .position(
                x: initialX + swayX,
                y: reduceMotion ? initialY : (initialY + animatedY).truncatingRemainder(dividingBy: containerSize.height + 40)
            )
            .onAppear {
                rotationDeg = Double((index * 60) % 360)
                guard !reduceMotion else { return }

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    animatedY = containerSize.height + 40
                }
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    swayX = 12
                    rotationDeg += 60
                }
            }
    }
}

// MARK: Easter Spring Holiday Bunny

private struct EasterBunnyMark: View {
    let size: CGFloat
    let twitch: Bool

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            let furWhite = Color(red: 0.98, green: 0.97, blue: 0.95)
            let innerEarPink = Color(red: 0.96, green: 0.78, blue: 0.82)
            let eyeDark = Color(red: 0.14, green: 0.12, blue: 0.15)
            let nosePink = Color(red: 0.92, green: 0.58, blue: 0.65)
            let blushPink = Color(red: 0.98, green: 0.65, blue: 0.70).opacity(0.35)
            let shadowColor = Color(red: 0.20, green: 0.25, blue: 0.22).opacity(0.18)

            // Ground shadow
            let shadowRect = CGRect(x: w * 0.15, y: h * 0.85, width: w * 0.70, height: h * 0.14)
            context.fill(Path(ellipseIn: shadowRect), with: .color(shadowColor))

            // Fluffy Cottontail
            let tailRect = CGRect(x: w * 0.08, y: h * 0.62, width: w * 0.22, height: h * 0.22)
            context.fill(Path(ellipseIn: tailRect), with: .color(furWhite))

            // Plump Bunny Body
            let bodyRect = CGRect(x: w * 0.20, y: h * 0.44, width: w * 0.58, height: h * 0.44)
            context.fill(Path(ellipseIn: bodyRect), with: .color(furWhite))

            // Hind leg and foot
            let footRect = CGRect(x: w * 0.28, y: h * 0.76, width: w * 0.42, height: h * 0.16)
            context.fill(Path(ellipseIn: footRect), with: .color(furWhite))

            // Front paws tucked forward
            let frontPawRect = CGRect(x: w * 0.56, y: h * 0.74, width: w * 0.22, height: h * 0.14)
            context.fill(Path(ellipseIn: frontPawRect), with: .color(furWhite))

            // Left Ear (slightly tilted)
            var leftEar = Path()
            leftEar.addEllipse(in: CGRect(x: w * 0.44, y: h * 0.04, width: w * 0.16, height: h * 0.42))
            context.fill(leftEar, with: .color(furWhite))

            var leftEarInner = Path()
            leftEarInner.addEllipse(in: CGRect(x: w * 0.47, y: h * 0.09, width: w * 0.10, height: h * 0.32))
            context.fill(leftEarInner, with: .color(innerEarPink))

            // Right Ear (upright with gentle twitch)
            let earTwitchY: CGFloat = twitch ? -2.0 : 0.0
            var rightEar = Path()
            rightEar.addEllipse(in: CGRect(x: w * 0.59, y: h * 0.02 + earTwitchY, width: w * 0.17, height: h * 0.45))
            context.fill(rightEar, with: .color(furWhite))

            var rightEarInner = Path()
            rightEarInner.addEllipse(in: CGRect(x: w * 0.62, y: h * 0.07 + earTwitchY, width: w * 0.11, height: h * 0.34))
            context.fill(rightEarInner, with: .color(innerEarPink))

            // Bunny Head
            let headRect = CGRect(x: w * 0.42, y: h * 0.34, width: w * 0.46, height: h * 0.42)
            context.fill(Path(ellipseIn: headRect), with: .color(furWhite))

            // Soft pink blush on cheek
            let blushRect = CGRect(x: w * 0.50, y: h * 0.52, width: w * 0.14, height: h * 0.10)
            context.fill(Path(ellipseIn: blushRect), with: .color(blushPink))

            // Big Glossy Storybook Eye with catchlight sparkles
            let eyeRect = CGRect(x: w * 0.62, y: h * 0.44, width: 6.5, height: 7.5)
            context.fill(Path(ellipseIn: eyeRect), with: .color(eyeDark))

            let sparkle1 = CGRect(x: w * 0.63, y: h * 0.45, width: 2.2, height: 2.2)
            context.fill(Path(ellipseIn: sparkle1), with: .color(.white))

            let sparkle2 = CGRect(x: w * 0.66, y: h * 0.49, width: 1.2, height: 1.2)
            context.fill(Path(ellipseIn: sparkle2), with: .color(.white))

            // Nose
            let noseY: CGFloat = twitch ? (h * 0.55 - 1.0) : (h * 0.55)
            let noseRect = CGRect(x: w * 0.78, y: noseY, width: 3.5, height: 3.0)
            context.fill(Path(ellipseIn: noseRect), with: .color(nosePink))

            // Delicate Whiskers
            var whiskers = Path()
            whiskers.move(to: CGPoint(x: w * 0.75, y: h * 0.57))
            whiskers.addLine(to: CGPoint(x: w * 0.94, y: h * 0.54))
            whiskers.move(to: CGPoint(x: w * 0.75, y: h * 0.59))
            whiskers.addLine(to: CGPoint(x: w * 0.95, y: h * 0.61))
            context.stroke(whiskers, with: .color(Color.gray.opacity(0.40)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

private struct EasterBunnyItem: View {
    let position: CGPoint
    let reduceMotion: Bool

    @State private var twitch = false

    var body: some View {
        EasterBunnyMark(size: 44, twitch: twitch)
            .position(x: position.x, y: position.y)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    twitch = true
                }
            }
    }
}

// MARK: Easter Spring Decorated Pastel Eggs

private struct EasterEggsMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            // Egg 1: Soft Mint Green (left, tilted gently)
            let egg1Rect = CGRect(x: w * 0.05, y: h * 0.28, width: w * 0.38, height: h * 0.62)
            var egg1 = Path()
            egg1.addEllipse(in: egg1Rect)
            context.fill(egg1, with: .color(Color(red: 0.74, green: 0.92, blue: 0.84)))

            // Egg 1 Polka Dots (soft cream)
            let dots: [(CGFloat, CGFloat)] = [
                (w * 0.16, h * 0.44), (w * 0.28, h * 0.48), (w * 0.20, h * 0.62), (w * 0.30, h * 0.72)
            ]
            for dot in dots {
                let dotRect = CGRect(x: dot.0 - 2, y: dot.1 - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(0.70)))
            }

            // Egg 2: Soft Lilac Lavender (back mid)
            let egg2Rect = CGRect(x: w * 0.36, y: h * 0.16, width: w * 0.36, height: h * 0.64)
            var egg2 = Path()
            egg2.addEllipse(in: egg2Rect)
            context.fill(egg2, with: .color(Color(red: 0.86, green: 0.78, blue: 0.94)))

            // Egg 2 Decorative Wavy Band
            var egg2Band = Path()
            egg2Band.move(to: CGPoint(x: w * 0.38, y: h * 0.48))
            egg2Band.addCurve(
                to: CGPoint(x: w * 0.70, y: h * 0.48),
                control1: CGPoint(x: w * 0.48, y: h * 0.42),
                control2: CGPoint(x: w * 0.60, y: h * 0.54)
            )
            context.stroke(egg2Band, with: .color(Color(red: 0.98, green: 0.94, blue: 0.68)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            // Egg 3: Soft Buttercup Yellow (front right)
            let egg3Rect = CGRect(x: w * 0.58, y: h * 0.36, width: w * 0.38, height: h * 0.58)
            var egg3 = Path()
            egg3.addEllipse(in: egg3Rect)
            context.fill(egg3, with: .color(Color(red: 0.98, green: 0.90, blue: 0.64)))

            // Egg 3 Peach Stripe
            var egg3Stripe = Path()
            egg3Stripe.move(to: CGPoint(x: w * 0.61, y: h * 0.64))
            egg3Stripe.addLine(to: CGPoint(x: w * 0.93, y: h * 0.64))
            context.stroke(egg3Stripe, with: .color(Color(red: 0.98, green: 0.68, blue: 0.62).opacity(0.85)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            // Tender grass sprigs at base
            let grassColor = Color(red: 0.45, green: 0.72, blue: 0.40).opacity(0.70)
            var grass = Path()
            grass.move(to: CGPoint(x: w * 0.12, y: h * 0.95))
            grass.addLine(to: CGPoint(x: w * 0.18, y: h * 0.80))
            grass.move(to: CGPoint(x: w * 0.48, y: h * 0.96))
            grass.addLine(to: CGPoint(x: w * 0.52, y: h * 0.78))
            grass.move(to: CGPoint(x: w * 0.82, y: h * 0.94))
            grass.addLine(to: CGPoint(x: w * 0.86, y: h * 0.82))
            context.stroke(grass, with: .color(grassColor), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(width: size, height: size * 0.75)
        .drawingGroup()
    }
}

private struct EasterEggsItem: View {
    let position: CGPoint

    var body: some View {
        EasterEggsMark(size: 46)
            .position(x: position.x, y: position.y)
    }
}

// MARK: Winter Christmas Twinkling Fairy Lights

private struct WinterFairyLightsItem: View {
    let containerSize: CGSize
    let reduceMotion: Bool

    @State private var twinklePhase = false

    private struct LightBulb: Identifiable {
        let id: Int
        let xPos: CGFloat
        let yPos: CGFloat
        let color: Color
        let isEven: Bool
    }

    private var bulbs: [LightBulb] {
        let w = containerSize.width
        let h = containerSize.height

        let colors: [Color] = [
            Color(red: 0.96, green: 0.22, blue: 0.24), // Ruby Red
            Color(red: 0.20, green: 0.85, blue: 0.42), // Emerald Green
            Color(red: 1.00, green: 0.82, blue: 0.28), // Golden Amber
            Color(red: 0.38, green: 0.76, blue: 1.00), // Icy Sapphire
            Color(red: 0.95, green: 0.35, blue: 0.75)  // Bright Magenta
        ]

        // Sample points along the tree limbs
        let points: [(CGFloat, CGFloat)] = [
            // Lower limb string
            (w - 28, h - 175),
            (w - 46, h - 198),
            (w - 65, h - 220),
            (w - 82, h - 235),
            (w - 96, h - 243),
            // Fork string
            (w - 68, h - 238),
            (w - 76, h - 258),
            (w - 83, h - 276),
            // Mid limb string
            (w - 22, h - 275),
            (w - 38, h - 305),
            (w - 55, h - 338),
            (w - 72, h - 366),
            (w - 86, h - 388),
            // Upper limb string
            (w - 18, h - 390),
            (w - 32, h - 425),
            (w - 48, h - 462)
        ]

        return points.enumerated().map { idx, pt in
            LightBulb(
                id: idx,
                xPos: pt.0,
                yPos: pt.1,
                color: colors[idx % colors.count],
                isEven: idx % 2 == 0
            )
        }
    }

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let wireColor = Color(red: 0.20, green: 0.30, blue: 0.22).opacity(0.40)

            // Draped thin green wires connecting the bulbs
            var wireLower = Path()
            wireLower.move(to: CGPoint(x: w - 24, y: h - 165))
            wireLower.addCurve(
                to: CGPoint(x: w - 98, y: h - 245),
                control1: CGPoint(x: w - 55, y: h - 200),
                control2: CGPoint(x: w - 80, y: h - 230)
            )
            context.stroke(wireLower, with: .color(wireColor), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))

            var wireMid = Path()
            wireMid.move(to: CGPoint(x: w - 16, y: h - 265))
            wireMid.addCurve(
                to: CGPoint(x: w - 88, y: h - 390),
                control1: CGPoint(x: w - 50, y: h - 315),
                control2: CGPoint(x: w - 72, y: h - 360)
            )
            context.stroke(wireMid, with: .color(wireColor), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .overlay {
            ForEach(bulbs) { bulb in
                let active = bulb.isEven ? twinklePhase : !twinklePhase
                let glowScale: CGFloat = (reduceMotion || active) ? 1.15 : 0.85
                let glowOpacity: Double = (reduceMotion || active) ? 0.95 : 0.45

                ZStack {
                    // Outer diffuse glow halo
                    Circle()
                        .fill(bulb.color.opacity(glowOpacity * 0.35))
                        .frame(width: 14, height: 14)
                        .scaleEffect(glowScale)

                    // Inner brilliant light bulb
                    Circle()
                        .fill(bulb.color.opacity(glowOpacity))
                        .frame(width: 5.5, height: 5.5)

                    // Tiny glass highlight
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 1.8, height: 1.8)
                        .offset(x: -1, y: -1)
                }
                .position(x: bulb.xPos, y: bulb.yPos)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                twinklePhase = true
            }
        }
    }
}

// MARK: Winter Christmas Wrapped Holiday Gift Boxes

private struct WinterGiftBoxesMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            let shadowColor = Color(red: 0.15, green: 0.22, blue: 0.28).opacity(0.20)
            let redBox = Color(red: 0.78, green: 0.16, blue: 0.18)
            let redLid = Color(red: 0.86, green: 0.20, blue: 0.22)
            let goldRibbon = Color(red: 0.98, green: 0.82, blue: 0.24)
            let greenBox = Color(red: 0.14, green: 0.48, blue: 0.26)
            let greenLid = Color(red: 0.18, green: 0.56, blue: 0.30)
            let silverRibbon = Color(red: 0.92, green: 0.94, blue: 0.98)

            // Ground shadow
            let shadowRect = CGRect(x: w * 0.08, y: h * 0.86, width: w * 0.84, height: h * 0.12)
            context.fill(Path(ellipseIn: shadowRect), with: .color(shadowColor))

            // Box 1 (Left): Festive Emerald Green Gift Box
            let gBoxRect = CGRect(x: w * 0.08, y: h * 0.42, width: w * 0.42, height: h * 0.46)
            context.fill(Path(roundedRect: gBoxRect, cornerRadius: 2.0), with: .color(greenBox))

            // Green box lid
            let gLidRect = CGRect(x: w * 0.06, y: h * 0.38, width: w * 0.46, height: h * 0.10)
            context.fill(Path(roundedRect: gLidRect, cornerRadius: 1.5), with: .color(greenLid))

            // Green box vertical silver ribbon
            let gRibbonV = CGRect(x: w * 0.25, y: h * 0.38, width: w * 0.08, height: h * 0.50)
            context.fill(Path(gRibbonV), with: .color(silverRibbon))

            // Green box silver bow loops
            var gBowLeft = Path()
            gBowLeft.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.28, width: w * 0.11, height: h * 0.12))
            context.stroke(gBowLeft, with: .color(silverRibbon), style: StrokeStyle(lineWidth: 2.0))

            var gBowRight = Path()
            gBowRight.addEllipse(in: CGRect(x: w * 0.29, y: h * 0.28, width: w * 0.11, height: h * 0.12))
            context.stroke(gBowRight, with: .color(silverRibbon), style: StrokeStyle(lineWidth: 2.0))

            // Box 2 (Right): Crimson Red Holiday Gift Box with Golden Satin Ribbon
            let rBoxRect = CGRect(x: w * 0.44, y: h * 0.30, width: w * 0.48, height: h * 0.58)
            context.fill(Path(roundedRect: rBoxRect, cornerRadius: 2.5), with: .color(redBox))

            // Red box lid
            let rLidRect = CGRect(x: w * 0.41, y: h * 0.25, width: w * 0.54, height: h * 0.11)
            context.fill(Path(roundedRect: rLidRect, cornerRadius: 2.0), with: .color(redLid))

            // Red box vertical gold ribbon
            let rRibbonV = CGRect(x: w * 0.63, y: h * 0.25, width: w * 0.10, height: h * 0.63)
            context.fill(Path(rRibbonV), with: .color(goldRibbon))

            // Red box horizontal gold ribbon
            let rRibbonH = CGRect(x: w * 0.44, y: h * 0.54, width: w * 0.48, height: h * 0.09)
            context.fill(Path(rRibbonH), with: .color(goldRibbon))

            // Golden Satin Bow Loops on Red Box
            var rBowLeft = Path()
            rBowLeft.addEllipse(in: CGRect(x: w * 0.52, y: h * 0.12, width: w * 0.14, height: h * 0.15))
            context.stroke(rBowLeft, with: .color(goldRibbon), style: StrokeStyle(lineWidth: 2.4))

            var rBowRight = Path()
            rBowRight.addEllipse(in: CGRect(x: w * 0.68, y: h * 0.12, width: w * 0.14, height: h * 0.15))
            context.stroke(rBowRight, with: .color(goldRibbon), style: StrokeStyle(lineWidth: 2.4))

            // Bow center knot
            let knotRect = CGRect(x: w * 0.63, y: h * 0.20, width: w * 0.08, height: h * 0.08)
            context.fill(Path(ellipseIn: knotRect), with: .color(goldRibbon))
        }
        .frame(width: size * 1.15, height: size)
        .drawingGroup()
    }
}

private struct WinterGiftBoxesItem: View {
    let position: CGPoint

    var body: some View {
        WinterGiftBoxesMark(size: 58)
            .position(x: position.x, y: position.y - 25)
    }
}

