import SwiftUI
import UIKit
import FMDesignSystem

/// Card for a single field in the admin fields list.
/// Full-width image at the top, capacity badge overlay, name / address / price below.
struct AdminFieldCard: View {
    let field: AdminFieldItem
    var onTap: (() -> Void)?

    @State private var cachedImage: UIImage? = nil

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 0) {
                fieldImageView
                infoRow
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .task(id: field.imageUrl) { await loadImage() }
    }

    // MARK: - Image + badge

    private var fieldImageView: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                imageContent(width: proxy.size.width)
                capacityBadge
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    @ViewBuilder
    private func imageContent(width: CGFloat) -> some View {
        if let img = cachedImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 180)
                .clipped()
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 180)
                .clipped()
        }
    }

    private var capacityBadge: some View {
        HStack(spacing: 4) {
            Text("Cupo \(field.capacity)")
                .font(FMTypography.labelSmall)
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
        }
        .foregroundColor(FMColors.onSecondaryFixed)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(FMColors.secondaryFixed))
    }

    // MARK: - Info row

    private var infoRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(field.name)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onSurface)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    Text(field.address ?? "Sin ubicación")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Precio")
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(field.formattedPrice)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Async image load

    private func loadImage() async {
        if let image = await FieldImageLoader.load(field.imageUrl) {
            cachedImage = image
        }
    }
}
