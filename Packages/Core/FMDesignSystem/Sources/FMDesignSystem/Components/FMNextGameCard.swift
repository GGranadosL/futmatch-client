import SwiftUI

/// Card showing the user's next upcoming game
/// Displays date, time, location, and a field image
/// Also supports an empty state when no game is scheduled
public struct FMNextGameCard: View {
    let title: String
    let dateLabel: String
    let time: String
    let location: String
    let distance: String?
    let detailLabel: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onDetailTap: (() -> Void)?

    /// - Parameters:
    ///   - location: venue only. Distance goes in `distance` — joining them into one
    ///     string made the distance wrap as if it were part of the address.
    ///   - distance: preformatted, e.g. "3.8 km". Nil or empty hides the line.
    public init(
        title: String,
        dateLabel: String,
        time: String,
        location: String,
        distance: String? = nil,
        detailLabel: String,
        fieldImageUrl: String? = nil,
        fieldImage: Image? = nil,
        onDetailTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.time = time
        self.location = location
        self.distance = distance
        self.detailLabel = detailLabel
        self.fieldImageUrl = fieldImageUrl
        self.fieldImage = fieldImage
        self.onDetailTap = onDetailTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header label
            Text(title)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .padding(.bottom, 8)
            
            HStack(alignment: .top, spacing: 12) {
                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    // Date as a quiet label over the time as the value. Concatenating the
                    // two ("Jue, 10 Sep - 7:00 p.m.") overflowed the column and broke with
                    // the separator dangling at the end of the first line.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateLabel)
                            .font(FMTypography.labelMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)

                        Text(time)
                            .font(FMTypography.titleLarge)
                            .foregroundColor(FMColors.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    // `.firstTextBaseline`, so the pin stays beside the first line of a
                    // wrapped venue name instead of centring itself mid-sentence.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(FMColors.primary)

                        Text(location)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .lineLimit(2)
                    }

                    if let distance, !distance.isEmpty {
                        Text(distance)
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Button {
                        onDetailTap?()
                    } label: {
                        Text(detailLabel)
                            .font(FMTypography.labelLarge)
                            .foregroundColor(FMColors.primary)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // Field image
                fieldImageView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
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
        .frame(width: 84, height: 84)
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
        title: "Tu Próximo Partido",
        dateLabel: "Jue, 10 Sep",
        time: "7:00 p.m.",
        location: "Calzada Casa del Obrero Mundial",
        distance: "3.8 km",
        detailLabel: "Ver detalle"
    )
    .padding()
}
