import UIKit

extension UIImage {
    /// Returns a copy whose longest side is at most `maxDimension` **pixels**,
    /// preserving aspect ratio. Images already smaller are not upscaled.
    ///
    /// The result is rendered at scale `1` with EXIF orientation baked in, so
    /// its pixel size equals its point size. This gives every uploaded photo a
    /// consistent resolution regardless of the source device, and keeps the
    /// in-memory image small so the UI stays stable.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let pixelWidth  = size.width * scale
        let pixelHeight = size.height * scale
        let longestSide = max(pixelWidth, pixelHeight)

        let ratio   = longestSide > maxDimension ? maxDimension / longestSide : 1
        let newSize = CGSize(width: (pixelWidth * ratio).rounded(),
                             height: (pixelHeight * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale  = 1       // 1 pixel per point → predictable output size
        format.opaque = true    // JPEG has no alpha; avoids a wasted alpha channel

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            // `draw(in:)` honours the image's orientation, normalising it to `.up`.
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Downscales then JPEG-encodes the image for upload in one step.
    /// Returns `nil` only if JPEG encoding fails.
    func normalizedForUpload(maxDimension: CGFloat, compressionQuality: CGFloat) -> (image: UIImage, data: Data)? {
        let resized = downscaled(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else { return nil }
        return (resized, data)
    }
}
