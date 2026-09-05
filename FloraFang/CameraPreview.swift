//
//  CameraPreview.swift
//  FloraFang
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called with a normalized device point when the user taps to focus.
    var onFocusTap: (CGPoint, CGPoint) -> Void = { _, _ in }
    /// Called with a zoom multiplier during a pinch.
    var onPinch: (CGFloat, UIGestureRecognizer.State) -> Void = { _, _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.parent = self
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: CameraPreview
        weak var view: PreviewView?

        init(_ parent: CameraPreview) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let location = gesture.location(in: view)
            // Convert view coordinates to the device's own normalized space:
            // this accounts for videoGravity, so it's correct even though the
            // preview is cropping the image.
            let devicePoint = view.videoPreviewLayer
                .captureDevicePointConverted(fromLayerPoint: location)
            parent.onFocusTap(devicePoint, location)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            parent.onPinch(gesture.scale, gesture.state)
            if gesture.state == .changed { gesture.scale = 1 }
        }
    }

    /// Backing the view with the preview layer means it resizes automatically.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
