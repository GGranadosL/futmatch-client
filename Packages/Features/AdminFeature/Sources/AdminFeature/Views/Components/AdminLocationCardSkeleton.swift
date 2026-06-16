import SwiftUI
import FMDesignSystem

/// Skeleton placeholder matching `LocationCard` proportions exactly.
/// Shown while the locations list loads for the first time (no cached data).
struct AdminLocationCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 200, height: 16)
                    FMSkeleton(cornerRadius: 4).frame(width: 130, height: 12)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 72, height: 11)
                    FMSkeleton(cornerRadius: 4).frame(width: 72, height: 11)
                }
            }
            FMSkeleton(cornerRadius: 8)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
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
}
