import SwiftUI
import UIKit

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

    /// Cached downloaded image — survives re-renders caused by parent state changes.
    @State private var cachedFieldImage: UIImage? = nil
    
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
        .task(id: fieldImageUrl) {
            await loadFieldImage()
        }
    }
    
    // MARK: - Top Section (Image + Info + Price)
    
    private var topSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Field image
            fieldImageView

            // Center: venue + time + badge — takes all remaining width so the
            // text can show as much as possible before truncating.
            VStack(alignment: .leading, spacing: 6) {
                Text(venueName)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onSurface)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeRange)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                availabilityBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: price + type — keeps its natural width so it never steals
            // room from the info column.
            VStack(alignment: .trailing, spacing: 6) {
                Text(price)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)
                    .lineLimit(1)

                Text(matchType)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
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
        Group {
            if let cached = cachedFieldImage {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else if let image = fieldImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image("defaultField1x1", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadFieldImage() async {
        guard
            let urlString = fieldImageUrl,
            let url = URL(string: urlString)
        else {
            cachedFieldImage = nil
            return
        }

        // Return immediately if already in the shared cache
        if let cached = FMImageCache.shared.image(for: urlString) {
            cachedFieldImage = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return }
            guard let downloaded = UIImage(data: data) else { return }
            FMImageCache.shared.store(downloaded, for: urlString)
            cachedFieldImage = downloaded
        } catch {
            // Silently fail — default image stays visible
        }
    }
    
    private var availabilityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
            
            Text(spotsLabel)
                .font(FMTypography.labelSmall)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundColor(FMColors.onSurfaceVariant)
            
            Text(distance)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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

        // Long venue name + verbose time + no location fallback
        FMMatchCard(
            venueName: "Cancha Futbol 7 La Magdalena Contreras",
            timeRange: "08:24 p.m. - 11:15 p.m.",
            price: "$19.00 MXN",
            matchType: "Mixto",
            spotsLeft: 20,
            spotsLabel: "Quedan 20 lugares",
            teamA: FMMatchTeam(name: "Equipo A", avatarURLs: [], playerCount: 0),
            teamB: FMMatchTeam(name: "Equipo B", avatarURLs: [], playerCount: 0),
            distance: "Sin ubicación"
        )
    }
    .padding()
}
