import UIKit

/// Shared in-memory image cache backed by NSCache.
/// Lives for the duration of the app process — survives view lifecycle changes
/// (navigation push/pop, parent re-renders, @State resets).
public final class FMImageCache {
    public static let shared = FMImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // ~50 MB cap so we don't balloon memory on image-heavy screens
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    public func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    public func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    public func remove(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}
