import SwiftUI
import FMDesignSystem

// MARK: - AdminUserDevicesView

/// Devices come with the user detail (no separate endpoint); refresh re-reads the detail.
struct AdminUserDevicesView: View {
    let devices: [AdminUserDevice]
    let onRefresh: () async -> Void
    private let formatting = AdminUsersFormatting()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.AdminUsers.devicesCount(devices.count))
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)

                if devices.isEmpty {
                    FMEmptyStateCard(icon: "iphone.slash", message: L10n.AdminUsers.noDevices)
                } else {
                    ForEach(devices) { device in
                        deviceCard(device)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .refreshable { await Task { await onRefresh() }.value }
        .background(FMColors.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                AdminNavTitle(title: L10n.AdminUsers.devices)
            }
        }
    }

    private func deviceCard(_ device: AdminUserDevice) -> some View {
        AdminUsersCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: device.platform.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(FMColors.onPrimaryContainer)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(FMColors.primaryContainer))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(device.name ?? L10n.AdminUsers.unnamedDevice)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)

                    let details = detailsLine(device)
                    if !details.isEmpty {
                        Text(details)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        FMStatusPill(
                            device.isActive ? L10n.AdminUsers.deviceActive : L10n.AdminUsers.deviceInactive,
                            tone: device.isActive ? .success : .neutral
                        )
                        FMStatusPill(
                            device.isTrusted ? L10n.AdminUsers.deviceTrusted : L10n.AdminUsers.deviceUntrusted,
                            tone: device.isTrusted ? .info : .warning
                        )
                    }

                    if let lastUsed = device.lastUsedAt {
                        Text(L10n.AdminUsers.lastUsed(formatting.dateTime(lastUsed)))
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "iOS · SO: 26.2 · App: 0.1.0", skipping whatever is missing.
    private func detailsLine(_ device: AdminUserDevice) -> String {
        [
            device.platform.displayName,
            device.osVersion.map(L10n.AdminUsers.osVersion),
            device.appVersion.map(L10n.AdminUsers.appVersion)
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}
