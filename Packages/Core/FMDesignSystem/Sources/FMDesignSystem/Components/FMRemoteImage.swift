import SwiftUI

/// The single remote-image component in the design system: loads through
/// `FMImageLoader` (memory → disk → network, deduplicated) instead of
/// SwiftUI's uncached `AsyncImage`.
///
/// Callers keep applying their own `.frame` / `.clipShape` / `.overlay` —
/// this view only decides what pixels to show, not how they're framed.
/// `placeholder` covers both "no URL" and "still loading" since there is no
/// network activity worth distinguishing once the shared cache is warm.
public struct FMRemoteImage<Placeholder: View>: View {
    private let urlString: String?
    private let placeholder: () -> Placeholder

    // Seeded synchronously from the memory cache so an already-loaded image
    // never flashes a placeholder on re-appear (matches the pattern
    // FMMatchCard/AdminFieldCard already used with the old FMImageCache).
    @State private var image: UIImage?

    public init(
        urlString: String?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self._image = State(initialValue: urlString.flatMap { FMImageCache.shared.image(for: $0) })
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        guard let urlString else {
            image = nil
            return
        }
        if let cached = await FMImageCache.shared.image(for: urlString) {
            image = cached
            return
        }
        image = await FMImageLoader.shared.load(urlString)
    }
}
