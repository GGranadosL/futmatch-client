import SwiftUI
import FMDesignSystem
import SafariServices
import SharedModels
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

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
    var onAccountDeleted: (() -> Void)?
    var paymentHistoryViewModelFactory: (() -> PaymentHistoryViewModel)?

    @StateObject private var paymentMethodsVM: PaymentMethodsViewModel
    @StateObject private var deleteAccountVM: DeleteAccountViewModel
    @StateObject private var paymentSecurityVM: PaymentSecurityViewModel
    @State private var presentCustomerSheet = false
    @State private var showPaymentHistory = false
    @State private var safariURL: URL? = nil
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountDialog = false
    @State private var deleteAccountConfirmationText = ""
    @State private var showDeleteAccountSuccessToast = false
    @State private var showBiometricErrorToast = false
    @State private var showPaymentSecurityErrorToast = false
    private let linksConfig: LegalLinksProtocol

    init(
        onLogout: (() -> Void)? = nil,
        onAccountDeleted: (() -> Void)? = nil,
        paymentMethodsViewModel: PaymentMethodsViewModel? = nil,
        deleteAccountViewModel: DeleteAccountViewModel? = nil,
        paymentSecurityViewModel: PaymentSecurityViewModel? = nil,
        paymentHistoryViewModelFactory: (() -> PaymentHistoryViewModel)? = nil,
        linksConfig: LegalLinksProtocol = LegalLinksConfig()
    ) {
        self.onLogout = onLogout
        self.onAccountDeleted = onAccountDeleted
        self.paymentHistoryViewModelFactory = paymentHistoryViewModelFactory
        self.linksConfig = linksConfig
        _paymentMethodsVM = StateObject(wrappedValue: paymentMethodsViewModel ?? PaymentMethodsViewModel(paymentService: PaymentService()))
        _deleteAccountVM = StateObject(wrappedValue: deleteAccountViewModel ?? DeleteAccountViewModel(
            deleteAccountUseCase: PlayerDependencyFactory().makeDeleteAccountUseCase(),
            authorizeUseCase: PlayerDependencyFactory().makeAuthorizeSensitiveActionUseCase()
        ))
        _paymentSecurityVM = StateObject(wrappedValue: paymentSecurityViewModel ?? PlayerDependencyFactory().makePaymentSecurityViewModel())
    }

    // MARK: - Row Data

    /// "Versión 1.2.3 (45)" — reads the marketing version and build from the bundle.
    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(L10n.Settings.version) \(version) (\(build))"
    }

    /// Rows shown before the "Seguridad en pagos" toggle row.
    private var topGeneralRows: [SettingsRow] {
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
            )
        ]
    }

    /// Rows shown after the "Seguridad en pagos" toggle row.
    private var bottomGeneralRows: [SettingsRow] {
        [
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
        ZStack {
            VStack(spacing: 0) {
                List {
                    // General section
                    Section {
                        ForEach(topGeneralRows) { row in
                            settingsRowView(row)
                        }
                        paymentSecurityRow
                        ForEach(bottomGeneralRows) { row in
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

                        Button {
                            Task { await deleteAccountVM.requestDeletion() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(FMColors.error)
                                    .frame(width: 28, height: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.Settings.deleteAccount)
                                        .font(FMTypography.bodyMedium)
                                        .foregroundColor(FMColors.error)

                                    Text(L10n.Settings.deleteAccountDesc)
                                        .font(FMTypography.bodySmall)
                                        .foregroundColor(FMColors.onSurfaceVariant)
                                }

                                if deleteAccountVM.isVerifyingIdentity {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(deleteAccountVM.isVerifyingIdentity)
                    }

                    // Version footer
                    Section {
                        EmptyView()
                    } footer: {
                        Text(versionText)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(FMColors.background)

            if showDeleteAccountDialog {
                FMTextFieldConfirmationAlert(
                    title: L10n.DeleteAccount.dialogTitle,
                    message: L10n.DeleteAccount.dialogMessage(L10n.DeleteAccount.confirmationPhrase),
                    textFieldLabel: L10n.DeleteAccount.confirmationLabel,
                    text: $deleteAccountConfirmationText,
                    isSecureTextField: false,
                    errorMessage: deleteAccountVM.errorMessage,
                    primaryButtonTitle: L10n.DeleteAccount.confirmButton,
                    secondaryButtonTitle: L10n.Common.cancel,
                    isLoading: deleteAccountVM.isLoading,
                    isPrimaryEnabled: deleteAccountVM.isConfirmationValid(deleteAccountConfirmationText),
                    onPrimaryAction: {
                        Task { await deleteAccountVM.deleteAccount(confirmation: deleteAccountConfirmationText) }
                    },
                    onSecondaryAction: {
                        showDeleteAccountDialog = false
                        deleteAccountConfirmationText = ""
                        deleteAccountVM.clearError()
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Settings.title)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task {
            paymentSecurityVM.load()
        }
        .onChange(of: paymentMethodsVM.customerSheet != nil) { ready in
            if ready {
                presentCustomerSheet = true
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
        .onChange(of: deleteAccountVM.identityConfirmed) { confirmed in
            guard confirmed else { return }
            deleteAccountConfirmationText = ""
            deleteAccountVM.clearError()
            showDeleteAccountDialog = true
            deleteAccountVM.resetIdentityConfirmation()
        }
        .onChange(of: deleteAccountVM.biometricErrorMessage != nil) { hasError in
            if hasError { showBiometricErrorToast = true }
        }
        .onChange(of: deleteAccountVM.succeeded) { succeeded in
            guard succeeded else { return }
            showDeleteAccountDialog = false
            deleteAccountConfirmationText = ""
            showDeleteAccountSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                onAccountDeleted?()
            }
        }
        .fmToast(L10n.DeleteAccount.successMessage, isPresented: $showDeleteAccountSuccessToast, style: .success)
        .fmToast(deleteAccountVM.biometricErrorMessage ?? "", isPresented: $showBiometricErrorToast, style: .error)
        .onChange(of: showBiometricErrorToast) { showing in
            if !showing { deleteAccountVM.clearBiometricError() }
        }
        .onChange(of: paymentSecurityVM.errorMessage != nil) { hasError in
            if hasError { showPaymentSecurityErrorToast = true }
        }
        .fmToast(paymentSecurityVM.errorMessage ?? "", isPresented: $showPaymentSecurityErrorToast, style: .error)
        .onChange(of: showPaymentSecurityErrorToast) { showing in
            if !showing { paymentSecurityVM.clearError() }
        }
    }

    // MARK: - Payment Security Row

    /// Hand-built (not through `SettingsRow`/`settingsRowView`, which is
    /// chevron/navigation-only) since this row needs a `Toggle`.
    private var paymentSecurityRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(FMColors.primary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Settings.paymentSecurity)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurface)

                Text(L10n.Settings.paymentSecurityDesc)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }

            Spacer()

            if paymentSecurityVM.isVerifying {
                ProgressView()
            } else {
                Toggle("", isOn: paymentSecurityToggleBinding)
                    .labelsHidden()
                    .tint(FMColors.primary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Turning ON persists immediately; turning OFF must pass the biometric /
    /// passcode gate first (`PaymentSecurityViewModel.disable()`). A rejected
    /// `disable()` leaves `isEnabled == true`, so reading it back here snaps
    /// the switch back to ON with no extra revert code.
    private var paymentSecurityToggleBinding: Binding<Bool> {
        Binding(
            get: { paymentSecurityVM.isEnabled },
            set: { newValue in
                if newValue {
                    paymentSecurityVM.enable()
                } else {
                    Task { await paymentSecurityVM.disable() }
                }
            }
        )
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
            // Whole row tappable, including the gap before the chevron
            .contentShape(Rectangle())
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
            Task { await paymentMethodsVM.loadCustomerSheet() }
        } else if row.title == L10n.Settings.paymentHistory {
            showPaymentHistory = true
        } else if row.title == L10n.Settings.help {
            safariURL = linksConfig.helpURL
        } else if row.title == L10n.Settings.terms {
            safariURL = linksConfig.termsURL
        } else if row.title == L10n.Settings.privacy {
            safariURL = linksConfig.privacyURL
        }
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
