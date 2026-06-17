import SwiftUI
import FMDesignSystem
import SharedModels
import NetworkFramework

/// Profile screen showing user info, stats, and performance
struct ProfileView: View {
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel
    var onLogout: (() -> Void)?
    @Binding var selectedTab: HomeTab

    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    @State private var profileImage: Image? = nil

    private var user: User? { userSession.currentUser }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if let loadError = userSession.error, user == nil {
                FMFullScreenError(
                    title: loadError.apiErrorTitle ?? L10n.ErrorOverlay.title,
                    message: loadError.apiErrorMessage ?? L10n.ErrorOverlay.fullScreenMessage,
                    retryTitle: L10n.Common.retry,
                    onRetry: {
                        Task {
                            await userSession.fetchProfile()
                            await homeViewModel.load()
                        }
                    }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        avatarSection
                        nameSection
                        statsSection
                        performanceSection
                        lastMatchSection
                    }
                    .padding(.bottom, 100) // Space for tab bar
                }
                .refreshable {
                    await Task {
                        await userSession.fetchProfile()
                        await homeViewModel.load()
                    }.value
                }
            }
        }
        .background(FMColors.background)
        .fmToast(
            userSession.refreshErrorMessage ?? L10n.ErrorOverlay.refreshMessage,
            isPresented: $userSession.refreshFailed,
            style: .error
        )
        .navigationBarHidden(true)
        .task(id: profilePicURL) {
            await loadProfileImage()
        }
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
        .alert(L10n.Profile.logoutTitle, isPresented: $showLogoutAlert) {
            Button(L10n.Profile.logoutConfirm, role: .destructive) {
                onLogout?()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Profile.logoutMessage)
        }
    }
    
    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Left-aligned logo (matches Home) — tapping it switches to the Home tab
            FMBrandLogo {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = .home
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.onSurface)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Button {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(FMColors.error)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
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
                    image: profileImage,
                    url: profilePicURL,
                    defaultImageName: user?.gender?.defaultAvatarAssetName ?? "defaultAvatar",
                    size: 100,
                    showCameraBadge: false
                )
                .id(homeViewModel.profileImageUrl ?? user?.profilePic)
                .overlay(
                    Circle()
                        .stroke(FMColors.outlineVariant, lineWidth: 2)
                )
                .overlay(alignment: .bottom) {
                    if let position = user?.playerPosition {
                        Text(position.displayName)
                            .font(FMTypography.labelMedium)
                            .foregroundColor(FMColors.onTertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(FMColors.tertiary))
                            .offset(y: 12)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
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
                
                Text(user?.countryDisplayName ?? "—")
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
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FMStatCard(icon: "trophy.fill",       value: user?.stats?.mvpCount ?? 0,      label: L10n.Profile.mvp)
                    FMStatCard(icon: "star.fill",         value: user?.stats?.matchesWon ?? 0,    label: L10n.Profile.won)
                    FMStatCard(icon: "sportscourt",       value: user?.stats?.matchesPlayed ?? 0, label: L10n.Profile.played)
                    FMStatCard(icon: "soccerball",        value: user?.stats?.totalGoals ?? 0,    label: L10n.Profile.totalGoals)
                }
                .padding(.horizontal, 24)
            }
        }
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

    // MARK: - Last Match Section

    @ViewBuilder
    private var lastMatchSection: some View {
        if homeViewModel.isLoading && homeViewModel.lastMatch == nil {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.LastMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                FMLastMatchSkeleton()
            }
            .padding(.horizontal, 24)
        } else if let last = homeViewModel.lastMatch {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.LastMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)

                HStack(spacing: 14) {
                    Image(systemName: outcomeIcon(last.outcome))
                        .font(.system(size: 24))
                        .foregroundColor(outcomeColor(last.outcome))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(outcomeColor(last.outcome).opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.outcomeLabel)
                            .font(FMTypography.titleSmall)
                            .foregroundColor(FMColors.onSurface)
                        Text("\(last.relativeDate) - \(last.fieldName)")
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    Text("\(last.teamAScore) - \(last.teamBScore)")
                        .font(FMTypography.headlineMedium)
                        .foregroundColor(FMColors.onSurface)
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
            .padding(.horizontal, 24)
        }
    }

    private func outcomeIcon(_ outcome: LastMatchOutcome) -> String {
        switch outcome {
        case .win: return "trophy.fill"
        case .loss: return "xmark.circle.fill"
        case .draw: return "equal.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: LastMatchOutcome) -> Color {
        switch outcome {
        case .win: return .green
        case .loss: return .red
        case .draw: return .orange
        }
    }

    private func loadProfileImage() async {
        guard let url = profilePicURL else {
            profileImage = nil
            return
        }

        do {
            var request = URLRequest(url: url)

            // Add auth token for Cloudinary authenticated URLs
            if url.absoluteString.contains("/authenticated/") {
                // Try to get token from userSession
                if let token = try? await userSession.getAuthToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            guard let downloaded = UIImage(data: data) else { return }
            profileImage = Image(uiImage: downloaded)
        } catch {
            // Silently fail, fall back to default avatar
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView(selectedTab: .constant(.profile))
}
