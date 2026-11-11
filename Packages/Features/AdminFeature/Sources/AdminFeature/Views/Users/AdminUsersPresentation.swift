import SwiftUI
import FMDesignSystem
import SharedModels

// MARK: - Labels and tones for the admin users screens

extension AdminUserRole {
    /// Plural label for the list tabs.
    var tabTitle: String {
        switch self {
        case .administrator: return L10n.AdminUsers.tabAdmins
        case .organizer: return L10n.AdminUsers.tabOrganizers
        case .player, .unknown: return L10n.AdminUsers.tabPlayers
        }
    }

    var displayName: String {
        switch self {
        case .administrator: return L10n.AdminUsers.roleAdmin
        case .organizer: return L10n.AdminUsers.roleOrganizer
        case .player: return L10n.AdminUsers.rolePlayer
        case .unknown: return L10n.AdminUsers.unknown
        }
    }
}

extension AdminUserStatus {
    var displayName: String {
        switch self {
        case .active: return L10n.AdminUsers.statusActive
        case .blocked: return L10n.AdminUsers.statusBlocked
        case .suspended: return L10n.AdminUsers.statusSuspended
        case .unknown: return L10n.AdminUsers.unknown
        }
    }

    var tone: FMStatusPill.Tone {
        switch self {
        case .active: return .success
        case .blocked: return .danger
        case .suspended: return .warning
        case .unknown: return .neutral
        }
    }
}

extension AdminPaymentStatus {
    var displayName: String {
        switch self {
        case .created: return L10n.AdminUsers.paymentCreated
        case .authorized: return L10n.AdminUsers.paymentAuthorized
        case .succeeded: return L10n.AdminUsers.paymentSucceeded
        case .failed: return L10n.AdminUsers.paymentFailed
        case .canceled: return L10n.AdminUsers.paymentCanceled
        case .refunded: return L10n.AdminUsers.paymentRefunded
        case .unknown: return L10n.AdminUsers.unknown
        }
    }

    var tone: FMStatusPill.Tone {
        switch self {
        case .succeeded: return .success
        case .failed, .canceled: return .danger
        case .refunded: return .warning
        case .authorized, .created: return .info
        case .unknown: return .neutral
        }
    }
}

extension AdminUserDevice.Platform {
    var displayName: String? {
        switch self {
        case .ios: return L10n.AdminUsers.platformIOS
        case .android: return L10n.AdminUsers.platformAndroid
        case .desktop: return L10n.AdminUsers.platformDesktop
        case .web: return L10n.AdminUsers.platformWeb
        case let .other(raw): return raw.capitalized
        case .unknown: return nil
        }
    }

    var iconName: String {
        switch self {
        case .ios, .android: return "iphone"
        case .desktop: return "desktopcomputer"
        case .web: return "globe"
        case .other, .unknown: return "questionmark.square.dashed"
        }
    }
}

extension AdminUserSummary {
    var displayName: String {
        fullName.isEmpty ? L10n.AdminUsers.unnamed : fullName
    }

    var defaultAvatarAssetName: String {
        Gender(rawValue: gender?.uppercased() ?? "")?.defaultAvatarAssetName ?? "defaultAvatar"
    }
}

// MARK: - Shared pieces

/// Avatar with the country flag pinned to its bottom-left, as on the list rows.
struct AdminUserAvatar: View {
    let user: AdminUserSummary
    var size: CGFloat = 64

    var body: some View {
        FMAvatar(url: user.profilePicURL, defaultImageName: user.defaultAvatarAssetName, size: size)
            .overlay(Circle().stroke(FMColors.outlineVariant, lineWidth: 1))
            .overlay(alignment: .bottomLeading) {
                if let flag = CountryFlag.emoji(for: user.countryCode) {
                    Text(flag)
                        .font(.system(size: size * 0.3))
                        .offset(x: size * 0.12, y: size * 0.04)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// Bordered rounded card used across the admin users screens.
struct AdminUsersCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(FMColors.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMColors.outlineVariant, lineWidth: 1))
    }
}

/// Hides the system tab bar on pushed admin screens.
struct AdminUsersHideTabBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}
