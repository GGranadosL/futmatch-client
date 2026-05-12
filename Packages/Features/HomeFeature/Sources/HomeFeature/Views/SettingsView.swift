import SwiftUI
import FMDesignSystem
import SafariServices
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

// MARK: - Static Web URLs (TODO: replace with real hosted URLs before release)

private enum FutMatchURLs {
    static let help    = URL(string: "https://futmatch.app/ayuda")!
    static let terms   = URL(string: "https://futmatch.app/terminos")!
    static let privacy = URL(string: "https://futmatch.app/privacidad")!
}

// MARK: - SettingsRow Model

private struct SettingsRow: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

// MARK: - SettingsView

/// Settings screen accessible from the profile gear icon.
/// Displays grouped rows for payment, help, legal, appearance, and account actions.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var onLogout: (() -> Void)?
    var paymentHistoryViewModelFactory: (() -> PaymentHistoryViewModel)?

    @StateObject private var paymentMethodsVM: PaymentMethodsViewModel
    @State private var presentCustomerSheet = false
    @State private var showPaymentHistory = false
    @State private var safariURL: URL? = nil

    init(
        onLogout: (() -> Void)? = nil,
        paymentMethodsViewModel: PaymentMethodsViewModel? = nil,
        paymentHistoryViewModelFactory: (() -> PaymentHistoryViewModel)? = nil
    ) {
        self.onLogout = onLogout
        self.paymentHistoryViewModelFactory = paymentHistoryViewModelFactory
        _paymentMethodsVM = StateObject(wrappedValue: paymentMethodsViewModel ?? PaymentMethodsViewModel(paymentService: PaymentService()))
    }

    // MARK: - Row Data

    private var generalRows: [SettingsRow] {
        [
            SettingsRow(
                icon: "creditcard",
                iconColor: FMColors.primary,
                title: L10n.Settings.paymentMethods,
                subtitle: L10n.Settings.paymentMethodsDesc
            ),
            SettingsRow(
                icon: "clock.arrow.circlepath",
                iconColor: FMColors.primary,
                title: L10n.Settings.paymentHistory,
                subtitle: L10n.Settings.paymentHistoryDesc
            ),
            SettingsRow(
                icon: "questionmark.circle",
                iconColor: FMColors.primary,
                title: L10n.Settings.help,
                subtitle: L10n.Settings.helpDesc
            ),
            SettingsRow(
                icon: "doc.text",
                iconColor: FMColors.primary,
                title: L10n.Settings.terms,
                subtitle: L10n.Settings.termsDesc
            ),
            SettingsRow(
                icon: "lock.shield",
                iconColor: FMColors.primary,
                title: L10n.Settings.privacy,
                subtitle: L10n.Settings.privacyDesc
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            List {
                // General section
                Section {
                    ForEach(generalRows) { row in
                        settingsRowView(row)
                    }
                }

                // Account actions section
                Section {
                    Button {
                        onLogout?()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(FMColors.error)
                                .frame(width: 28, height: 28)

                            Text(L10n.Settings.logout)
                                .font(FMTypography.bodyMedium)
                                .foregroundColor(FMColors.error)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(FMColors.background)
        .navigationBarHidden(true)
        .onChange(of: paymentMethodsVM.customerSheet != nil) { ready in
            debugLog("customerSheet ready changed ready=\(ready)")
            if ready {
                presentCustomerSheet = true
                debugLog("Setting presentCustomerSheet=true")
            }
        }
        .background(
            CustomerSheetPresenter(
                customerSheet: paymentMethodsVM.customerSheet,
                isPresented: $presentCustomerSheet
            ) { result in
                paymentMethodsVM.handleCustomerSheetResult(result)
            }
        )
        .alert(
            L10n.Settings.paymentMethods,
            isPresented: Binding(
                get: { paymentMethodsVM.error != nil },
                set: { if !$0 { paymentMethodsVM.clearError() } }
            )
        ) {
            Button(L10n.Common.retry) {
                Task { await paymentMethodsVM.loadCustomerSheet() }
            }
            Button(L10n.Common.cancel, role: .cancel) {
                paymentMethodsVM.clearError()
            }
        } message: {
            Text(paymentMethodsVM.error ?? "")
        }
        .navigationDestination(isPresented: $showPaymentHistory) {
            if let factory = paymentHistoryViewModelFactory {
                PaymentHistoryView(viewModel: factory())
            }
        }
        .sheet(item: $safariURL) { url in
            SafariBrowserView(url: url)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Text(L10n.Settings.title)
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

    // MARK: - Row View

    private func settingsRowView(_ row: SettingsRow) -> some View {
        Button {
            handleRowTap(row)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: row.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(row.iconColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurface)

                    Text(row.subtitle)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FMColors.outline)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}

// MARK: - Row Actions

private extension SettingsView {
    func handleRowTap(_ row: SettingsRow) {
        if row.title == L10n.Settings.paymentMethods {
            debugLog("Tapped payment methods row")
            Task { await paymentMethodsVM.loadCustomerSheet() }
        } else if row.title == L10n.Settings.paymentHistory {
            showPaymentHistory = true
        } else if row.title == L10n.Settings.help {
            safariURL = FutMatchURLs.help
        } else if row.title == L10n.Settings.terms {
            safariURL = FutMatchURLs.terms
        } else if row.title == L10n.Settings.privacy {
            safariURL = FutMatchURLs.privacy
        }
    }

    func debugLog(_ message: String) {
#if DEBUG
        print("[FMDEBUG][Stripe][SettingsView] \(message)")
#endif
    }
}

// MARK: - Safari In-App Browser

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct SafariBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
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
        print("[FMDEBUG][Stripe][CustomerSheetPresenter] Attempting presentation isPresented=\(isPresented)")
#endif

        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
#if DEBUG
                print("[FMDEBUG][Stripe][CustomerSheetPresenter] No active root view controller found")
#endif
                return
            }

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            guard topVC.presentedViewController == nil else {
#if DEBUG
                print("[FMDEBUG][Stripe][CustomerSheetPresenter] Top view controller already presenting another controller")
#endif
                return
            }
            self.isPresented = false
#if DEBUG
            print("[FMDEBUG][Stripe][CustomerSheetPresenter] Presenting from \(type(of: topVC))")
#endif
            sheet.present(from: topVC) { result in
#if DEBUG
                print("[FMDEBUG][Stripe][CustomerSheetPresenter] Presentation completed result=\(String(describing: result))")
#endif
                self.onResult(result)
            }
        }
    }
}
