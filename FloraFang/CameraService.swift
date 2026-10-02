//
//  CameraService.swift
//  FloraFang
//
//  LENS NOTE (v3): this now requests a VIRTUAL multi-camera device
//  (.builtInTripleCamera / .builtInDualWideCamera) rather than the plain wide
//  angle. That matters more than it sounds:
//
//  The main wide camera has a minimum focus distance around 10 to 12cm. Closer
//  than that it physically cannot focus: no software fix exists. Phones that
//  do macro achieve it by switching to the ULTRA-WIDE lens, and that switch
//  only happens automatically if the app asked for a virtual device in the
//  first place. Asking for .builtInWideAngleCamera explicitly opts out of the
//  hardware's macro capability.
//
//  Combined with zoom (fill the frame without moving closer), this is what
//  makes small subjects on walls actually workable.
//

import AVFoundation
import UIKit

enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
    case action = "action"
    case detail = "detail"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .action: return "Action"
        case .detail: return "Detail"
        }
    }

    var subtitle: String {
        switch self {
        case .action: return "Instant shutter for fast spiders and bugs"
        case .detail: return "Deep Fusion for still plants and fungi"
        }
    }

    var systemIcon: String {
        switch self {
        case .action: return "bolt.fill"
        case .detail: return "sparkles"
        }
    }
}

@Observable
final class CameraService: NSObject {

    enum State: Equatable {
        case idle, ready, denied, interrupted
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Active shutter mode: action for instant reflex release, detail for deep fusion
    private(set) var captureMode: CaptureMode = .action

    /// Current zoom, in the device's own factor units.
    private(set) var zoomFactor: CGFloat = 1

    /// Range we allow the UI to drive.
    private(set) var minZoom: CGFloat = 1
    private(set) var maxZoom: CGFloat = 8

    /// Closest focusable distance in cm, or nil if the device won't report it.
    /// Surfaced so the UI can tell the user how close is too close.
    private(set) var minimumFocusDistanceCM: Double?

    /// True when the active device can drop to an ultra-wide for macro.
    private(set) var supportsMacro = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.aramirez.florafang.camera.session")

    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    /// What the app currently wants: running or stopped. Read and written
    /// only on sessionQueue, so a queued stop and a queued start always
    /// resolve in the order they were asked for.
    @ObservationIgnored private var wantsRunning = false

    /// Bumped by every start() and stop() on the main actor. Async work that
    /// finishes later only writes `state` if no newer start or stop has
    /// happened since, so a slow stop can't overwrite a fresh .ready with a
    /// stale .idle (the "big delay" coming back from the Exposure tab).
    @ObservationIgnored private var lifecycleGeneration = 0

    @ObservationIgnored private var pressureObservation: NSKeyValueObservation?

    override init() {
        super.init()
        observeSessionNotifications()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: Lifecycle

    func start() async {
        guard await requestAccess() else {
            state = .denied
            return
        }

        lifecycleGeneration += 1
        let generation = lifecycleGeneration

        // Two attempts: startRunning can come back not running when it lands
        // right behind a stopRunning from a tab switch.
        for attempt in 0..<2 {
            let running: Bool = await withCheckedContinuation { continuation in
                sessionQueue.async { [weak self] in
                    guard let self else { continuation.resume(returning: false); return }

                    self.wantsRunning = true
                    if !self.isConfigured { self.configure() }

                    if self.isConfigured, !self.session.isRunning {
                        self.session.startRunning()
                    }

                    continuation.resume(returning: self.isConfigured && self.session.isRunning && !self.session.isInterrupted)
                }
            }

            // A newer start or stop owns the state now.
            guard generation == lifecycleGeneration else { return }
            // configure() already reported its own .failed reason.
            guard isConfigured else { return }

            if running {
                state = .ready
                return
            }
            if attempt == 0 {
                try? await Task.sleep(for: .milliseconds(400))
                guard generation == lifecycleGeneration else { return }
            }
        }

        state = .interrupted
    }

    func stop() {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            Task { @MainActor in
                guard generation == self.lifecycleGeneration else { return }
                self.state = .idle
            }
        }
    }

