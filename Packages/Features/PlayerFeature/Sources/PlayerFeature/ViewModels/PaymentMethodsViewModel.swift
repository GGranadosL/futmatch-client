import Foundation
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

// MARK: - PaymentMethodsViewModel

@MainActor
final class PaymentMethodsViewModel: ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var customerSheet: CustomerSheet?

    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    func loadCustomerSheet() async {
        isLoading = true
        error = nil
        customerSheet = nil
        do {
            let session = try await paymentService.fetchCustomerSession()
            STPAPIClient.shared.publishableKey = session.publishableKey

            var config = CustomerSheet.Configuration()
            config.merchantDisplayName = "FutMatch"
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
            guard !(error is CancellationError) else { return }
            self.error = Self.message(for: error)
        }
        isLoading = false
    }

    func handleCustomerSheetResult(_ result: CustomerSheet.CustomerSheetResult) {
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
