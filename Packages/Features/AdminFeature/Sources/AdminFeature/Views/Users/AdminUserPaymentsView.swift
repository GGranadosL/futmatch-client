import SwiftUI
import FMDesignSystem

// MARK: - AdminUserPaymentsView

struct AdminUserPaymentsView: View {
    @StateObject private var viewModel: AdminUserPaymentsViewModel
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    private let formatting = AdminUsersFormatting()
    private let topID = "admin-payments-top"

    init(viewModel: @autoclosure @escaping () -> AdminUserPaymentsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
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
                AdminNavTitle(title: L10n.AdminUsers.payments)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onChange(of: viewModel.errorMessage) { message in
            guard let message, viewModel.page != nil else { return }
            errorToastMessage = message
            showErrorToast = true
        }
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FMSkeleton(cornerRadius: 4).frame(width: 120, height: 14)
                    ForEach(0..<3, id: \.self) { _ in AdminPaymentCardSkeleton() }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .disabled(true)
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
            list { FMEmptyStateCard(icon: "creditcard", message: L10n.AdminUsers.noPayments) }
        case .loaded(let payments):
            list {
                ForEach(payments) { paymentCard($0) }
            }
        }
    }

    private func list<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        let rows = rows()
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.AdminUsers.paymentsCount(viewModel.total))
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .id(topID)
                    rows
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .refreshable { await Task { await viewModel.refresh() }.value }
            .onChange(of: viewModel.scrollResetToken) { _ in
                proxy.scrollTo(topID, anchor: .top)
            }
        }
    }

    // MARK: - Card

    private func paymentCard(_ payment: AdminUserPayment) -> some View {
        AdminUsersCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(formatting.money(amountInCents: payment.amountInCents, currency: payment.currency))
                        .font(FMTypography.titleLarge)
                        .foregroundColor(FMColors.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    FMStatusPill(payment.status.displayName, tone: payment.status.tone)
                    Spacer(minLength: 0)
                }

                Divider()

                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 20))
                        .foregroundColor(FMColors.onPrimaryContainer)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.primaryContainer))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.fieldName ?? L10n.AdminUsers.paymentUnknownField)
                            .font(FMTypography.titleMedium)
                            .foregroundColor(FMColors.onSurface)
                        // Two different moments: when the match starts and when it was paid.
                        if let startsAt = payment.matchStartsAt {
                            dateLine(L10n.AdminUsers.paymentMatchDate(formatting.dateTime(startsAt)))
                        }
                        if let paidAt = payment.paidAt {
                            dateLine(L10n.AdminUsers.paymentPaidDate(formatting.dateTime(paidAt)))
                        }
                        if let refundedAt = payment.refundedAt {
                            dateLine(L10n.AdminUsers.paymentRefundedDate(formatting.dateTime(refundedAt)))
                        }
                    }
                }

                methodRow(payment.card)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dateLine(_ text: String) -> some View {
        Text(text)
            .font(FMTypography.bodyMedium)
            .foregroundColor(FMColors.onSurfaceVariant)
    }

    private func methodRow(_ card: AdminUserPayment.Card?) -> some View {
        HStack(spacing: 16) {
            FMCardBrandMark(brand: card?.brand)
            Text(methodText(card))
                .font(FMTypography.bodyLarge)
                .foregroundColor(FMColors.onSurfaceVariant)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerHigh))
    }

    /// Only what the backend sent: brand and last four, never a made-up number.
    private func methodText(_ card: AdminUserPayment.Card?) -> String {
        guard let card else { return L10n.AdminUsers.paymentMethodUnavailable }
        switch (card.brand, card.last4) {
        case let (brand?, last4?): return L10n.AdminUsers.cardDescription(brand, last4)
        case let (nil, last4?): return "•••• \(last4)"
        case let (brand?, nil): return brand
        case (nil, nil): return L10n.AdminUsers.paymentMethodUnavailable
        }
    }
}

struct AdminPaymentCardSkeleton: View {
    var body: some View {
        AdminUsersCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    FMSkeleton(cornerRadius: 4).frame(width: 130, height: 24)
                    FMSkeleton(cornerRadius: 10).frame(width: 70, height: 22)
                }
                FMSkeleton(cornerRadius: 1).frame(height: 1)
                HStack(spacing: 16) {
                    FMSkeleton(cornerRadius: 12).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        FMSkeleton(cornerRadius: 4).frame(width: 110, height: 16)
                        FMSkeleton(cornerRadius: 4).frame(width: 170, height: 12)
                        FMSkeleton(cornerRadius: 4).frame(width: 150, height: 12)
                    }
                }
                FMSkeleton(cornerRadius: 12).frame(height: 64)
            }
        }
    }
}
