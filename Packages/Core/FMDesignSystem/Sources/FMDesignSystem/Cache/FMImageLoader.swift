import UIKit

/// Centralizes remote image downloads behind `FMImageCache` so N views
/// requesting the same URL (e.g. the same player's avatar rendered in a
/// lineup, a match card, and a profile screen) share one in-flight request
/// instead of firing N downloads.
public actor FMImageLoader {
    public static let shared = FMImageLoader()

    /// Set once at app launch (from `UserSession`) so authenticated Cloudinary
    /// URLs (containing `/authenticated/`) can be fetched with a bearer token.
    /// Kept as a closure so this package stays free of an `UserSession` dependency.
    private var authTokenProvider: (() async -> String?)?

    /// Optional fallback for keys that aren't plain URLs (e.g. bare Cloudinary
    /// image paths resolved through an authenticated API endpoint). Registered
    /// by AdminFeature at launch; when unset, `load` requires `urlString` to
    /// parse as a `URL`.
    private var dataFetcher: ((String) async -> Data?)?

    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {}

    /// Registers the bearer-token provider. Call once at app launch.
    public func setAuthTokenProvider(_ provider: @escaping () async -> String?) {
        authTokenProvider = provider
    }

    /// Registers the fallback fetcher for non-URL keys. Call once at app launch.
    public func setDataFetcher(_ fetcher: @escaping (String) async -> Data?) {
        dataFetcher = fetcher
    }

    /// Returns the image for `urlString`, checking memory, then disk, then
    /// the network — deduplicating concurrent callers for the same key.
    public func load(_ urlString: String) async -> UIImage? {
        if let cached = await FMImageCache.shared.image(for: urlString) {
            return cached
        }

        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            let result = await self?.download(urlString)
            await self?.clearInFlight(urlString)
            return result
        }
        inFlight[urlString] = task
        return await task.value
    }

    private func clearInFlight(_ key: String) {
        inFlight[key] = nil
    }

    private func download(_ urlString: String) async -> UIImage? {
        let data: Data?
        if let url = URL(string: urlString), urlString.hasPrefix("http") {
            data = await fetchOverHTTP(url: url, urlString: urlString)
        } else if let dataFetcher {
            data = await dataFetcher(urlString)
        } else {
            data = nil
        }

        guard let data, let image = UIImage(data: data) else { return nil }
        FMImageCache.shared.store(data: data, image: image, for: urlString)
        return image
    }

    private func fetchOverHTTP(url: URL, urlString: String) async -> Data? {
        var request = URLRequest(url: url)
        if urlString.contains("/authenticated/"), let authTokenProvider, let token = await authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
            return data
        } catch {
            return nil
        }
    }
}
