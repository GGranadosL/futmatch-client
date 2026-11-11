import SwiftUI
import FMDesignSystem

// MARK: - AdminUserProfileView

/// Admin view of one user. Uses the same collapsing header as the player profiles
/// (avatar and name move into the bar), so the bar and its back button are drawn
/// by the scaffold, like `PlayerProfileView`.
struct AdminUserProfileView: View {
    @StateObject private var viewModel: AdminUserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAccessSheet = false
    @State private var showDevices = false
    @State private var showPayments = false
    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    private let factory: AdminDependencyFactory
    private let onAccessChanged: () -> Void
    private let formatting = AdminUsersFormatting()

    init(
        viewModel: @autoclosure @escaping () -> AdminUserProfileViewModel,
        factory: AdminDependencyFactory,
        onAccessChanged: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.factory = factory
        self.onAccessChanged = onAccessChanged
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: 0) {
                    plainBar
                    loadingSkeleton
                }
            case .failed(let message):
                VStack(spacing: 0) {
                    plainBar
                    FMEmptyStateCard(
                        icon: "exclamationmark.triangle",
                        message: message.isEmpty ? L10n.AdminUsers.loadError : message,
                        actionLabel: L10n.Common.retry,
                        onActionTap: { Task { await viewModel.load() } }
                    )
                    .padding(24)
                    Spacer()
                }
            case .loaded(let detail):
                loadedBody(detail)
            }
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            if viewModel.detail == nil { await viewModel.load() }
        }
        .onChange(of: viewModel.refreshError) { message in
            guard let message else { return }
            errorToastMessage = message
            showErrorToast = true
        }
        .onChange(of: viewModel.accessSaved) { saved in
            guard saved else { return }
            showAccessSheet = false
            showSuccessToast = true
            viewModel.acknowledgeAccessSaved()
            onAccessChanged()
        }
        .sheet(isPresented: $showAccessSheet) {
            AdminUserAccessSheet(viewModel: viewModel)
        }
        .fmToast(L10n.AdminUsers.accessSaved, isPresented: $showSuccessToast, style: .success)
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
        .navigationDestination(isPresented: $showDevices) {
            AdminUserDevicesView(devices: viewModel.detail?.devices ?? [], onRefresh: { await viewModel.load() })
                .modifier(AdminUsersHideTabBar())
        }
        .navigationDestination(isPresented: $showPayments) {
            AdminUserPaymentsView(viewModel: factory.makeAdminUserPaymentsViewModel(userId: viewModel.userId))
                .modifier(AdminUsersHideTabBar())
        }
    }

    // MARK: - Loaded

    private func loadedBody(_ detail: AdminUserDetail) -> some View {
        let user = detail.summary
        return ProfileScaffold(
            identity: ProfileIdentity(
                name: user.displayName,
                avatarURL: user.profilePicURL,
                defaultAvatarAssetName: user.defaultAvatarAssetName
            ),
            barTitle: L10n.AdminUsers.profileTitle,
            leadingInset: 48,
            showsBackdrop: false,
            onRefresh: { await viewModel.load() },
            leading: { _ in AdminProfileBackButton(action: { dismiss() }) },
            trailing: { _ in EmptyView() },
            meta: { meta(user) },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    accessButton
                    activityCard(detail)
                    accountCard(detail)
                    securityCard(detail)
                    navigationRow(
                        icon: "laptopcomputer.and.iphone",
                        title: L10n.AdminUsers.devices,
                        subtitle: L10n.AdminUsers.devicesCount(detail.devices.count),
                        action: { showDevices = true }
                    )
                    navigationRow(
                        icon: "creditcard",
                        title: L10n.AdminUsers.payments,
                        subtitle: L10n.AdminUsers.paymentsSubtitle,
                        action: { showPayments = true }
                    )
                }
                .padding(.horizontal, 24)
            }
        )
    }

    private func meta(_ user: AdminUserSummary) -> some View {
        HStack(spacing: 10) {
            if let flag = CountryFlag.emoji(for: user.countryCode) {
                Text(flag).accessibilityHidden(true)
            }
            Text(user.role.displayName)
                .font(FMTypography.bodyLarge)
                .foregroundColor(FMColors.onSurfaceVariant)
            FMStatusPill(user.status.displayName, tone: user.status.tone)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var accessButton: some View {
        if viewModel.canManageAccess {
            Button {
                viewModel.beginEditingAccess()
                showAccessSheet = true
            } label: {
                Text(L10n.AdminUsers.manageAccess)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(FMColors.primary))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Text(L10n.AdminUsers.selfAccessNote)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Cards

    private func activityCard(_ detail: AdminUserDetail) -> some View {
        section(L10n.AdminUsers.activity) {
            row(L10n.AdminUsers.upcomingMatches, count(detail.upcomingMatchesCount))
            row(L10n.AdminUsers.completedMatches, count(detail.completedMatchesCount))
            row(L10n.AdminUsers.activeSessions, count(detail.activeSessionCount))
        }
    }

    private func accountCard(_ detail: AdminUserDetail) -> some View {
        let user = detail.summary
        return section(L10n.AdminUsers.account) {
            row(L10n.AdminUsers.email, user.maskedEmail ?? L10n.AdminUsers.unavailable)
            row(L10n.AdminUsers.phone, detail.maskedPhone ?? L10n.AdminUsers.unavailable)
            row(L10n.AdminUsers.emailVerified, user.isEmailVerified ? L10n.AdminUsers.yes : L10n.AdminUsers.no)
            row(L10n.AdminUsers.memberSince, user.createdAt.map(formatting.date) ?? L10n.AdminUsers.unavailable)
        }
    }

    private func securityCard(_ detail: AdminUserDetail) -> some View {
        section(L10n.AdminUsers.security) {
            row(L10n.AdminUsers.failedAttempts, count(detail.failedLoginAttempts))
            if let lockedUntil = detail.lockedUntil, lockedUntil > Date() {
                row(L10n.AdminUsers.lockedUntil, formatting.dateTime(lockedUntil))
            }
        }
    }

    /// A missing value reads "No disponible", never 0.
    private func count(_ value: Int?) -> String {
        value.map(String.init) ?? L10n.AdminUsers.unavailable
    }

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        AdminUsersCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.primary)
                rows()
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundColor(FMColors.onSurface)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(value)
                    .foregroundColor(FMColors.onSurface)
            }
        }
        .font(FMTypography.bodyLarge)
        .accessibilityElement(children: .combine)
    }

    private func navigationRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AdminUsersCard {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(FMColors.primary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(FMTypography.titleMedium)
                            .foregroundColor(FMColors.onSurface)
                        Text(subtitle)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading / error chrome

    private var plainBar: some View {
        ZStack {
            Text(L10n.AdminUsers.profileTitle)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onBackground)
            HStack {
                AdminProfileBackButton(action: { dismiss() })
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                FMSkeleton(cornerRadius: 66).frame(width: 132, height: 132)
                FMSkeleton(cornerRadius: 6).frame(width: 180, height: 26)
                FMSkeleton(cornerRadius: 12).frame(width: 160, height: 24)
                FMSkeleton(cornerRadius: 25).frame(height: 50)
                ForEach(0..<3, id: \.self) { _ in
                    FMSkeleton(cornerRadius: 16).frame(height: 140)
                }
            }
            .padding(24)
        }
        .disabled(true)
    }
}

