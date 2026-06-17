import SwiftUI
import UIKit

/// Card for a suggested game in horizontal scroll
/// Shows field image, venue name badge, price, and time range
public struct FMGameCard: View {
    let venueName: String
    let price: String
    let timeRange: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onTap: (() -> Void)?

    /// Cached downloaded image — survives re-renders caused by parent state changes.
    @State private var cachedFieldImage: UIImage? = nil

    public init(
        venueName: String,
        price: String,
        timeRange: String,
        fieldImageUrl: String? = nil,
        fieldImage: Image? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.venueName = venueName
        self.price = price
        self.timeRange = timeRange
        self.fieldImageUrl = fieldImageUrl
        self.fieldImage = fieldImage
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Field image with venue name badge
                ZStack(alignment: .bottomTrailing) {
                    fieldImageView

                    // Venue badge
                    Text(venueName)
                        .font(FMTypography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(FMColors.primary.opacity(0.85))
                        )
                        .padding(8)
                }

                // Price
                Text(price)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)

                // Time range
                Text(timeRange)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
        .task(id: fieldImageUrl) {
            await loadFieldImage()
        }
    }

    // MARK: - Private

    @ViewBuilder
    private var fieldImageView: some View {
        Group {
            if let cached = cachedFieldImage {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else if let image = fieldImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image("defaultField1x1", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 160, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadFieldImage() async {
        guard
            let urlString = fieldImageUrl,
            let url = URL(string: urlString)
        else {
            cachedFieldImage = nil
            return
        }

        // Return immediately if already in the shared cache
        if let cached = FMImageCache.shared.image(for: urlString) {
            cachedFieldImage = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return }
            guard let downloaded = UIImage(data: data) else { return }
            FMImageCache.shared.store(downloaded, for: urlString)
            cachedFieldImage = downloaded
        } catch {
            // Silently fail — default image stays visible
        }
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 12) {
        FMGameCard(
            venueName: "Roma 28",
            price: "$150.00 MXN",
            timeRange: "19:50 PM - 21:00 PM"
        )

        FMGameCard(
            venueName: "Roma 28",
            price: "$150.00 MXN",
            timeRange: "19:50 PM - 21:00 PM"
        )
    }
    .padding()
}
