import SwiftUI
import FMDesignSystem
import SharedModels

// MARK: - AdminUsersListView

/// "Usuarios": admins, organizers or players, one page at a time. The search only
/// filters the loaded page by name, and says so.
struct AdminUsersListView: View {
    @EnvironmentObject private var userSession: UserSession
    @StateObject private var viewModel: AdminUsersViewModel
    @State private var isSearchVisible = false
    @State private var isSearchFocused = false
    @State private var selectedUser: AdminUserSummary?
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    private let factory: AdminDependencyFactory
    private let topID = "admin-users-top"

    init(viewModel: @autoclosure @escaping () -> AdminUsersViewModel, factory: AdminDependencyFactory) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.factory = factory
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchVisible {
                FMTextField(
                    label: L10n.AdminUsers.searchPlaceholder,
                    text: $viewModel.searchQuery,
                    autocapitalization: .words
                )
                .focused($isSearchFocused)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            AdminRoleSegmentedControl(
                roles: AdminUserRole.selectable,
                selected: viewModel.selectedRole,
                onSelect: { role in Task { await viewModel.selectRole(role) } }
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)

            content

            FMPaginationBar(
                page: viewModel.pageNumber,
                totalPages: viewModel.totalPages,
                isLoading: viewModel.isLoading,
                onPrevious: { Task { await viewModel.previousPage() } },
                onNext: { Task { await viewModel.nextPage() } }
            )
        }
        .frame(maxHeight: .infinity)
        .background(FMColors.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                AdminNavTitle(title: L10n.AdminUsers.title)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                searchToggle
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onChange(of: viewModel.errorMessage) { message in
            // A failed refresh/page change keeps the current page on screen.
            guard let message, viewModel.page != nil else { return }
            errorToastMessage = message
            showErrorToast = true
        }
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
        .navigationDestination(isPresented: Binding(
            get: { selectedUser != nil },
            set: { if !$0 { selectedUser = nil } }
        )) {
            if let user = selectedUser {
                AdminUserProfileView(
                    viewModel: factory.makeAdminUserProfileViewModel(
                        userId: user.id,
                        currentUserId: userSession.currentUser?.id
                    ),
                    factory: factory,
                    onAccessChanged: { Task { await viewModel.refresh() } }
                )
                .modifier(AdminUsersHideTabBar())
            }
        }
    }

    // MARK: - Toolbar

    private var searchToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSearchVisible {
                    viewModel.clearSearch()
                    isSearchFocused = false
                    isSearchVisible = false
                } else {
                    isSearchVisible = true
                }
            }
            if isSearchVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isSearchFocused = true }
            }
        } label: {
            Image(systemName: isSearchVisible ? "xmark" : "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(FMColors.onSurface)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isSearchVisible ? L10n.AdminUsers.closeSearch : L10n.AdminUsers.openSearch)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            skeletonList
        case .failed(let message):
            VStack {
                FMEmptyStateCard(
                    icon: "exclamationmark.triangle",
                    message: message.isEmpty ? L10n.AdminUsers.loadError : message,
                    actionLabel: L10n.Common.retry,
                    onActionTap: { Task { await viewModel.refresh() } }
                )
                Spacer()
            }
            .padding(24)
            .frame(maxHeight: .infinity)
        case .empty:
            scrollingList {
                FMEmptyStateCard(icon: "person.2", message: L10n.AdminUsers.emptyRole)
            }
        case .noMatches:
            scrollingList {
                FMEmptyStateCard(
                    icon: "magnifyingglass",
                    message: "\(L10n.AdminUsers.noResults). \(L10n.AdminUsers.searchScope)",
                    actionLabel: L10n.AdminUsers.clearSearch,
                    onActionTap: { viewModel.clearSearch() }
                )
            }
        case .loaded(let users):
            scrollingList {
                LazyVStack(spacing: 12) {
                    ForEach(users) { user in
                        AdminUserRow(user: user) { selectedUser = user }
                    }
                }
            }
        }
    }

    private func scrollingList<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        let rows = rows()
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(countText)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .id(topID)
                    rows
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .refreshable { await Task { await viewModel.refresh() }.value }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.scrollResetToken) { _ in
                proxy.scrollTo(topID, anchor: .top)
            }
            .onChange(of: viewModel.searchQuery) { _ in
                proxy.scrollTo(topID, anchor: .top)
            }
        }
    }

    private var countText: String {
        if viewModel.isSearching, let page = viewModel.page {
            return L10n.AdminUsers.searchResults(viewModel.visibleUsers.count, page.items.count)
        }
        return L10n.AdminUsers.registeredCount(viewModel.totalUsers)
    }

    private var skeletonList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FMSkeleton(cornerRadius: 4).frame(width: 160, height: 14)
                ForEach(0..<5, id: \.self) { _ in AdminUserRowSkeleton() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .disabled(true)
    }
}

// MARK: - Role control

/// Outlined capsule with one segment per role, as in the admin users design.
struct AdminRoleSegmentedControl: View {
    let roles: [AdminUserRole]
    let selected: AdminUserRole
    let onSelect: (AdminUserRole) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(roles.enumerated()), id: \.element) { index, role in
                if index > 0 {
                    Rectangle().fill(FMColors.outline).frame(width: 1)
                }
                Button { onSelect(role) } label: {
                    Text(role.tabTitle)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(role == selected ? FMColors.onSecondaryContainer : FMColors.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(role == selected ? FMColors.secondaryContainer : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(role == selected ? .isSelected : [])
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(FMColors.outline, lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Row

struct AdminUserRow: View {
    let user: AdminUserSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AdminUsersCard {
                HStack(spacing: 16) {
                    AdminUserAvatar(user: user, size: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName)
                            .font(FMTypography.titleMedium)
                            .foregroundColor(FMColors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                        if let email = user.maskedEmail {
                            Text(email)
                                .font(FMTypography.bodyMedium)
                                .foregroundColor(FMColors.onSurfaceVariant)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        HStack(spacing: 6) {
                            FMStatusPill(user.status.displayName, tone: user.status.tone)
                            if user.isNew() {
                                FMStatusPill(L10n.AdminUsers.newBadge, tone: .info)
                            }
                        }
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
}

struct AdminUserRowSkeleton: View {
    var body: some View {
        AdminUsersCard {
            HStack(spacing: 16) {
                FMSkeleton(cornerRadius: 32).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 8) {
                    FMSkeleton(cornerRadius: 4).frame(width: 150, height: 16)
                    FMSkeleton(cornerRadius: 4).frame(width: 120, height: 12)
                    FMSkeleton(cornerRadius: 10).frame(width: 64, height: 22)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
