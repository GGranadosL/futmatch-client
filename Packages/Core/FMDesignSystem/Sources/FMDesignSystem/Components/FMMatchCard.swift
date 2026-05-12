import SwiftUI

/// Data model for a match card's team info
public struct FMMatchTeam {
    public let name: String
    public let avatarURLs: [String?]
    public let playerCount: Int
    
    public init(name: String, avatarURLs: [String?] = [], playerCount: Int) {
        self.name = name
        self.avatarURLs = avatarURLs
        self.playerCount = playerCount
    }
}

/// Full match card used in the Matches listing
/// Shows field image, venue, time, price, type, availability badge,
/// team rosters with stacked avatars, and distance
public struct FMMatchCard: View {
    let venueName: String
    let timeRange: String
    let price: String
    let matchType: String
    let spotsLeft: Int
    let spotsLabel: String
    let teamA: FMMatchTeam
    let teamB: FMMatchTeam
    let distance: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onTap: (() -> Void)?
    
    public init(
        venueName: String,
        timeRange: String,
        price: String,
        matchType: String,
        spotsLeft: Int,
        spotsLabel: String,
        teamA: FMMatchTeam,
        teamB: FMMatchTeam,
        distance: String,
        fieldImageUrl: String? = nil,
        fieldImage: Image? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.venueName = venueName
        self.timeRange = timeRange
        self.price = price
        self.matchType = matchType
        self.spotsLeft = spotsLeft
        self.spotsLabel = spotsLabel
        self.teamA = teamA
        self.teamB = teamB
        self.distance = distance
        self.fieldImageUrl = fieldImageUrl
        self.fieldImage = fieldImage
        self.onTap = onTap
    }
    
    public var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 12) {
                topSection
                bottomSection
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
        .buttonStyle(.plain)
    }
    
    // MARK: - Top Section (Image + Info + Price)
    
    private var topSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Field image
            fieldImageView
            
            // Center: venue + time + badge
            VStack(alignment: .leading, spacing: 6) {
                Text(venueName)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onSurface)
                
                Text(timeRange)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                availabilityBadge
            }
            
            Spacer()
            
            // Right: price + type
            VStack(alignment: .trailing, spacing: 6) {
                Text(price)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)
                
                Text(matchType)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
    }
    
    // MARK: - Bottom Section (Teams + Distance)
    
    private var bottomSection: some View {
        HStack(alignment: .center) {
            // Team A
            teamColumn(team: teamA)
            
            Spacer()
            
            // Team B
            teamColumn(team: teamB)
            
            Spacer()
            
            // Distance
            distanceView
        }
    }
    
    // MARK: - Sub-views
    
    @ViewBuilder
    private var fieldImageView: some View {
        if let urlString = fieldImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image("defaultField1x1", bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let image = fieldImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private var availabilityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
            
            Text(spotsLabel)
                .font(FMTypography.labelSmall)
        }
        .foregroundColor(badgeTextColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeBackgroundColor)
        )
    }
    
    private func teamColumn(team: FMMatchTeam) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(team.name)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
            
            FMStackedAvatars(
                avatarURLs: team.avatarURLs,
                totalCount: team.playerCount,
                size: 26,
                maxVisible: 3
            )
        }
    }
    
    private var distanceView: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(FMColors.onSurfaceVariant)
            
            Text(distance)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }
    
    // MARK: - Badge Colors
    
    private var badgeTextColor: Color {
        FMColors.onSecondaryFixed
    }
    
    private var badgeBackgroundColor: Color {
        FMColors.secondaryFixed
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        FMMatchCard(
            venueName: "Roma 29",
            timeRange: "19:50 PM - 21:00 PM",
            price: "$150.00 MXN",
            matchType: "Mixto",
            spotsLeft: 2,
            spotsLabel: "Quedan 2 lugares",
            teamA: FMMatchTeam(
                name: "Equipo A",
                avatarURLs: [nil, nil, nil],
                playerCount: 6
            ),
            teamB: FMMatchTeam(
                name: "Equipo B",
                avatarURLs: [nil],
                playerCount: 1
            ),
            distance: "1.4 km"
        )
    }
    .padding()
}
