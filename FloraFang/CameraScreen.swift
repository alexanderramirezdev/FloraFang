//
//  CameraScreen.swift
//  FloraFang
//

import SwiftUI
import SwiftData
import AVFoundation

struct CameraScreen: View {
    var isActive: Bool = true

    @Environment(\.modelContext) private var modelContext

    @State private var camera = CameraService()
    @State private var cascade = IdentificationCascade()
    @State private var location = LocationService()

    @State private var isWorking = false
    @State private var assessment: Assessment?
    @State private var savedEntry: FieldEntry?
    @State private var capturedImage: UIImage?
    @State private var trace: [String] = []
    @State private var errorMessage: String?
    @State private var stopTask: Task<Void, Never>?

    // Label inspector (development tool: long-press the shutter)
    @State private var rawLabels: [RankedLabel] = []
    @State private var inspectorImage: UIImage?
    @State private var showInspector = false

    // Shutter capture mode: action for fast bugs, detail for deep fusion plants
    @AppStorage("camera_capture_mode") private var storedCaptureMode = "action"

    // Background processing states for Snap and Step Back flow
    @State private var backgroundThumbnail: UIImage?
    @State private var isAnalyzingInBackground = false
    @State private var backgroundResult: Assessment?
    @State private var backgroundToastVisible = false
    @State private var hideToastTask: Task<Void, Never>?

    // Focus indicator
    @State private var focusPoint: CGPoint?
    @State private var focusPulse = false

    // Shutter flash visual feedback
    @State private var shutterFlash = false

    // Geometry needed to map the on-screen square into image pixels.
    @State private var previewSize: CGSize = .zero

    private let squareSide: CGFloat = 260

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            switch camera.state {
            case .ready:
                preview
            case .denied:
                message("FloraFang needs the camera to identify anything. Enable it in Settings → FloraFang.")
            case .interrupted:
                message("Camera paused. This usually clears on its own. If it does not, switch tabs and come back.")
            case .failed(let reason):
                message(reason)
            case .idle:
                ProgressView().tint(Palette.parchment)
            }

            if shutterFlash {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                header
                Spacer()
                if isReady { quadratFrame }
                Spacer()
                if isReady { zoomControl }
                shutterArea
            }
            .padding(.vertical, 24)

