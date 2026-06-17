import UIKit
import FMDesignSystem
import NetworkFramework

/// Loads field images from the API, transparently handling the two shapes the
/// backend may return in `imagePath`:
///
/// 1. A full, pre-signed Cloudinary URL (what the API returns today) — loaded
///    directly.
/// 2. A bare Cloudinary key (per the original docs) — resolved through the
///    authenticated `GET /fields/image/{key}` endpoint, which 302-redirects to
///    the signed URL.
///
/// Successful results are memo-ised in `FMImageCache`, keyed by `imagePath`.
enum FieldImageLoader {

    static func load(_ imagePath: String?) async -> UIImage? {
        guard let imagePath, !imagePath.isEmpty else { return nil }

        if let cached = FMImageCache.shared.image(for: imagePath) {
            return cached
        }

        let data: Data?
        if imagePath.hasPrefix("http"), let url = URL(string: imagePath) {
            data = try? await URLSession.shared.data(from: url).0
        } else {
            data = try? await APIClient.shared.downloadData(
                endpoint: FieldEndpoint.getImage(imageName: imagePath)
            )
        }

        guard let data, let image = UIImage(data: data) else { return nil }
        FMImageCache.shared.store(image, for: imagePath)
        return image
    }
}
