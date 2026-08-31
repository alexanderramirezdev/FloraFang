//
//  ImageProcessor.swift
//  FloraFang
//
//  Downscales before inference.
//
//  A full resolution capture from a recent iPhone is large enough that
//  pushing several through the Neural Engine in quick succession is a real
//  memory spike, and it buys nothing: Core ML resizes to 299x299 internally,
//  and the language model tokenizes larger images at higher cost for no
//  additional detail at this scale.
//

import UIKit

actor ImageProcessor {

    /// Scales the longest edge down to maxDimension, preserving aspect ratio.
    /// Images already at or below that size pass through untouched.
    func prepareForInference(_ image: UIImage, maxDimension: CGFloat = 1024) throws -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat()
        // Scale 1 rather than device scale. A 3x render here would undo the
        // downscale entirely, which is a subtle way to make this function a
        // no-op without noticing.
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
