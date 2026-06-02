import SwiftUI
import UIKit
import FMDesignSystem

// MARK: - PaymentHistoryView

struct PaymentHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PaymentHistoryViewModel
    @State private var showCopiedToast = false

    init(viewModel: PaymentHistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.PaymentHistory.title)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task {
            await viewModel.load()
        }
        .fmToast(L10n.Common.copied, isPresented: $showCopiedToast, style: .success, duration: 1.5)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(FMColors.primary)
            Spacer()
        } else if let error = viewModel.error {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(FMColors.error)
                Text(error)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Text(L10n.Common.retry)
                        .font(FMTypography.labelMedium)
                        .foregroundColor(FMColors.primary)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        } else if viewModel.payments.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(L10n.PaymentHistory.empty)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            Spacer()
        } else {
            paymentTable
        }
    }

    // MARK: - Payment List

    private var paymentTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.PaymentHistory.sectionTitle)
                .font(FMTypography.titleSmall)
                .foregroundColor(FMColors.onBackground)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.payments) { payment in
                        paymentCard(payment)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
        }
    }

    private func paymentCard(_ payment: PaymentHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Amount + status
            HStack(alignment: .firstTextBaseline) {
                Text(payment.formattedAmount)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
                Spacer()
                statusPill(payment)
            }

            Divider()

            // Date + card
            HStack {
                Label {
                    Text(payment.formattedShortDate)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(FMColors.onSurfaceVariant)
                }

                Spacer()

                if payment.paymentMethod != nil {
                    Label {
                        Text(cardText(payment))
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                    } icon: {
                        Image(systemName: payment.brandIcon)
                            .font(.system(size: 13))
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                }
            }

            // Transaction id (truncated, tap to copy)
            HStack(spacing: 6) {
                Text(payment.id)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIPasteboard.general.string = payment.id
                showCopiedToast = true
            }
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

    // MARK: - Status Pill

    private func statusPill(_ payment: PaymentHistoryItem) -> some View {
        let (text, fg, bg) = statusStyle(payment)
        return Text(text)
            .font(FMTypography.labelSmall)
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(bg)
            )
    }

    private func statusStyle(_ payment: PaymentHistoryItem) -> (String, Color, Color) {
        if payment.isRefunded {
            return (L10n.PaymentHistory.statusRefunded, .orange, .orange.opacity(0.15))
        }
        switch payment.status {
        case "succeeded":
            return (L10n.PaymentHistory.statusSuccess, .green, .green.opacity(0.15))
        case "canceled":
            return (L10n.PaymentHistory.statusCanceled, FMColors.onSurfaceVariant, FMColors.onSurfaceVariant.opacity(0.15))
        default:
            return (L10n.PaymentHistory.statusFailed, FMColors.error, FMColors.error.opacity(0.15))
        }
    }

    // MARK: - Helpers

    private func cardText(_ payment: PaymentHistoryItem) -> String {
        guard let method = payment.paymentMethod else { return "—" }
        return "\(method.brand.capitalized) \(method.last4)"
    }
}
