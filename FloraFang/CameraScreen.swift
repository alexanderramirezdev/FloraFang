//
//  CameraScreen.swift
//  FloraFang
//

import SwiftUI
import SwiftData
import AVFoundation

struct CameraScreen: View {
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

    // Label inspector (development tool: long-press the shutter)
    @State private var rawLabels: [RankedLabel] = []
    @State private var inspectorImage: UIImage?
    @State private var showInspector = false

    // Focus indicator
    @State private var focusPoint: CGPoint?
    @State private var focusPulse = false

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
                message("Quadrat needs the camera to identify anything. Enable it in Settings → Quadrat.")
            case .interrupted:
                message("Camera paused. This usually clears on its own. If it does not, switch tabs and come back.")
            case .failed(let reason):
                message(reason)
            case .idle:
                ProgressView().tint(Palette.parchment)
            }

            VStack {
                header
                Spacer()
                if isReady { quadratFrame }
                Spacer()
                if isReady { zoomControl }
                shutter
            }
            .padding(.vertical, 24)
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            Task { await camera.start() }
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
        .sheet(isPresented: $showInspector) {
            LabelInspectorSheet(labels: rawLabels, image: inspectorImage)
        }
        .alert("Scan failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Preview

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

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 3) {
            Text("FLORAFANG")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .tracking(4)
                .foregroundStyle(Palette.parchment)
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
                Text("zoom until the subject fills the square")
                    .font(.system(size: 11.5, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.parchment)
                Text("tap to focus · long-press shutter for raw labels")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Palette.parchment.opacity(0.72))
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
                Text(camera.supportsMacro
                     ? "closer than ~\(Int(cm))cm switches to macro automatically"
                     : "can't focus closer than ~\(Int(cm))cm, zoom instead of moving in")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.lichen.opacity(0.7))
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    private var shutter: some View {
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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in inspectLabels() }
        )
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

    // MARK: - Actions

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
        isWorking = true
        location.refresh()
        Task {
            defer { isWorking = false }
            do {
                let full = try await camera.capturePhoto()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let cropped = cropToFrame(full)

                capturedImage = cropped
                let result = try await cascade.assess(cropped)
                trace = cascade.lastTrace

                savedEntry = save(result)
                assessment = result
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

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

    @discardableResult
    private func save(_ result: Assessment) -> FieldEntry? {
        let entry = FieldEntry(
            assessment: result,
            imageData: capturedImage?.jpegData(compressionQuality: 0.8),
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

// MARK: - Quadrat corner brackets

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
