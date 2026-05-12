import SwiftUI

/// Card for a suggested game in horizontal scroll
/// Shows field image, venue name badge, price, and time range
public struct FMGameCard: View {
    let venueName: String
    let price: String
    let timeRange: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onTap: (() -> Void)?
    
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
    }
    
    // MARK: - Private
    
    @ViewBuilder
    private var fieldImageView: some View {
        if let urlString = fieldImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image("defaultField1x1", bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let image = fieldImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
