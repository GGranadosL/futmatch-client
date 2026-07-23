import SwiftUI
import FMDesignSystem

/// Full match card for the admin matches list.
/// Shows field image, venue / time / price on the left and occupancy / status on the right.
struct AdminMatchCard: View {
    let match: AdminMatch
    var onTap: (() -> Void)?

    @State private var cachedFieldImage: UIImage?

    init(match: AdminMatch, onTap: (() -> Void)? = nil) {
        self.match = match
        self.onTap = onTap
        // Seed from the cache so a recreated card (list refresh, LazyVStack
        // recycling) renders the image on its first frame instead of flashing
        // the placeholder while `.task` re-fetches it.
        _cachedFieldImage = State(
            initialValue: match.fieldImageUrl.flatMap { FMImageCache.shared.image(for: $0) }
        )
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                fieldImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.fieldName)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onSurface)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(FMColors.onSurfaceVariant)
                        Text("\(match.dateLabel), \(match.timeRange)")
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Text(match.price)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.primary)

                    Text(match.gender.displayName)
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.onSecondaryFixed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(FMColors.secondaryFixed))
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

                    if (match.status == .scheduled || match.status == .inProgress) && match.isIncomplete {
                        Text(L10n.AdminMatches.incomplete)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    if match.status == .completed || match.status == .canceled {
                        statusBadge(for: match.status)
                    }
                }
            }
            .contentShape(Rectangle())
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

    // MARK: - Subviews

    @ViewBuilder
    private var fieldImage: some View {
        if let img = cachedFieldImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            defaultFieldImage
        }
    }

    private var defaultFieldImage: some View {
        Image("defaultField1x1", bundle: .main)
            .resizable()
            .scaledToFill()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadFieldImage() async {
        if let image = await FieldImageLoader.load(match.fieldImageUrl) {
            cachedFieldImage = image
        }
    }

    private func statusBadge(for status: AdminMatchStatus) -> some View {
        let (fg, bg): (Color, Color) = status == .completed
            ? (FMColors.primary, FMColors.primary.opacity(0.12))
            : (FMColors.error, FMColors.error.opacity(0.12))

        return Text(status.displayName)
            .font(FMTypography.labelSmall)
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}

// MARK: - Preview

#Preview {
    AdminMatchCard(match: AdminMatch(
        id: "1",
        fieldName: "Roma 29",
        dateLabel: "Hoy",
        timeRange: "20:00 – 22:00",
        price: "$8/14",
        gender: .mixed,
        playerLevel: .intermediate,
        spotsFilled: 8,
        spotsTotal: 14,
        status: .scheduled,
        fieldImageUrl: nil,
        startDate: Date()
    ))
    .padding()
    .background(FMColors.background)
}
