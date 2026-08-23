//
//  ImageCropping.swift
//  FloraFang
//
//  The single most important accuracy fix in the app.
//
//  Vision's .centerCrop takes the middle square of the FULL FRAME. When you
//  photograph a spider on a wall from arm's length, that middle square is
//  ~98% stucco. The classifier is not failing at spiders — it's correctly
//  describing a wall, because that's what it was shown.
//
//  Cropping to the on-screen capture square before classification means the
//  model sees what the user framed.
//

import UIKit

extension UIImage {

    /// Redraws the image with .up orientation so downstream pixel math is sane.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Crops the region the on-screen capture square was covering.
    ///
    /// The preview uses .resizeAspectFill, so the image is scaled by
    /// max(previewW/imageW, previewH/imageH) and overflow is clipped. Inverting
    /// that scale converts the square's side length in points into pixels.
    ///
    /// Assumes the square is centered in the preview, which it is.
    ///
    /// - Parameters:
    ///   - squareSide: side length of the capture square, in points
    ///   - previewSize: size of the preview view, in points
    ///   - padding: extra margin around the square, 0.0–1.0. A little context
    ///     helps the classifier; too much reintroduces the background problem.
    func croppedToFrame(
        squareSide: CGFloat,
        previewSize: CGSize,
        padding: CGFloat = 0.15
    ) -> UIImage {
        guard let cg = cgImage, previewSize.width > 0, previewSize.height > 0 else { return self }

        let pixelWidth = CGFloat(cg.width)
        let pixelHeight = CGFloat(cg.height)

        // Points per pixel under aspect-fill.
        let scale = max(previewSize.width / pixelWidth, previewSize.height / pixelHeight)
        guard scale > 0 else { return self }

        var side = (squareSide / scale) * (1 + padding)
        side = min(side, min(pixelWidth, pixelHeight))

        let rect = CGRect(
            x: (pixelWidth - side) / 2,
            y: (pixelHeight - side) / 2,
            width: side,
            height: side
        ).integral

        guard let cropped = cg.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped, scale: self.scale, orientation: .up)
    }
}
