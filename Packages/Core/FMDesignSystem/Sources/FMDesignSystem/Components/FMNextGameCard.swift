import SwiftUI

/// Compact card showing the user's next upcoming game: date, time, address, venue,
/// a field thumbnail on the right and two actions (view match, directions).
public struct FMNextGameCard: View {
    let title: String
    let dateLabel: String
    let time: String
    let address: String
    let fieldName: String
    let detailLabel: String
    let directionsLabel: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onDetailTap: (() -> Void)?
    var onDirectionsTap: (() -> Void)?

    /// - Parameters:
    ///   - address: full venue address; truncated to one line so a long address never grows the card.
    ///   - fieldName: venue name shown beside the pin.
    ///   - directionsLabel: accessibility label of the icon-only directions button.
    public init(
        title: String,
        dateLabel: String,
        time: String,
        address: String,
        fieldName: String,
        detailLabel: String,
        directionsLabel: String,
        fieldImageUrl: String? = nil,
        fieldImage: Image? = nil,
        onDetailTap: (() -> Void)? = nil,
        onDirectionsTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.time = time
        self.address = address
        self.fieldName = fieldName
        self.detailLabel = detailLabel
        self.directionsLabel = directionsLabel
        self.fieldImageUrl = fieldImageUrl
        self.fieldImage = fieldImage
        self.onDetailTap = onDetailTap
        self.onDirectionsTap = onDirectionsTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    Text(time)
                        .font(FMTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(FMColors.onSurface)
                        .lineLimit(1)

                    Text(address)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(FMColors.onSurfaceVariant)

                        Text(fieldName)
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                fieldImageView
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)

                Button {
                    onDetailTap?()
                } label: {
                    Text(detailLabel)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }

                Button {
                    onDirectionsTap?()
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 15))
                        .foregroundColor(FMColors.onSurface)
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(FMColors.outlineVariant, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(directionsLabel)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Private

    @ViewBuilder
    private var fieldImageView: some View {
        Group {
            if fieldImageUrl != nil {
                FMRemoteImage(urlString: fieldImageUrl) {
                    defaultFieldImage
                }
            } else {
                defaultFieldImage
            }
        }
        .scaledToFill()
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var defaultFieldImage: some View {
        if let image = fieldImage {
            image.resizable().scaledToFill()
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
        }
    }
}

// MARK: - Previews
#Preview("With Game") {
    FMNextGameCard(
        title: "Tu próximo partido",
        dateLabel: "Mañana",
        time: "8:00 a. m.",
        address: "Calzada Casa del Obrero Mundial, Ciudad de México",
        fieldName: "La Jaula",
        detailLabel: "Ver partido",
        directionsLabel: "Cómo llegar"
    )
    .padding()
}
