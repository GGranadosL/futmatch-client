import UIKit
import CryptoKit

/// Shared two-level image cache: an in-memory `NSCache` for the current
/// process, backed by a disk cache under `Library/Caches` so thumbnails
/// (player avatars, field images) survive app relaunches.
///
/// Lives for the duration of the app process — survives view lifecycle
/// changes (navigation push/pop, parent re-renders, @State resets).
public final class FMImageCache {
    public static let shared = FMImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL
    private let diskQueue = DispatchQueue(label: "com.futmatch.FMImageCache.disk", qos: .utility)

    /// Disk budget. Purged LRU (by file modification date) down to this size.
    private let diskCapacityBytes = 200 * 1024 * 1024

    private init() {
        // ~50 MB cap so we don't balloon memory on image-heavy screens
        memoryCache.totalCostLimit = 50 * 1024 * 1024

        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        diskDirectory = (cachesDir ?? FileManager.default.temporaryDirectory).appendingPathComponent(
            "FMImageCache", isDirectory: true
        )
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Memory (synchronous)

    /// Memory-only lookup. Use for seeding `@State` synchronously (e.g. from
    /// a view's `init`) so an already-loaded image never flashes a placeholder.
    public func image(for key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    /// Stores in memory only. Callers that also want disk persistence should
    /// use `store(data:for:)` instead.
    public func store(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString, cost: cost(of: image))
    }

    public func remove(for key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }

    // MARK: - Memory + Disk (asynchronous)

    /// Checks memory, then disk. Populates memory on a disk hit.
    ///
    /// The memory lookup reads `memoryCache` directly rather than calling the
    /// synchronous `image(for:)` overload: in an async context Swift resolves that
    /// call to *this* function, so it recursed into itself forever. Async frames
    /// live on the heap, so it grew to gigabytes instead of overflowing the stack.
    public func image(for key: String) async -> UIImage? {
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        guard let data = await readDisk(for: key), let image = UIImage(data: data) else {
            return nil
        }
        memoryCache.setObject(image, forKey: key as NSString, cost: cost(of: image))
        return image
    }

    /// Stores the raw downloaded bytes on disk (no re-encoding) and the
    /// decoded image in memory.
    public func store(data: Data, image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString, cost: cost(of: image))
        writeDisk(data: data, for: key)
    }

    /// Clears both cache levels — call on logout so one account's photos
    /// never linger for the next.
    public func clearAll() {
        memoryCache.removeAllObjects()
        diskQueue.async { [diskDirectory] in
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: diskDirectory, includingPropertiesForKeys: nil
            ) else { return }
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Purges the disk cache down to `diskCapacityBytes`, oldest files first.
    /// Call once at app launch, off the main thread.
    public func purgeDiskIfNeeded() {
        diskQueue.async { [diskDirectory, diskCapacityBytes] in
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: diskDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else { return }

            let entries: [(url: URL, date: Date, size: Int)] = files.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let date = values.contentModificationDate,
                      let size = values.fileSize else { return nil }
                return (url, date, size)
            }

            var totalSize = entries.reduce(0) { $0 + $1.size }
            guard totalSize > diskCapacityBytes else { return }

            for entry in entries.sorted(by: { $0.date < $1.date }) {
                guard totalSize > diskCapacityBytes else { break }
                try? FileManager.default.removeItem(at: entry.url)
                totalSize -= entry.size
            }
        }
    }

    // MARK: - Private

    private func cost(of image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * 4)
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(hex)
    }

    private func readDisk(for key: String) async -> Data? {
        let url = fileURL(for: key)
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                continuation.resume(returning: try? Data(contentsOf: url))
            }
        }
    }

    private func writeDisk(data: Data, for key: String) {
        let url = fileURL(for: key)
        diskQueue.async {
            try? data.write(to: url, options: .atomic)
        }
    }
}
