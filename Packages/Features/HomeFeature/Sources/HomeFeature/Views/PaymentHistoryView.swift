import SwiftUI
import FMDesignSystem

// MARK: - PaymentHistoryView

struct PaymentHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PaymentHistoryViewModel

    init(viewModel: PaymentHistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Text(L10n.PaymentHistory.title)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onBackground)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Circle().fill(.white))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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

    // MARK: - Payment Table

    private var paymentTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.PaymentHistory.sectionTitle)
                .font(FMTypography.titleSmall)
                .foregroundColor(FMColors.onBackground)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 0) {
                    tableHeader
                    Divider()
                    tableRows
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell(L10n.PaymentHistory.columnDate, width: 100)
            headerCell(L10n.PaymentHistory.columnAmount, width: 100)
            headerCell(L10n.PaymentHistory.columnStatus, width: 110)
            headerCell(L10n.PaymentHistory.columnTransactionId, width: 170)
            headerCell(L10n.PaymentHistory.columnCard, width: 90)
        }
        .padding(.vertical, 10)
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(FMTypography.labelSmall)
            .foregroundColor(FMColors.onSurfaceVariant)
            .frame(width: width, alignment: .leading)
    }

    private var tableRows: some View {
        ForEach(viewModel.payments) { payment in
            VStack(spacing: 0) {
                tableRow(payment)
                Divider()
            }
        }
    }

    private func tableRow(_ payment: PaymentHistoryItem) -> some View {
        HStack(spacing: 0) {
            // Fecha
            Text(payment.formattedShortDate)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurface)
                .frame(width: 100, alignment: .leading)

            // Monto
            Text(payment.formattedAmount)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurface)
                .frame(width: 100, alignment: .leading)

            // Estatus
            statusPill(payment)
                .frame(width: 110, alignment: .leading)

            // Id transacción
            Text(payment.id)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .lineLimit(1)
                .frame(width: 170, alignment: .leading)

            // Tarjeta
            Text(cardText(payment))
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurface)
                .frame(width: 90, alignment: .leading)
        }
        .padding(.vertical, 12)
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
