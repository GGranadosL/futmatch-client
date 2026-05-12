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
        debugLog("Starting customer sheet load")
        do {
            let session = try await paymentService.fetchCustomerSession()
            debugLog(
                "Fetched session customerId=\(session.customerId) publishableKeyPrefix=\(session.publishableKey.prefix(12)) customerSessionSecretPrefix=\(session.customerSessionClientSecret.prefix(12))"
            )
            STPAPIClient.shared.publishableKey = session.publishableKey

            var config = CustomerSheet.Configuration()
            config.merchantDisplayName = "FutMatch"
            config.applePayEnabled = true

            let service = self.paymentService
            let intentConfig = CustomerSheet.IntentConfiguration {
                let setupIntent = try await service.createSetupIntent()
                Self.debugStaticLog(
                    "Created setup intent customerId=\(setupIntent.customerId) publishableKeyPrefix=\(setupIntent.publishableKey.prefix(12)) clientSecretPrefix=\(setupIntent.clientSecret.prefix(12))"
                )
                return setupIntent.clientSecret
            }

            let customerId = session.customerId
            let clientSecret = session.customerSessionClientSecret
            let sheet = CustomerSheet(
                configuration: config,
                intentConfiguration: intentConfig,
                customerSessionClientSecretProvider: {
                    Self.debugStaticLog(
                        "Providing customer session secret customerId=\(customerId) clientSecretPrefix=\(clientSecret.prefix(12))"
                    )
                    return CustomerSessionClientSecret(
                        customerId: customerId,
                        clientSecret: clientSecret
                    )
                }
            )
            self.customerSheet = sheet
            debugLog("CustomerSheet instance created successfully")
        } catch {
            debugLog("CustomerSheet load failed error=\(String(describing: error))")
            self.error = Self.message(for: error)
        }
        isLoading = false
        debugLog("Finished customer sheet load isLoading=\(isLoading) hasSheet=\(customerSheet != nil) hasError=\(error != nil)")
    }

    func handleCustomerSheetResult(_ result: CustomerSheet.CustomerSheetResult) {
        debugLog("Received CustomerSheet result=\(String(describing: result))")
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

    private func debugLog(_ message: String) {
        Self.debugStaticLog(message)
    }

    private static func debugStaticLog(_ message: String) {
#if DEBUG
        print("[FMDEBUG][Stripe][PaymentMethodsVM] \(message)")
#endif
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