            if backgroundToastVisible, let thumbnail = backgroundThumbnail {
                VStack {
                    Spacer()
                    backgroundProcessingToast(thumbnail: thumbnail)
                        .padding(.bottom, 106)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            camera.setCaptureMode(storedCaptureMode == "detail" ? .detail : .action)
            stopTask?.cancel()
            stopTask = nil
            if isActive {
                Task { await camera.start() }
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                stopTask?.cancel()
                stopTask = nil
                Task { await camera.start() }
            } else {
                stopTask?.cancel()
                stopTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    camera.stop()
                }
            }
        }
        .onDisappear {
            stopTask?.cancel()
            stopTask = nil
            camera.stop()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )) { _ in
            stopTask?.cancel()
            stopTask = nil
            camera.stop()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            if isActive {
                Task { await camera.start() }
            }
        }
        .fullScreenCover(item: $assessment) { result in
            ResultScreen(
                assessment: result,
                image: capturedImage,
                trace: trace,
                savedEntry: savedEntry,
                onDelete: {
                    if let entry = savedEntry {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                    savedEntry = nil
                    assessment = nil
                },
                onDismiss: {
                    savedEntry = nil
                    assessment = nil
                }
            )
        }
        #if DEBUG
        .sheet(isPresented: $showInspector) {
            LabelInspectorSheet(labels: rawLabels, image: inspectorImage)
        }
        #endif
        .alert("Scan failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Preview

    private var preview: some View {
        GeometryReader { geo in
            CameraPreview(
                session: camera.session,
                onFocusTap: { devicePoint, viewPoint in
                    camera.focus(at: devicePoint)
                    showFocusIndicator(at: viewPoint)
                },
                onPinch: { scale, state in
                    if state == .changed {
                        camera.setZoom(camera.zoomFactor * scale)
                    }
                }
            )
            .onAppear { previewSize = geo.size }
            .onChange(of: geo.size) { _, newValue in previewSize = newValue }
        }
        .ignoresSafeArea()
        .overlay(scrim)
        .overlay(focusIndicator)
    }

    private var scrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear, .black.opacity(0.7)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var focusIndicator: some View {
        if let point = focusPoint {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Palette.ochre, lineWidth: 1.5)
                .frame(width: 64, height: 64)
                .scaleEffect(focusPulse ? 1 : 1.35)
                .opacity(focusPulse ? 1 : 0.3)
                .position(point)
                .allowsHitTesting(false)
        }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 3) {
            Text("FLORAFANG")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .tracking(4)
                .foregroundStyle(Palette.moss)
            Text("know what bites and what is toxic")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(Palette.parchment.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.black.opacity(0.35), in: Capsule())
        .allowsHitTesting(false)
    }

    private var quadratFrame: some View {
        ZStack {
            Rectangle().stroke(Palette.moss, lineWidth: 1.5)

            ForEach(CornerPosition.allCases, id: \.self) { corner in
                CornerBracket(position: corner).stroke(Palette.ochre, lineWidth: 3)
            }

            if isWorking {
                Text("identifying…")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.parchment)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
            }
        }
        .frame(width: squareSide, height: squareSide)
        .allowsHitTesting(false)
        .overlay(alignment: .bottom) {
            // Anchored to the frame but allowed to exceed its width. The hint
            // is longer than 260pt, and wrapped text defaults to leading
            // alignment, which reads as badly centered rather than wrapped.
            //
            // The scrim matters more than it looks. Light text over a live
            // camera feed is legible against a dark wall and invisible
            // against a bright one, and the app cannot control what someone
            // points it at.
            VStack(spacing: 3) {
                Text("frame a single leaf cluster, stem marking, or spider")
                    .font(.system(size: 11.5, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.parchment)
                #if DEBUG
                Text("tap to focus · hold shutter for raw labels")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Palette.parchment.opacity(0.72))
                #else
                Text("tap to focus")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Palette.parchment.opacity(0.72))
                #endif
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .offset(y: 46)
            .allowsHitTesting(false)
        }
    }

    /// Zoom is the answer for small subjects, not walking closer: moving in
    /// past the lens's minimum focus distance just produces a blurry photo.
    private var zoomControl: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)

                Slider(
                    value: Binding(
                        get: { camera.zoomFactor },
                        set: { camera.setZoom($0) }
                    ),
                    in: camera.minZoom...max(camera.maxZoom, camera.minZoom + 0.1)
                )
                .tint(Palette.ochre)

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)

                Text(String(format: "%.1f×", camera.zoomFactor / max(camera.minZoom, 0.001)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.parchment)
                    .frame(width: 34, alignment: .trailing)
            }

            if let cm = camera.minimumFocusDistanceCM {
                let inches = max(1, Int(round(Double(cm) / 2.54)))
                Text(camera.supportsMacro
                     ? "Closer than ~\(inches) in (\(Int(cm)) cm) switches to macro automatically"
                     : "Cannot focus closer than ~\(inches) in (\(Int(cm)) cm), zoom instead of moving in")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.parchment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    private var shutterArea: some View {
        HStack {
            // Balanced spacer on left so shutter button is centered
            Color.clear
                .frame(width: 58, height: 50)

            Spacer()

            shutterButton

            Spacer()

            // Quick Shutter Mode Toggle (Action / Detail) positioned right beside the shutter
            modeToggleButton
                .frame(width: 58, height: 50)
        }
        .padding(.horizontal, 28)
    }

    private var shutterButton: some View {
        Button(action: capture) {
            ZStack {
                Circle().fill(Palette.ochre).frame(width: 66, height: 66)
                Circle().stroke(Palette.parchment, lineWidth: 4).frame(width: 74, height: 74)
                if isWorking {
                    ProgressView().tint(Palette.parchment)
                } else {
                    Image(systemName: "camera")
                        .foregroundStyle(Palette.parchment)
                        .font(.system(size: 22))
                }
            }
        }
        .disabled(isWorking || !isReady)
        .opacity(isReady ? 1 : 0.4)
        .accessibilityLabel("Scan subject")
        #if DEBUG
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in inspectLabels() }
        )
        #endif
    }

    private var modeToggleButton: some View {
        Button {
            let nextMode: CaptureMode = (camera.captureMode == .action ? .detail : .action)
            storedCaptureMode = nextMode.rawValue
            camera.setCaptureMode(nextMode)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: camera.captureMode.systemIcon)
                    .font(.system(size: 15, weight: .bold))
                Text(camera.captureMode.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(camera.captureMode == .action ? Color(red: 1.0, green: 0.82, blue: 0.20) : Palette.moss)
            .frame(width: 58, height: 50)
            .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        camera.captureMode == .action ? Color(red: 1.0, green: 0.82, blue: 0.20).opacity(0.65) : Palette.moss.opacity(0.5),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .accessibilityLabel("Shutter mode: \(camera.captureMode.displayName). \(camera.captureMode.subtitle)")
    }

    private var isReady: Bool {
        if case .ready = camera.state { return true }
        return false
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, design: .serif))
            .foregroundStyle(Palette.parchment)
            .multilineTextAlignment(.center)
            .padding(32)
    }

    // MARK: Actions

    private func showFocusIndicator(at point: CGPoint) {
        focusPoint = point
        focusPulse = false
        withAnimation(.easeOut(duration: 0.25)) { focusPulse = true }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            if focusPoint == point { focusPoint = nil }
        }
    }

    /// Crops to what the user framed. Without this the classifier sees mostly
    /// background and describes the wall instead of the spider on it.
    private func cropToFrame(_ image: UIImage) -> UIImage {
        guard previewSize != .zero else { return image }
        return image.croppedToFrame(squareSide: squareSide, previewSize: previewSize)
    }

    private func capture() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { shutterFlash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.12)) { shutterFlash = false }
        }

        isWorking = true
        location.refresh()

        Task {
            do {
                let full = try await camera.capturePhoto(mode: camera.captureMode)
                let cropped = cropToFrame(full)

                // Instant capture confirmation: unlock viewfinder immediately
                // so user can safely step back from the subject
                await MainActor.run {
                    isWorking = false
                    capturedImage = cropped
                    backgroundThumbnail = cropped
                    isAnalyzingInBackground = true
                    backgroundResult = nil
                    hideToastTask?.cancel()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        backgroundToastVisible = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                // Run CoreML cascade assessment in the background
                let result = try await cascade.assess(cropped)
                let currentTrace = cascade.lastTrace

                // Automatically save into SwiftData Field Log
                await MainActor.run {
                    self.trace = currentTrace
                    self.savedEntry = save(result, image: cropped)
                    self.backgroundResult = result
                    self.isAnalyzingInBackground = false

                    // If a hazardous spider or plant is detected, trigger warning alert haptic
                    if result.hazard == .avoid || result.hazard == .caution {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }

                    // Auto dismiss the background toast after 8 seconds if user has not tapped
                    self.hideToastTask = Task {
                        try? await Task.sleep(for: .seconds(8))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.backgroundToastVisible = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    isAnalyzingInBackground = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func backgroundProcessingToast(thumbnail: UIImage) -> some View {
        Button {
            if let res = backgroundResult {
                assessment = res
            }
        } label: {
            HStack(spacing: 12) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isAnalyzingInBackground ? Color(red: 1.0, green: 0.82, blue: 0.20) : (backgroundResult?.hazard == .avoid ? Palette.danger : (backgroundResult?.hazard == .caution ? Palette.warn : Palette.moss)),
                                lineWidth: 2
                            )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if isAnalyzingInBackground {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(Palette.parchment)
                            Text("IDENTIFYING IN BACKGROUND")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.20))
                        } else if let res = backgroundResult {
                            Image(systemName: res.hazard.symbol)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(res.hazard == .avoid ? Palette.danger : (res.hazard == .caution ? Palette.warn : Palette.moss))
                            Text(res.hazard.label.uppercased())
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(res.hazard == .avoid ? Palette.danger : (res.hazard == .caution ? Palette.warn : Palette.parchment))
                        }
                    }

                    Text(isAnalyzingInBackground ? "Step back safely. Analyzing subject…" : (backgroundResult?.headline ?? "Analysis complete"))
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.parchment)
                        .lineLimit(1)

                    if !isAnalyzingInBackground {
                        Text("Tap to view protocol")
                            .font(.system(size: 10, design: .serif))
                            .italic()
                            .foregroundStyle(Palette.parchment.opacity(0.75))
                    }
                }

                Spacer()

                if !isAnalyzingInBackground {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.parchment.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isAnalyzingInBackground ? Color(red: 1.0, green: 0.82, blue: 0.20).opacity(0.4) : (backgroundResult?.hazard == .avoid ? Palette.danger.opacity(0.7) : Color.white.opacity(0.18)),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    private func inspectLabels() {
        guard isReady, !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let full = try await camera.capturePhoto()
                let cropped = cropToFrame(full)
                inspectorImage = cropped
                rawLabels = try await cascade.rawLabels(cropped)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showInspector = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif

    @discardableResult
    private func save(_ result: Assessment, image: UIImage? = nil) -> FieldEntry? {
        let finalImage = image ?? capturedImage
        let entry = FieldEntry(
            assessment: result,
            imageData: finalImage?.jpegData(compressionQuality: 0.8),
            note: ""
        )

        entry.traceLines = trace

        if let coord = location.coarseCoordinate {
            entry.latitude = coord.latitude
            entry.longitude = coord.longitude
        }
        if let place = location.placeName {
            entry.placeName = place
        }

        modelContext.insert(entry)

        do {
            try modelContext.save()
            return entry
        } catch {
            errorMessage = "Couldn't save to the field log: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: Quadrat corner brackets

enum CornerPosition: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

struct CornerBracket: Shape {
    let position: CornerPosition
    var arm: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch position {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        }
        return path
    }
}

// Keyed on scanID, not content: see the note in Assessment.swift.
extension Assessment: Identifiable {
    var id: UUID { scanID }
}

enum IdentificationError: Error, LocalizedError {
    case badImage
    case noResults

    var errorDescription: String? {
        switch self {
        case .badImage:  return "That photo couldn't be read. Take another."
        case .noResults: return "No match. Fill more of the frame with the subject and try again."
        }
    }
}
