import SwiftUI
import FMDesignSystem

/// Skeleton placeholder matching `AdminMatchCard` proportions.
/// Shown during initial load when there is no cached match data.
struct AdminMatchRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FMSkeleton(cornerRadius: 10)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                FMSkeleton(cornerRadius: 4).frame(width: 140, height: 16)
                FMSkeleton(cornerRadius: 4).frame(width: 110, height: 12)
                FMSkeleton(cornerRadius: 4).frame(width: 64, height: 14)
                FMSkeleton(cornerRadius: 12).frame(width: 68, height: 24)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                FMSkeleton(cornerRadius: 4).frame(width: 40, height: 14)
                FMSkeleton(cornerRadius: 4).frame(width: 60, height: 12)
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
}
