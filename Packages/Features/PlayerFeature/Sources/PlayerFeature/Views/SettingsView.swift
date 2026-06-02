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
    @State private var showLogoutAlert = false

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
                        showLogoutAlert = true
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.Settings.title)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
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
        .alert(L10n.Profile.logoutTitle, isPresented: $showLogoutAlert) {
            Button(L10n.Profile.logoutConfirm, role: .destructive) {
                onLogout?()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Profile.logoutMessage)
        }
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

    final class Coordinator {
        var isPresenting = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let sheet = customerSheet, !context.coordinator.isPresenting else { return }
        context.coordinator.isPresenting = true

        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
                context.coordinator.isPresenting = false
                return
            }

            guard rootVC.presentedViewController == nil else {
                context.coordinator.isPresenting = false
                return
            }

            sheet.present(from: rootVC) { result in
                context.coordinator.isPresenting = false
                self.isPresented = false
                self.onResult(result)
            }
        }
    }
}
