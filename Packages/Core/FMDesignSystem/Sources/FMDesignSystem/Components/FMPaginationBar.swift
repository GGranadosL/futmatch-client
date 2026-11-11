import SwiftUI

/// Sticky footer for paged lists: "‹  Página 2 de 4  ›".
public struct FMPaginationBar: View {
    private let page: Int
    private let totalPages: Int
    private let isLoading: Bool
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    public init(
        page: Int,
        totalPages: Int,
        isLoading: Bool = false,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.page = page
        self.totalPages = max(totalPages, 1)
        self.isLoading = isLoading
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    private var canGoBack: Bool { page > 1 && !isLoading }
    private var canGoForward: Bool { page < totalPages && !isLoading }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                arrow(systemName: "chevron.left", enabled: canGoBack,
                      label: FML10n.Pagination.previous, action: onPrevious)
                Spacer()
                Text(FML10n.Pagination.pageOf(page, totalPages))
                    .font(FMTypography.bodyLarge)
                    .foregroundColor(FMColors.onSurface)
                    .monospacedDigit()
                Spacer()
                arrow(systemName: "chevron.right", enabled: canGoForward,
                      label: FML10n.Pagination.next, action: onNext)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(FMColors.surfaceContainer.ignoresSafeArea(edges: .bottom))
    }

    private func arrow(systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundColor(enabled ? FMColors.onSurface : FMColors.onSurfaceVariant.opacity(0.4))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
