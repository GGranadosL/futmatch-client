import SwiftUI
import FMDesignSystem

// MARK: - NotificationsView

struct NotificationsView: View {
    @EnvironmentObject private var viewModel: NotificationsViewModel
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text("Notificaciones")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task { await viewModel.load() }
        .onAppear { viewModel.markAsSeen() }
        .onChange(of: viewModel.pendingNavigation) { item in
            guard let item else { return }
            navigationPath.append(item)
            viewModel.clearNavigation()
        }
        .overlay {
            if viewModel.isNavigating {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(FMColors.primary)
                    .scaleEffect(1.4)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .loaded(let sections):
            notificationsList(sections)
        case .empty:
            emptyView
        case .failed(let message):
            errorView(message)
        }
    }

    // MARK: - Notifications List

    private func notificationsList(_ sections: [NotificationSection]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(sections) { section in
                    sectionHeader(section.title)
                    ForEach(section.notifications) { item in
                        NotificationRowView(item: item) {
                            Task { await viewModel.handleTap(item) }
                        } onDelete: {
                            Task { await viewModel.delete(id: item.id) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(FMTypography.labelMedium)
            .foregroundColor(FMColors.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(FMColors.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(FMColors.onSurfaceVariant)
            Text("Sin notificaciones")
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40))
                .foregroundColor(FMColors.error)
            Text(message)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Reintentar") {
                Task { await viewModel.load() }
            }
            .font(FMTypography.labelLarge)
            .foregroundColor(FMColors.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - NotificationRowView

private struct NotificationRowView: View {
    let item: NotificationItem
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                notificationIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(FMTypography.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(FMColors.onBackground)
                        .lineLimit(1)

                    Text(item.body)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(item.timeString)
                        .font(FMTypography.labelMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(FMColors.error)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMColors.outline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var notificationIcon: some View {
        Image(systemName: item.notificationType.iconName)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(FMColors.error)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(FMColors.errorContainer)
            )
    }
}
