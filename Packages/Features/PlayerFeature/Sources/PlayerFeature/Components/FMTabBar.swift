import SwiftUI
import FMDesignSystem

/// Tab item model
public enum HomeTab: Int, CaseIterable {
    case home = 0
    case matches = 1
    case reserved = 2
    case profile = 3
    
    var title: String {
        switch self {
        case .home: return L10n.Tab.home
        case .matches: return L10n.Tab.matches
        case .reserved: return L10n.Tab.reserved
        case .profile: return L10n.Tab.profile
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .matches: return "soccerBall"
        case .reserved: return "calendar"
        case .profile: return "person"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .matches: return "soccerBall"
        case .reserved: return "calendar"
        case .profile: return "person.fill"
        }
    }
    
    /// Whether the icon is a custom asset (not an SF Symbol)
    var isAssetIcon: Bool {
        switch self {
        case .matches: return true
        default: return false
        }
    }
    
    /// Whether the tab shows a user avatar instead of an icon
    var isAvatarIcon: Bool {
        switch self {
        case .profile: return true
        default: return false
        }
    }
}

/// Liquid Glass Tab Bar
public struct FMTabBar: View {
    @Binding var selectedTab: HomeTab
    let profileImageUrl: String?
    let profileDefaultImageName: String?

    public init(
        selectedTab: Binding<HomeTab>,
        profileImageUrl: String? = nil,
        profileDefaultImageName: String? = "defaultAvatar"
    ) {
        self._selectedTab = selectedTab
        self.profileImageUrl = profileImageUrl
        // Fallback to "defaultAvatar" if gender is unknown (currentUser not loaded yet)
        self.profileDefaultImageName = profileDefaultImageName ?? "defaultAvatar"
    }

    public var body: some View {
        let tabContent = HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.rawValue) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    profileImageUrl: profileImageUrl,
                    profileDefaultImageName: profileDefaultImageName
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)

        Group {
            if #available(iOS 26.0, *) {
                tabContent
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .hoverEffect(.highlight)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            } else {
                tabContent
                    .background(fallbackGlassBackground)
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 20,
                        x: 0,
                        y: 8
                    )
                    .shadow(
                        color: Color.black.opacity(0.04),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Fallback Glass (iOS < 26)
    
    private var fallbackGlassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                .blur(radius: 1)
                .offset(y: 1)
        }
    }
}

// MARK: - Tab Bar Item
private struct TabBarItem: View {
    let tab: HomeTab
    let isSelected: Bool
    let profileImageUrl: String?
    let profileDefaultImageName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Background bubble for selected state
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FMColors.primary.opacity(0.15),
                                        FMColors.primary.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 48, height: 32)
                            .overlay(
                                Capsule()
                                    .stroke(FMColors.primary.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(
                                color: FMColors.primary.opacity(0.15),
                                radius: 8,
                                x: 0,
                                y: 2
                            )
                    }
                    
                    // Icon
                    Group {
                        if tab.isAvatarIcon {
                            avatarIcon
                        } else if tab.isAssetIcon {
                            Image(isSelected ? tab.selectedIcon : tab.icon, bundle: .main)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundColor(isSelected ? FMColors.primary : FMColors.secondary)
                        } else {
                            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isSelected ? FMColors.primary : FMColors.secondary)
                        }
                    }
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 32)
                
                // Label
                Text(tab.title)
                    .font(FMTypography.caption)
                    .foregroundColor(isSelected ? FMColors.primary : FMColors.secondary)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Avatar Icon

    @ViewBuilder
    private var avatarIcon: some View {
        let url: URL? = {
            guard let str = profileImageUrl, !str.isEmpty else { return nil }
            return URL(string: str)
        }()
        FMAvatar(
            url: url,
            defaultImageName: profileDefaultImageName,
            size: 24
        )
        .id(profileImageUrl)
        .overlay(
            Circle()
                .stroke(isSelected ? FMColors.primary : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            FMTabBar(selectedTab: .constant(.home))
        }
    }
}
