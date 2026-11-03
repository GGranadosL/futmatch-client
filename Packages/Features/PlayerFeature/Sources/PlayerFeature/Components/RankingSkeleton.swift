import SwiftUI
import FMDesignSystem

/// Podium and standings placeholders while the ranking loads with nothing cached.
struct RankingSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 8) {
                FMSkeleton(cornerRadius: 16).frame(height: 180)
                FMSkeleton(cornerRadius: 16).frame(height: 210)
                FMSkeleton(cornerRadius: 16).frame(height: 170)
            }
            .padding(.vertical, 8)
            ForEach(0..<5, id: \.self) { _ in
                FMSkeleton(cornerRadius: 16).frame(height: 48)
            }
        }
        .disabled(true)
        .accessibilityHidden(true)
    }
}
