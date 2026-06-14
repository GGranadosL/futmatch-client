import SwiftUI
import FMDesignSystem

// MARK: - Locations Carousel

public struct LocationsCarouselView: View {
    let locations: [AdminLocation]
    let onLocationTap: ((AdminLocation) -> Void)?

    public init(
        locations: [AdminLocation],
        onLocationTap: ((AdminLocation) -> Void)? = nil
    ) {
        self.locations = locations
        self.onLocationTap = onLocationTap
    }

    public var body: some View {
        if locations.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Ubicaciones")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(locations) { location in
                            LocationsCarouselCardView(location: location)
                                .onTapGesture {
                                    onLocationTap?(location)
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        )
    }
}

// MARK: - Location Carousel Card

private struct LocationsCarouselCardView: View {
    let location: AdminLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Coordinates badge
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                Text("\(String(format: "%.2f", location.latitude))")
                    .font(FMTypography.labelSmall)
            }
            .foregroundColor(FMColors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FMColors.primaryContainer)
            .cornerRadius(6)

            // Address
            Text(location.address)
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.onSurface)
                .lineLimit(2)

            // City
            Text("\(location.city)")
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .lineLimit(1)

            Spacer()

            // Longitude badge
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.2f", location.longitude))
                    .font(FMTypography.labelSmall)
            }
            .foregroundColor(FMColors.onSecondaryFixed)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FMColors.secondaryFixed)
            .cornerRadius(6)
        }
        .frame(width: 180, height: 160)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    LocationsCarouselView(
        locations: [
            AdminLocation(
                id: "1",
                address: "Roma Norte",
                country: "MX",
                city: "MX_CDMX",
                latitude: 19.4326,
                longitude: -99.1332
            ),
            AdminLocation(
                id: "2",
                address: "Polanco",
                country: "MX",
                city: "MX_CDMX",
                latitude: 19.4401,
                longitude: -99.1949
            ),
        ]
    )
}
