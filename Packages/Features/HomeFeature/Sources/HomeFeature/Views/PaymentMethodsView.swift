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
            headerBar
            content
        }
        .background(FMColors.background)
        .navigationBarHidden(true)
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

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Text(L10n.Settings.paymentMethods)
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

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let sheet = customerSheet else { return }

#if DEBUG
        print("[FMDEBUG][Stripe][PaymentMethodsPresenter] Attempting presentation isPresented=\(isPresented)")
#endif

        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
#if DEBUG
                print("[FMDEBUG][Stripe][PaymentMethodsPresenter] No active root view controller found")
#endif
                return
            }

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            guard topVC.presentedViewController == nil else {
#if DEBUG
                print("[FMDEBUG][Stripe][PaymentMethodsPresenter] Top view controller already presenting another controller")
#endif
                return
            }
            self.isPresented = false
#if DEBUG
            print("[FMDEBUG][Stripe][PaymentMethodsPresenter] Presenting from \(type(of: topVC))")
#endif
            sheet.present(from: topVC) { result in
#if DEBUG
                print("[FMDEBUG][Stripe][PaymentMethodsPresenter] Presentation completed result=\(String(describing: result))")
#endif
                self.onResult(result)
            }
        }
    }
}
