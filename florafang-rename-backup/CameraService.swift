//
//  CameraService.swift
//  Quadrat
//
//  LENS NOTE (v3): this now requests a VIRTUAL multi-camera device
//  (.builtInTripleCamera / .builtInDualWideCamera) rather than the plain wide
//  angle. That matters more than it sounds:
//
//  The main wide camera has a minimum focus distance around 10–12cm. Closer
//  than that it physically cannot focus — no software fix exists. Phones that
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

@Observable
final class CameraService: NSObject {

    enum State: Equatable {
        case idle, ready, denied, interrupted
        case failed(String)
    }

    private(set) var state: State = .idle

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
    private let sessionQueue = DispatchQueue(label: "quadrat.camera.session")

    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    override init() {
        super.init()
        observeSessionNotifications()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Lifecycle

    func start() async {
        guard await requestAccess() else {
            await MainActor.run { state = .denied }
            return
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }

                if !self.isConfigured { self.configure() }

                if self.isConfigured, !self.session.isRunning {
                    self.session.startRunning()
                }

                if self.isConfigured {
                    Task { @MainActor in
                        if self.state != .denied {
                            self.state = self.session.isRunning ? .ready : .interrupted
                        }
                    }
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default:             return false
        }
    }

    // MARK: - Configuration

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        // ORDER MATTERS. Virtual devices first — they're the ones that can
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

        configureDevice(device)
        isConfigured = true
    }

    private func configureDevice(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        // Let the system switch constituent lenses on its own — this is what
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
                // Cap well below the hardware max — past ~8x it's pure upscaling
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

    // MARK: - Zoom

    /// Fill the frame without physically moving closer. For a spider on a wall
    /// this is almost always the right move — moving in hits the focus limit,
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

    // MARK: - Focus

    /// Point is normalized (0...1) in the device's coordinate space — get it
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

    // MARK: - Interruptions

    private func observeSessionNotifications() {
        let center = NotificationCenter.default

        // iOS 18 moved these onto AVCaptureSession as nested names. The old
        // global constants still work but are deprecated.
        center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { [weak self] _ in
            self?.state = .interrupted
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
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in self.state = .ready }
        }
    }

    // MARK: - Capture

    func capturePhoto() async throws -> UIImage {
        guard photoContinuation == nil else { throw CameraError.captureInProgress }
        guard isConfigured else { throw CameraError.notReady }

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
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
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
