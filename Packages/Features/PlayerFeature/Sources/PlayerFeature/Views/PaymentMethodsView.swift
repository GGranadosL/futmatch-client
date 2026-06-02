import SwiftUI
import FMDesignSystem
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

// MARK: - PaymentMethodsView

struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PaymentMethodsViewModel
    @State private var presentSheet = false

    init(viewModel: PaymentMethodsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(FMColors.background)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.Settings.paymentMethods)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task {
            debugLog("View task started")
            await viewModel.loadCustomerSheet()
        }
        .onChange(of: viewModel.customerSheet != nil) { ready in
            debugLog("customerSheet ready changed ready=\(ready)")
            if ready {
                presentSheet = true
                debugLog("Setting presentSheet=true")
            }
        }
        .background(
            CustomerSheetPresenter(
                customerSheet: viewModel.customerSheet,
                isPresented: $presentSheet
            ) { result in
                viewModel.handleCustomerSheetResult(result)

                switch result {
                case .selected, .canceled:
                    dismiss()
                case .error:
                    break
                }
            }
        )
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
                    Task { await viewModel.loadCustomerSheet() }
                } label: {
                    Text(L10n.Common.retry)
                        .font(FMTypography.labelMedium)
                        .foregroundColor(FMColors.primary)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        } else {
            Spacer()
        }
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[FMDEBUG][Stripe][PaymentMethodsView] \(message)")
#endif
    }
}

// MARK: - CustomerSheet UIKit Bridge

private struct CustomerSheetPresenter: UIViewControllerRepresentable {
    let customerSheet: CustomerSheet?
    @Binding var isPresented: Bool
    let onResult: (CustomerSheet.CustomerSheetResult) -> Void

    // Coordinator holds presentation state so re-renders never trigger a second present()
    final class Coordinator {
        var isPresenting = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Guard: only present once — coordinator flag prevents re-entry during re-renders
        guard isPresented, let sheet = customerSheet, !context.coordinator.isPresenting else { return }
        context.coordinator.isPresenting = true
        isPresented = false

        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
                context.coordinator.isPresenting = false
                return
            }

            // Present from the root — never walk into Stripe's own VCs
            guard rootVC.presentedViewController == nil else {
                context.coordinator.isPresenting = false
                return
            }

            sheet.present(from: rootVC) { result in
                context.coordinator.isPresenting = false
                self.onResult(result)
            }
        }
    }
}
