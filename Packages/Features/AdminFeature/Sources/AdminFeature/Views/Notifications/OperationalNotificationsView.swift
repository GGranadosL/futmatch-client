import SwiftUI
import FMDesignSystem

// MARK: - Hub

/// Notification hub of an operational inbox. Public so the home container can open it
/// straight from a push.
public struct OperationalNotificationsHubView: View {
    @StateObject private var viewModel: OperationalNotificationsViewModel
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var selectedMatch: AdminMatch?

    private let factory: AdminDependencyFactory

    public init(inbox: OperationalInbox, store: OperationalNotificationsStore) {
        let factory = AdminDependencyFactory(fieldListScope: inbox == .admin ? .all : .assigned)
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeOperationalNotificationsViewModel(inbox: inbox, store: store))
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FMColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AdminNavTitle(title: L10n.OperationalNotifications.title, subtitle: subtitle)
                }
            }
            .modifier(AdminUsersHideTabBar())
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isOpeningMatch {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView().tint(FMColors.primary).scaleEffect(1.4)
                    }
                }
            }
            .onChange(of: viewModel.toastError) { message in
                guard let message else { return }
                errorToastMessage = message
                showErrorToast = true
                viewModel.clearToast()
            }
            .onChange(of: viewModel.matchToOpen) { match in
                guard let match else { return }
                selectedMatch = match
                viewModel.didOpenMatch()
            }
            .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
            .navigationDestination(isPresented: Binding(
                get: { selectedMatch != nil },
                set: { if !$0 { selectedMatch = nil } }
            )) {
                if let match = selectedMatch {
                    AdminMatchDetailView(
                        viewModel: factory.makeAdminMatchDetailViewModel(match: match),
                        factory: factory,
                        subtitle: subtitle
                    )
                    .modifier(AdminUsersHideTabBar())
                }
            }
    }

    private var subtitle: String {
        viewModel.inbox == .admin ? "admin" : L10n.OrganizerHome.roleBadge
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FMSkeleton(cornerRadius: 4).frame(width: 60, height: 14).padding(.top, 16)
                    ForEach(0..<4, id: \.self) { _ in
                        FMSkeleton(cornerRadius: 12).frame(height: 110)
                    }
                }
                .padding(.horizontal, 16)
            }
            .disabled(true)
        case .failed(let message):
            VStack {
                FMEmptyStateCard(
                    icon: "exclamationmark.circle",
                    message: message.isEmpty ? L10n.OperationalNotifications.loadError : message,
                    actionLabel: L10n.Common.retry,
                    onActionTap: { Task { await viewModel.load() } }
                )
                Spacer()
            }
            .padding(24)
        case .empty:
            ScrollView {
                FMEmptyStateCard(icon: "bell.slash", message: L10n.OperationalNotifications.empty)
                    .padding(24)
            }
            .refreshable { await Task { await viewModel.load() }.value }
        case .loaded(let items):
            list(items)
        }
    }

    private func list(_ items: [OperationalNotification]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(OperationalNotificationSection.group(items)) { section in
                    Text(section.title)
                        .font(FMTypography.titleSmall)
                        .foregroundColor(FMColors.onSurface)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    ForEach(section.items) { item in
                        OperationalNotificationRow(
                            item: item,
                            isDeleting: viewModel.deletingIds.contains(item.id),
                            onTap: { Task { await viewModel.open(item) } },
                            onDelete: { Task { await viewModel.delete(id: item.id) } }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .refreshable { await Task { await viewModel.load() }.value }
    }
}

// MARK: - Sections

struct OperationalNotificationSection: Identifiable {
    let day: Date
    let title: String
    let items: [OperationalNotification]
    var id: Date { day }

    static func group(
        _ items: [OperationalNotification],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [OperationalNotificationSection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")

        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            let title: String
            if day == today {
                title = L10n.OperationalNotifications.today
            } else if day == yesterday {
                title = L10n.OperationalNotifications.yesterday
            } else {
                title = formatter.string(from: day).capitalized(with: locale)
            }
            let dayItems = (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            return OperationalNotificationSection(day: day, title: title, items: dayItems)
        }
    }
}

// MARK: - Row

private struct OperationalNotificationRow: View {
    let item: OperationalNotification
    let isDeleting: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: item.isPaymentWindowWarning ? "calendar.badge.checkmark" : "bell")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Self.iconColor)
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Self.iconBackground))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .font(FMTypography.titleMedium)
                                .foregroundColor(FMColors.onSurface)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text(Self.timeFormatter.string(from: item.createdAt))
                                .font(FMTypography.bodyMedium)
                                .foregroundColor(FMColors.onSurfaceVariant)
                        }
                        Text(item.body)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.matchId == nil)

            Button(action: onDelete) {
                ZStack {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 17))
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityLabel(L10n.OperationalNotifications.delete)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private static let iconColor = Color(red: 0.12, green: 0.45, blue: 0.22)
    private static let iconBackground = Color(red: 0.12, green: 0.45, blue: 0.22).opacity(0.14)
}

// MARK: - Bell

/// Bell with the unread badge of one operational inbox, for the admin/organizer headers.
public struct OperationalBellButton: View {
    @ObservedObject private var store: OperationalNotificationsStore
    private let inbox: OperationalInbox
    private let action: () -> Void

    public init(inbox: OperationalInbox, store: OperationalNotificationsStore, action: @escaping () -> Void) {
        self.inbox = inbox
        self.store = store
        self.action = action
    }

    public var body: some View {
        let count = store.count(for: inbox) ?? 0
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(FMColors.onSurface)
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.interBold(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(FMColors.error))
                            .offset(x: -4, y: 4)
                    }
                }
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.OperationalNotifications.open)
        .accessibilityValue(count > 0 ? L10n.OperationalNotifications.unreadCount(count) : "")
        .task { await store.refresh(inbox) }
    }
}
