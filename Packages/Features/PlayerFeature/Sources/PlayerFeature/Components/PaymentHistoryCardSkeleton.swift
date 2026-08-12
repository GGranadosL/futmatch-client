import SwiftUI
import FMDesignSystem

/// Skeleton placeholder that matches the payment history card proportions.
/// Shown while the payment history is loading for the first time.
struct PaymentHistoryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                FMSkeleton(cornerRadius: 4)
                    .frame(width: 90, height: 18)
                Spacer()
                FMSkeleton(cornerRadius: 10)
                    .frame(width: 60, height: 20)
            }

            Divider()

            HStack {
                FMSkeleton(cornerRadius: 4)
                    .frame(width: 100, height: 13)
                Spacer()
                FMSkeleton(cornerRadius: 4)
                    .frame(width: 90, height: 13)
            }

            FMSkeleton(cornerRadius: 4)
                .frame(width: 140, height: 12)
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
