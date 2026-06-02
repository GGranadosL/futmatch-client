import SwiftUI
import FMDesignSystem

// MARK: - Player Status

enum PlayerStatus: String {
    case joined = "JOINED"
    case reserved = "RESERVED"
}

// MARK: - Match Data Models

struct MatchPlayer: Identifiable, Hashable {
    let id: String
    let playerId: String
    let name: String
    let avatarUrl: String?
    let avatarImage: Image?
    let status: PlayerStatus
    let country: String?

    init(
        id: String = UUID().uuidString,
        playerId: String = "",
        name: String,
        avatarUrl: String? = nil,
        avatarImage: Image? = nil,
        status: PlayerStatus = .joined,
        country: String? = nil
    ) {
        self.id = id
        self.playerId = playerId
        self.name = name
        self.avatarUrl = avatarUrl
        self.avatarImage = avatarImage
        self.status = status
        self.country = country
    }

    /// Flag emoji derived from ISO-2 country code (e.g. "MX" → "🇲🇽"). Nil when unknown.
    var countryFlag: String? {
        guard let iso = country?.uppercased(),
              iso.count == 2,
              iso.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 })
        else { return nil }
        return iso.unicodeScalars.map { String(Unicode.Scalar($0.value + 127397)!) }.joined()
    }

    static func == (lhs: MatchPlayer, rhs: MatchPlayer) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MatchItem: Identifiable, Hashable {
    let id: String
    let venueName: String
    let location: String
    let timeRange: String
    let date: String
    let startDate: Date
    let price: String
    let matchType: String
    let spotsLeft: Int
    let teamAPlayers: [MatchPlayer]
    let teamBPlayers: [MatchPlayer]
    let teamAMax: Int
    let teamBMax: Int
    let distance: String
    let duration: String
    let fieldImageUrl: String?
    let fieldImageName: String?
    let shoeType: String
    let fieldType: String
    let hasParking: Bool
    let extraInfo: String?
    let rules: [String]
    let matchStatus: String
    let teamAScore: Int?
    let teamBScore: Int?
    let winnerTeam: String?

    init(
        id: String = UUID().uuidString,
        venueName: String,
        location: String = "",
        timeRange: String,
        date: String = "",
        startDate: Date = Date(),
        price: String,
        matchType: String,
        spotsLeft: Int,
        teamAPlayers: [MatchPlayer] = [],
        teamBPlayers: [MatchPlayer] = [],
        teamAMax: Int = 5,
        teamBMax: Int = 5,
        distance: String = "",
        duration: String = "60 min",
        fieldImageUrl: String? = nil,
        fieldImageName: String? = nil,
        shoeType: String = "",
        fieldType: String = "",
        hasParking: Bool = false,
        extraInfo: String? = nil,
        rules: [String] = [],
        matchStatus: String = "UPCOMING",
        teamAScore: Int? = nil,
        teamBScore: Int? = nil,
        winnerTeam: String? = nil
    ) {
        self.id = id
        self.venueName = venueName
        self.location = location
        self.timeRange = timeRange
        self.date = date
        self.startDate = startDate
        self.price = price
        self.matchType = matchType
        self.spotsLeft = spotsLeft
        self.teamAPlayers = teamAPlayers
        self.teamBPlayers = teamBPlayers
        self.teamAMax = teamAMax
        self.teamBMax = teamBMax
        self.distance = distance
        self.duration = duration
        self.fieldImageUrl = fieldImageUrl
        self.fieldImageName = fieldImageName
        self.shoeType = shoeType
        self.fieldType = fieldType
        self.hasParking = hasParking
        self.extraInfo = extraInfo
        self.rules = rules
        self.matchStatus = matchStatus
        self.teamAScore = teamAScore
        self.teamBScore = teamBScore
        self.winnerTeam = winnerTeam
    }

    static func == (lhs: MatchItem, rhs: MatchItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MatchSection: Identifiable {
    let id = UUID()
    let title: String
    let matches: [MatchItem]
}

// MARK: - Matches List View

/// Matches tab showing upcoming games grouped by date sections
struct MatchesListView: View {
    @EnvironmentObject private var matchesViewModel: MatchesViewModel
    
    /// Navigation path binding shared from container (custom tab) or local (native tab).
    @Binding var navigationPath: NavigationPath
    
    init(navigationPath: Binding<NavigationPath>? = nil) {
        self._navigationPath = navigationPath ?? .constant(NavigationPath())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.Matches.upcoming)
                .font(FMTypography.headlineMedium)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            matchesContent
        }
        .background(FMColors.background)
        .fmToast(
            matchesViewModel.refreshErrorMessage ?? L10n.ErrorOverlay.refreshMessage,
            isPresented: $matchesViewModel.refreshFailed,
            style: .error
        )
        .task { await matchesViewModel.loadMatches() }
    }

    // MARK: - Content by State

    @ViewBuilder
    private var matchesContent: some View {
        switch matchesViewModel.state {
        case .idle, .loading:
            skeletonView
        case .loaded(let sections):
            if sections.isEmpty {
                matchesEmptyState
            } else {
                sectionsList(sections)
            }
        case .failed(let message):
            errorView(message: message)
        }
    }
    
    private var matchesEmptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 80)
                Image("emptyStateMatches", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(L10n.Matches.noMatchesAvailable)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .bold()
                    .multilineTextAlignment(.center)
                Text(L10n.Matches.noMatchesSubtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable { await matchesViewModel.reload() }
    }
    
    private var skeletonView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Section header placeholder
                FMSkeleton(cornerRadius: 4)
                    .frame(width: 100, height: 22)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                // Card placeholders
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        FMMatchCardSkeleton()
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 100)
        }
        .disabled(true)
    }
    
    private func errorView(message: String) -> some View {
        FMFullScreenError(
            title: matchesViewModel.loadErrorTitle ?? L10n.ErrorOverlay.title,
            message: matchesViewModel.loadErrorMessage ?? L10n.ErrorOverlay.fullScreenMessage,
            retryTitle: L10n.Common.retry,
            onRetry: { Task { await matchesViewModel.reload() } }
        )
    }

    private func sectionsList(_ sections: [MatchSection]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(section.matches) { match in
                                matchCard(for: match)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    } header: {
                        sectionHeader(section.title, showDivider: index > 0)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .refreshable { await matchesViewModel.reload() }
    }

    // MARK: - Section Header
    
    private func sectionHeader(_ title: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
            
            Text(title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 4)
        }
    }
    
    // MARK: - Match Card
    
    private func matchCard(for match: MatchItem) -> some View {
        FMMatchCard(
            venueName: match.venueName,
            timeRange: match.timeRange,
            price: match.price,
            matchType: match.matchType,
            spotsLeft: match.spotsLeft,
            spotsLabel: L10n.Matches.spotsLeft(match.spotsLeft),
            teamA: FMMatchTeam(
                name: L10n.Matches.teamA,
                avatarURLs: match.teamAPlayers.prefix(3).map { $0.avatarUrl },
                playerCount: match.teamAPlayers.count
            ),
            teamB: FMMatchTeam(
                name: L10n.Matches.teamB,
                avatarURLs: match.teamBPlayers.prefix(3).map { $0.avatarUrl },
                playerCount: match.teamBPlayers.count
            ),
            distance: match.distance,
            fieldImageUrl: match.fieldImageUrl,
            onTap: {
                navigationPath.append(match)
            }
        )
    }
    
}
