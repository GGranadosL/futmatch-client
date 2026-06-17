import SwiftUI
import FMDesignSystem

/// Stats card showing the total number of registered locations
/// This is displayed in the admin panel dashboard
public struct LocationsStatsView: View {
    let count: Int
    let onTap: () -> Void

    public init(count: Int, onTap: @escaping () -> Void) {
        self.count = count
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FMColors.primary)
                        .padding(6)
                        .background(Circle().fill(FMColors.primaryContainer))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FMColors.onSurfaceVariant)
                }

                Text(String(format: "%02d", count))
                    .font(FMTypography.headlineSmall)
                    .foregroundColor(FMColors.onSurface)
                    .bold()

                Text("Ubicaciones registradas")
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}
