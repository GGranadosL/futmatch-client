import SwiftUI
import FMDesignSystem

/// Matches `HomeRankingCard`'s ranked layout while Home loads with no summary yet.
struct HomeRankingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FMSkeleton(cornerRadius: 4).frame(width: 140, height: 16)
            HStack(spacing: 12) {
                FMSkeleton(cornerRadius: 6).frame(width: 48, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 150, height: 14)
                    FMSkeleton(cornerRadius: 4).frame(width: 100, height: 12)
                }
            }
            FMSkeleton(cornerRadius: 4).frame(width: 190, height: 14)
            FMSkeleton(cornerRadius: 10).frame(maxWidth: .infinity).frame(height: 38)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(FMColors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMColors.outlineVariant, lineWidth: 1))
        .disabled(true)
        .accessibilityHidden(true)
    }
}
