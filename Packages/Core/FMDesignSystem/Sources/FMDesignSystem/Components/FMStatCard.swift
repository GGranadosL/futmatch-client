import SwiftUI

/// Individual statistics card with icon, value and label — designed for horizontal carousels
public struct FMStatCard: View {
    let icon: String
    let value: Int
    let label: String
    /// Fixed card width for carousels; `nil` lets the card share a row equally.
    let width: CGFloat?
    let contentPadding: CGFloat
    
    public init(icon: String, value: Int, label: String, width: CGFloat? = 110, contentPadding: CGFloat = 16) {
        self.icon = icon
        self.value = value
        self.label = label
        self.width = width
        self.contentPadding = contentPadding
    }
    
    /// Cards sharing a row (no fixed width) are narrower, so their icon is smaller too.
    private var isCompact: Bool { width == nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 13 : 20))
                .foregroundColor(FMColors.primary)
                .padding(isCompact ? 5 : 6)
                .background(
                    Circle()
                        .fill(FMColors.primaryContainer)
                )
            
            Text("\(value)")
                .font(FMTypography.headlineSmall)
                .foregroundColor(FMColors.onSurface)
                .bold()
            
            Text(label)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .lineLimit(2, reservesSpace: width == nil)
                .minimumScaleFactor(0.85)
        }
        .padding(contentPadding)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
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

/// Container card that holds multiple stat items in a row
public struct FMStatsRow: View {
    let stats: [StatItem]
    
    public struct StatItem: Identifiable {
        public let id = UUID()
        public let icon: String
        public let value: Int
        public let label: String
        
        public init(icon: String, value: Int, label: String) {
            self.icon = icon
            self.value = value
            self.label = label
        }
    }
    
    public init(stats: [StatItem]) {
        self.stats = stats
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                FMStatCard(
                    icon: stat.icon,
                    value: stat.value,
                    label: stat.label
                )
                
                if index < stats.count - 1 {
                    Divider()
                        .frame(height: 60)
                }
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

// MARK: - Preview
#Preview {
    FMStatsRow(stats: [
        .init(icon: "sportscourt", value: 12, label: "Jugados"),
        .init(icon: "star.fill", value: 12, label: "Ganados"),
        .init(icon: "trophy.fill", value: 12, label: "MVP")
    ])
    .padding()
}
