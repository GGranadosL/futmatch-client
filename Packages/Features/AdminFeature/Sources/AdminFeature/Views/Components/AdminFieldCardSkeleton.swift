import SwiftUI
import FMDesignSystem

/// Skeleton placeholder that matches `AdminFieldCard` proportions exactly.
/// Shown while the fields list is loading for the first time (no cached data).
struct AdminFieldCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area
            FMSkeleton(cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 180)

            // Info row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    // Name
                    FMSkeleton(cornerRadius: 4)
                        .frame(width: 160, height: 16)
                    // Address
                    FMSkeleton(cornerRadius: 4)
                        .frame(width: 110, height: 12)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // "Precio" label
                    FMSkeleton(cornerRadius: 4)
                        .frame(width: 42, height: 11)
                    // Price value
                    FMSkeleton(cornerRadius: 4)
                        .frame(width: 64, height: 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
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
}