// MARK: - Access sheet

/// Role + status picker. The confirm button carries its own loader and the sheet
/// shows its own error toast (a toast on the presenter would be hidden by the sheet).
struct AdminUserAccessSheet: View {
    @ObservedObject var viewModel: AdminUserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L10n.AdminUsers.manageAccessDescription)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    optionGroup(L10n.AdminUsers.roleLabel, options: AdminUserRole.selectable,
                                selection: $viewModel.draftRole, label: \.displayName)

                    optionGroup(L10n.AdminUsers.statusLabel, options: AdminUserStatus.selectable,
                                selection: $viewModel.draftStatus, label: \.displayName)

                    Label(L10n.AdminUsers.sessionsWarning, systemImage: "exclamationmark.triangle")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                FMStickyActionBar(
                    title: L10n.AdminUsers.saveChanges,
                    isLoading: viewModel.isSavingAccess,
                    isEnabled: viewModel.canSaveAccess,
                    action: { showConfirm = true }
                )
            }
            .background(FMColors.background.ignoresSafeArea())
            .navigationTitle(L10n.AdminUsers.manageAccess)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .disabled(viewModel.isSavingAccess)
                }
            }
            .alert(L10n.AdminUsers.confirmAccessTitle, isPresented: $showConfirm) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.AdminUsers.saveChanges) {
                    Task { await viewModel.saveAccess() }
                }
            } message: {
                Text(L10n.AdminUsers.confirmAccessMessage)
            }
        }
        .interactiveDismissDisabled(viewModel.isSavingAccess)
        .presentationDetents([.large])
        .onChange(of: viewModel.accessError) { message in
            guard let message else { return }
            errorToastMessage = message
            showErrorToast = true
            viewModel.clearAccessError()
        }
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
    }

    private func optionGroup<Option: Hashable>(
        _ title: String,
        options: [Option],
        selection: Binding<Option>,
        label: KeyPath<Option, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FMTypography.titleSmall)
                .foregroundColor(FMColors.onSurface)
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    if index > 0 { Divider() }
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack {
                            Text(option[keyPath: label])
                                .font(FMTypography.bodyLarge)
                                .foregroundColor(FMColors.onSurface)
                            Spacer()
                            if selection.wrappedValue == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(FMColors.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSavingAccess)
                    .accessibilityAddTraits(selection.wrappedValue == option ? .isSelected : [])
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        }
    }
}

// MARK: - Back button

/// The collapsing header hides the navigation bar, so the system back button isn't there.
/// On iOS 26 this draws the same glass circle the system button has (with its rim), so the
/// profile's back matches the rest of the admin screens; earlier versions use `FMBackButton`.
private struct AdminProfileBackButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            FMBackButton(action: action, isInToolbar: true)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            FMBackButton(action: action)
        }
    }
}