    /// Escape hatch behind the "Restart camera" button: a full stop and
    /// start, which clears a session iOS left wedged after an interruption.
    func forceRestart() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                if self.session.isRunning { self.session.stopRunning() }
                continuation.resume()
            }
        }
        await start()
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default:             return false
        }
    }

    // MARK: Configuration

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        // ORDER MATTERS. Virtual devices first: they're the ones that can
        // switch lenses for macro. Plain wide angle is the last resort.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,     // Pro: ultra-wide + wide + tele
                .builtInDualWideCamera,   // ultra-wide + wide
                .builtInDualCamera,       // wide + tele (no macro)
                .builtInWideAngleCamera   // single lens fallback
            ],
            mediaType: .video,
            position: .back
        )

        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            fail("No camera found on this device.")
            return
        }
        self.device = device

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            fail("Couldn't open the camera. Another app may be using it.")
            return
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            fail("Couldn't attach the photo output.")
            return
        }
        session.addOutput(photoOutput)

        // Configure prioritization based on active mode
        if captureMode == .action {
            if photoOutput.isZeroShutterLagSupported {
                photoOutput.isZeroShutterLagEnabled = true
            }
            photoOutput.maxPhotoQualityPrioritization = .speed
        } else {
            if photoOutput.isZeroShutterLagSupported {
                photoOutput.isZeroShutterLagEnabled = false
            }
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        configureDevice(device)

        // Watch for heat and load. Sustained camera plus Core ML plus
        // Foundation Models right after a shot is exactly what raises it.
        pressureObservation = device.observe(\.systemPressureState, options: [.new]) { @Sendable device, _ in
            CameraService.applyPressure(to: device)
        }

        isConfigured = true
    }

    /// Apple's guidance under system pressure is to cut the frame rate
    /// before iOS interrupts the session outright. A 15 fps viewfinder is
    /// plenty for framing a spider, and it keeps the camera alive.
    nonisolated private static func applyPressure(to device: AVCaptureDevice) {
        let level = device.systemPressureState.level
        let throttle = (level == .serious || level == .critical)

        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        if throttle {
            let supports15 = device.activeFormat.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= 15 && $0.maxFrameRate >= 15
            }
            guard supports15 else { return }
            let frame = CMTime(value: 1, timescale: 15)
            device.activeVideoMinFrameDuration = frame
            device.activeVideoMaxFrameDuration = frame
        } else {
            // .invalid restores the format's default frame rate.
            device.activeVideoMinFrameDuration = .invalid
            device.activeVideoMaxFrameDuration = .invalid
        }
    }

    func setCaptureMode(_ mode: CaptureMode) {
        guard mode != captureMode else { return }
        captureMode = mode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if mode == .action {
                if self.photoOutput.isZeroShutterLagSupported {
                    self.photoOutput.isZeroShutterLagEnabled = true
                }
                self.photoOutput.maxPhotoQualityPrioritization = .speed
            } else {
                if self.photoOutput.isZeroShutterLagSupported {
                    self.photoOutput.isZeroShutterLagEnabled = false
                }
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
        }
    }

    private func configureDevice(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        // Let the system switch constituent lenses on its own: this is what
        // enables automatic macro when you move in close.
        if device.isVirtualDevice {
            device.setPrimaryConstituentDeviceSwitchingBehavior(
                .auto,
                restrictedSwitchingBehaviorConditions: []
            )
        }

        // Start framed like the main camera rather than the ultra-wide. On a
        // triple-camera device zoom factor 1.0 IS the ultra-wide, which looks
        // wrong if you're expecting the normal 1x view.
        if let firstSwitchover = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            let factor = CGFloat(truncating: firstSwitchover)
            device.videoZoomFactor = factor
            Task { @MainActor in
                self.zoomFactor = factor
                self.minZoom = device.minAvailableVideoZoomFactor
                // Cap well below the hardware max: past ~8x it's pure upscaling
                // and gives the classifier nothing but noise.
                self.maxZoom = min(device.maxAvailableVideoZoomFactor, factor * 6)
            }
        }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        let macroCapable = device.isVirtualDevice
            && device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }

        // Reported in millimetres; -1 means unknown.
        let focusMM = device.minimumFocusDistance
        Task { @MainActor in
            self.supportsMacro = macroCapable
            self.minimumFocusDistanceCM = focusMM > 0 ? Double(focusMM) / 10.0 : nil
        }
    }

    private func fail(_ reason: String) {
        Task { @MainActor in self.state = .failed(reason) }
    }

    // MARK: Zoom

    /// Fill the frame without physically moving closer. For a spider on a wall
    /// this is almost always the right move: moving in hits the focus limit,
    /// zooming doesn't.
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.device else { return }
            guard (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }

            let clamped = min(max(factor, device.minAvailableVideoZoomFactor),
                              min(device.maxAvailableVideoZoomFactor, self.maxZoom))
            device.videoZoomFactor = clamped
            Task { @MainActor in self.zoomFactor = clamped }
        }
    }

    // MARK: Focus

    /// Point is normalized (0...1) in the device's coordinate space: get it
    /// from AVCaptureVideoPreviewLayer.captureDevicePointConverted.
    ///
    /// Autofocus hunts badly on a flat textured wall because there's no obvious
    /// subject. Letting the user tap the spider fixes that directly.
    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.device else { return }
            guard (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
        }
    }

    // MARK: Interruptions

    private func observeSessionNotifications() {
        let center = NotificationCenter.default

        // iOS 18 moved these onto AVCaptureSession as nested names. The old
        // global constants still work but are deprecated.
        center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { [weak self] note in
            guard let self else { return }
            if let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
               let reason = AVCaptureSession.InterruptionReason(rawValue: raw) {
                print("[FloraFang] camera interrupted, reason \(reason.rawValue)")
            }
            self.state = .interrupted

            // Belt and braces: if the ended notification never arrives,
            // check again on our own instead of leaving "paused" up.
            Task { @MainActor [weak self] in
                for delay in [1.5, 4.0] {
                    try? await Task.sleep(for: .seconds(delay))
                    guard let self, self.state == .interrupted else { return }
                    self.restart()
                }
            }
        }

        center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: .main) { [weak self] _ in
            self?.restart()
        }

        center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] note in
            guard let self else { return }
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
            if error?.code == .mediaServicesWereReset {
                self.restart()
            } else {
                self.state = .failed("Camera error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    private func restart() {
        let generation = lifecycleGeneration
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.wantsRunning else { return }

            // THE "CAMERA PAUSED" BUG: iOS usually resumes the session on its
            // own when an interruption ends, so it is often already running
            // here. The old guard bailed out in that case without ever
            // clearing .interrupted, which left "Camera paused" on screen
            // after every shot until a tab switch forced a full restart.
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning && !self.session.isInterrupted

            Task { @MainActor in
                guard generation == self.lifecycleGeneration else { return }
                self.state = running ? .ready : .interrupted
            }
        }
    }

    // MARK: Capture

    func capturePhoto(mode: CaptureMode? = nil) async throws -> UIImage {
        guard photoContinuation == nil else { throw CameraError.captureInProgress }
        guard isConfigured else { throw CameraError.notReady }

        let targetMode = mode ?? self.captureMode

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            sessionQueue.async { [weak self] in
                guard let self else { return }
                guard self.session.isRunning else {
                    Task { @MainActor in
                        self.photoContinuation?.resume(throwing: CameraError.notReady)
                        self.photoContinuation = nil
                    }
                    return
                }

                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                } else {
                    settings = AVCapturePhotoSettings()
                }

                settings.photoQualityPrioritization = (targetMode == .action ? .speed : .quality)

                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

enum CameraError: Error, LocalizedError {
    case notReady, captureInProgress

    var errorDescription: String? {
        switch self {
        case .notReady:          return "The camera isn't ready yet. Try again in a moment."
        case .captureInProgress: return "Still working on the last photo."
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {

    /// AVFoundation delivers this on its own internal queue, not the main
    /// actor. Under default main actor isolation the conformance would be
    /// @MainActor, which is a lie about where the callback actually arrives.
    ///
    /// So: mark it nonisolated, do the image work here off the main actor,
    /// then hop deliberately to resume the continuation, which touches
    /// main-actor state.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: Result<UIImage, Error>

        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(IdentificationError.badImage)
        }

        Task { @MainActor in
            self.finishCapture(result)
        }
    }

    /// Normalizing orientation touches UIGraphicsImageRenderer, so it stays
    /// on the main actor with the rest of the state mutation.
    @MainActor
    private func finishCapture(_ result: Result<UIImage, Error>) {
        let continuation = photoContinuation
        photoContinuation = nil

        switch result {
        case .success(let image):
            continuation?.resume(returning: image.normalizedUp())
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}
