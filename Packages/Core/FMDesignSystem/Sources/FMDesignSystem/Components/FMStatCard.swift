import SwiftUI

/// Individual statistics card with icon, value and label — designed for horizontal carousels
public struct FMStatCard: View {
    let icon: String
    let value: Int
    let label: String
    
    public init(icon: String, value: Int, label: String) {
        self.icon = icon
        self.value = value
        self.label = label
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(FMColors.primary)
                .padding(6)
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
        }
        .padding(16)
        .frame(width: 110)
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
