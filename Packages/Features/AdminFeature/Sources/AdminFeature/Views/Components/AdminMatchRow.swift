import SwiftUI
import FMDesignSystem
import UIKit

/// Compact match row for the admin home "Próximos Partidos" list.
/// Field image + venue/date/price on the left, occupancy + type on the right.
struct AdminMatchRow: View {
    let match: AdminUpcomingMatch
    var onTap: (() -> Void)?
    @State private var cachedFieldImage: UIImage?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                fieldImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.venueName)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onSurface)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(FMColors.onSurfaceVariant)
                        Text("\(match.dateLabel), \(match.time)")
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Text(match.price)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text(match.occupancyLabel)
                            .font(FMTypography.labelMedium)
                    }
                    .foregroundColor(FMColors.onSurfaceVariant)

                    if match.isIncomplete {
                        Text(L10n.AdminMatches.incomplete)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Text(match.matchType)
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.onSecondaryFixed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(FMColors.secondaryFixed))
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
        .buttonStyle(.plain)
        .task(id: match.fieldImageUrl) { await loadFieldImage() }
    }

    @ViewBuilder
    private var fieldImage: some View {
        if let img = cachedFieldImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func loadFieldImage() async {
        guard let img = await FieldImageLoader.load(match.fieldImageUrl) else { return }
        cachedFieldImage = img
    }
}

// MARK: - Preview
#Preview {
    AdminMatchRow(match: AdminUpcomingMatch(
        id: "1",
        venueName: "Roma 29",
        dateLabel: "Hoy",
        time: "20:00",
        price: "$15.000",
        matchType: "Mixto",
        spotsFilled: 8,
        spotsTotal: 14
    ))
    .padding()
    .background(FMColors.background)
}
