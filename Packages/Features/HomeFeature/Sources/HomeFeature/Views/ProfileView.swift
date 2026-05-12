import SwiftUI
import FMDesignSystem
import SharedModels

/// Profile screen showing user info, stats, and performance
struct ProfileView: View {
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel
    var onLogout: (() -> Void)?
    
    @State private var showSettings = false
    @State private var showEditProfile = false
    
    // TODO: Replace with real stats from backend when available
    private let matchesPlayed = 0
    private let matchesWon = 0
    private let mvpCount = 0
    private let totalGoals = 0
    
    private var user: User? { userSession.currentUser }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    avatarSection
                    nameSection
                    statsSection
                    performanceSection
                }
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .background(FMColors.background)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(
                onLogout: onLogout,
                paymentMethodsViewModel: PaymentMethodsViewModel(paymentService: PaymentService()),
                paymentHistoryViewModelFactory: {
                    PaymentHistoryViewModel(paymentService: PaymentService())
                }
            )
        }
        .navigationDestination(isPresented: $showEditProfile) {
            EditProfileView()
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            // Position badge
            Text(user?.playerPosition.displayName ?? "—")
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(FMColors.tertiary)
                )
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.onSurface)
                }
                
                Button {
                    onLogout?()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.onSurface)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Avatar Section
    
    private var profilePicURL: URL? {
        if let urlStr = homeViewModel.profileImageUrl, let url = URL(string: urlStr) {
            return url
        }
        return user?.profilePicURL
    }

    private var avatarSection: some View {
        HStack {
            Button {
                showEditProfile = true
            } label: {
                FMAvatar(
                    url: profilePicURL,
                    defaultImageName: user?.gender.defaultAvatarAssetName,
                    size: 100,
                    showCameraBadge: false
                )
                .id(homeViewModel.profileImageUrl ?? user?.profilePic)
                .overlay(
                    Circle()
                        .stroke(FMColors.outlineVariant, lineWidth: 2)
                )
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    // MARK: - Name + Edit Section
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(user?.fullName ?? "—")
                    .font(FMTypography.headlineSmall)
                    .foregroundColor(FMColors.onBackground)
                
                Spacer()
                
                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(L10n.Profile.editProfile)
                            .font(FMTypography.labelLarge)
                    }
                    .foregroundColor(FMColors.onTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(FMColors.tertiary)
                    )
                }
            }
            
            HStack(spacing: 4) {
                Text(user?.countryFlag ?? "🏳️")
                    .font(.system(size: 14))
                
                Text(user?.country ?? "—")
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.statistics)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FMStatCard(icon: "trophy.fill",       value: mvpCount,      label: L10n.Profile.mvp)
                    FMStatCard(icon: "star.fill",         value: matchesWon,    label: L10n.Profile.won)
                    FMStatCard(icon: "sportscourt",       value: matchesPlayed, label: L10n.Profile.played)
                    FMStatCard(icon: "soccerball",        value: totalGoals,    label: L10n.Profile.totalGoals)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.performance)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Profile.playerLevel)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                    
                    Text(user?.level.displayName ?? "—")
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(FMColors.tertiary)
                        )
                }
                
                Spacer()
                
                FMOVRRing(score: homeViewModel.averageScore)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
}
