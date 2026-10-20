import SwiftUI
import FMDesignSystem

struct AdminNavTitle: View {
    let title: String
    var subtitle: String = "admin"

    var body: some View {
        VStack(spacing: 1) {
            Text(subtitle)
                .font(.interBold(size: 10))
                .foregroundColor(FMColors.primary)
                .kerning(1.5)
            Text(title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .lineLimit(1)
        }
    }
}
