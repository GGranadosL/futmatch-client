import SwiftUI

/// Tertiary badge showing user rating/average score
/// Used in Home header next to greeting
public struct FMRatingBadge: View {
    let score: Int
    let label: String
    
    public init(score: Int, label: String) {
        self.score = score
        self.label = label
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(FMColors.onTertiary)
            
            Text("\(score)")
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.onTertiary)
            
            Text(label)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(FMColors.tertiary)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        FMRatingBadge(score: 84, label: "Promedio")
        FMRatingBadge(score: 65, label: "Promedio")
        FMRatingBadge(score: 40, label: "Promedio")
    }
    .padding()
}
