//
//  SubjectSegmenter.swift
//  FloraFang
//
//  Finds the organism and isolates it from the background.
//
//  This replaces SubjectCropper, which was written to do the same job and was
//  never wired in. It is a better approach than the fixed square crop in
//  ImageCropping, because it does not assume the subject is centred. A spider
//  photographed off to one side survives this and does not survive a centre
//  crop.
//
//  Both paths are kept. Segmentation can fail, on a photo with no clear
//  foreground subject, and when it does the caller falls back to the square
//  crop rather than to nothing.
//

import CoreImage
import UIKit
import Vision

actor SubjectSegmenter {

    private let context = CIContext()

    /// Returns the subject on a transparent background, or throws if there is
    /// nothing to isolate. Callers should treat a throw as "use the original"
    /// rather than as a failure worth surfacing.
    func isolateSubject(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw IdentificationError.badImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw IdentificationError.noResults
        }

        // croppedToInstancesExtent tightens to the subject's bounding box,
        // which is the whole point. Leaving it false returns a full frame
        // image with the background knocked out, and the classifier would
        // still be looking mostly at empty space.
        let masked = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )

        let ciImage = CIImage(cvPixelBuffer: masked)
        guard let rendered = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw IdentificationError.badImage
        }

        return UIImage(cgImage: rendered, scale: image.scale, orientation: .up)
    }
}
