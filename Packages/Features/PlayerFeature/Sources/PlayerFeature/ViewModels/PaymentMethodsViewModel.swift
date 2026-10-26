import Foundation
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

// MARK: - PaymentMethodsViewModel

@MainActor
final class PaymentMethodsViewModel: ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var customerSheet: CustomerSheet?
    /// True from the moment Stripe's sheet is asked to present until it reports a result.
    @Published private(set) var isPresenting = false
    /// A new value asks the view to present `customerSheet`. One value = one presentation.
    @Published private(set) var presentationRequest: UUID?

    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    /// Entry point for the "Payment methods" row. Repeated taps while loading or
    /// while the sheet is up are ignored. A sheet built earlier is reused: Stripe
    /// fetches a fresh Customer Session on every `present`, so only the first open waits.
    func open() async {
        guard !isLoading, !isPresenting else { return }
        error = nil
        if customerSheet == nil {
            await loadCustomerSheet()
        }
        guard customerSheet != nil, error == nil else { return }
        presentationRequest = UUID()
    }

    func presentationStarted() {
        isPresenting = true
    }

    /// The view could not find a view controller to present from.
    func presentationFailed() {
        isPresenting = false
        error = L10n.Settings.paymentMethodsOpenError
    }

    func loadCustomerSheet() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        customerSheet = nil
        do {
            let session = try await paymentService.fetchCustomerSession()
            STPAPIClient.shared.publishableKey = session.publishableKey

            var config = CustomerSheet.Configuration()
            config.merchantDisplayName = "Interfut"
            config.applePayEnabled = true

            let service = self.paymentService
            let intentConfig = CustomerSheet.IntentConfiguration {
                try await service.createSetupIntent().clientSecret
            }

            let sheet = CustomerSheet(
                configuration: config,
                intentConfiguration: intentConfig,
                customerSessionClientSecretProvider: {
                    let fresh = try await service.fetchCustomerSession()
                    return CustomerSessionClientSecret(
                        customerId: fresh.customerId,
                        clientSecret: fresh.customerSessionClientSecret
                    )
                }
            )
            self.customerSheet = sheet
        } catch {
            guard !error.isCancellation else { return }
            self.error = Self.message(for: error)
        }
    }

    func handleCustomerSheetResult(_ result: CustomerSheet.CustomerSheetResult) {
        isPresenting = false
        switch result {
        case .selected, .canceled:
            error = nil
        case .error(let error):
            customerSheet = nil
            self.error = Self.message(for: error)
        }
    }

    func clearError() {
        error = nil
    }

    private static func message(for error: Error) -> String {
        let details = [error.localizedDescription, String(describing: error)]
            .joined(separator: " ")
            .lowercased()

        if details.contains("customer_sheet") && details.contains("component enabled") {
            return "Stripe CustomerSheet en iOS rechazo esta sesion porque no incluye el componente customer_sheet. Para seguir usando el sheet de Stripe, el backend debe devolver una Customer Session con customer_sheet habilitado o exponer un endpoint de ephemeral key para StripeCustomerAdapter."
        }

        return error.localizedDescription
    }
}

// MARK: - Error

private enum PaymentMethodsError: LocalizedError {
    case deallocated

    var errorDescription: String? {
        switch self {
        case .deallocated:
            return "Payment session expired"
        }
    }
}
