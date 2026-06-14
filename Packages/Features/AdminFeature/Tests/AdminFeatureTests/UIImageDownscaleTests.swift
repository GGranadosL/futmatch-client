import XCTest
import UIKit
@testable import AdminFeature

final class UIImageDownscaleTests: XCTestCase {

    func test_downscaled_largeImage_capsLongestSideToMax() {
        let image = makeImage(width: 4000, height: 3000)
        let result = image.downscaled(maxDimension: 1280)

        XCTAssertEqual(longestSidePixels(result), 1280, accuracy: 1)
    }

    func test_downscaled_preservesAspectRatio() {
        let image = makeImage(width: 4000, height: 3000)   // 4:3
        let result = image.downscaled(maxDimension: 1280)

        XCTAssertEqual(result.size.width / result.size.height, 4.0 / 3.0, accuracy: 0.01)
    }

    func test_downscaled_smallImage_isNotUpscaled() {
        let image = makeImage(width: 200, height: 100)
        let result = image.downscaled(maxDimension: 1280)

        XCTAssertEqual(longestSidePixels(result), 200, accuracy: 1)
    }

    func test_downscaled_portraitImage_capsHeight() {
        let image = makeImage(width: 1080, height: 1920)   // portrait
        let result = image.downscaled(maxDimension: 1280)

        XCTAssertEqual(longestSidePixels(result), 1280, accuracy: 1)
        XCTAssertTrue(result.size.height > result.size.width)
    }

    func test_normalizedForUpload_returnsResizedImageAndData() {
        let image = makeImage(width: 4000, height: 3000)
        let result = image.normalizedForUpload(maxDimension: 1280, compressionQuality: 0.8)

        XCTAssertNotNil(result)
        XCTAssertEqual(longestSidePixels(result!.image), 1280, accuracy: 1)
        XCTAssertFalse(result!.data.isEmpty)
    }

    // MARK: - Helpers

    private func longestSidePixels(_ image: UIImage) -> CGFloat {
        max(image.size.width * image.scale, image.size.height * image.scale)
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
