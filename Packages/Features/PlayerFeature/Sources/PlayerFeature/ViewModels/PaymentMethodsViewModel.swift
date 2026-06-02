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
        await verifyAttachedCards("on open")
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
            let sessionCustomerId = session.customerId
            let intentConfig = CustomerSheet.IntentConfiguration {
                Self.debugStaticLog("IntentConfiguration called — creating setup intent for customerId=\(sessionCustomerId)")
                do {
                    let setupIntent = try await service.createSetupIntent()
                    Self.debugStaticLog(
                        "✅ Setup intent created — setupCustomerId=\(setupIntent.customerId) sessionCustomerId=\(sessionCustomerId) match=\(setupIntent.customerId == sessionCustomerId) clientSecretPrefix=\(setupIntent.clientSecret.prefix(20))"
                    )
                    return setupIntent.clientSecret
                } catch {
                    Self.debugStaticLog("❌ Setup intent FAILED: \(error)")
                    throw error
                }
            }

            let sheet = CustomerSheet(
                configuration: config,
                intentConfiguration: intentConfig,
                customerSessionClientSecretProvider: {
                    Self.debugStaticLog("customerSessionClientSecretProvider called — fetching fresh session")
                    do {
                        let fresh = try await service.fetchCustomerSession()
                        Self.debugStaticLog(
                            "✅ Fresh session — customerId=\(fresh.customerId) clientSecretPrefix=\(fresh.customerSessionClientSecret.prefix(20))"
                        )
                        return CustomerSessionClientSecret(
                            customerId: fresh.customerId,
                            clientSecret: fresh.customerSessionClientSecret
                        )
                    } catch {
                        Self.debugStaticLog("❌ customerSessionClientSecretProvider FAILED: \(error)")
                        throw error
                    }
                }
            )
            self.customerSheet = sheet
            debugLog("CustomerSheet instance created successfully")
        } catch {
            guard !(error is CancellationError) else { return }
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
            Task { await verifyAttachedCards("after sheet") }
        case .error(let error):
            customerSheet = nil
            self.error = Self.message(for: error)
        }
    }

    /// Diagnostic: queries the backend's own payment-methods listing (which reflects
    /// what's actually *attached* to the Stripe customer, unfiltered by `allow_redisplay`).
    /// If a just-added card is missing here, it was never attached (SetupIntent likely
    /// created without `customer`). If it's present, the issue is only how CustomerSheet
    /// surfaces it (the `allow_redisplay` filter on the CustomerSession).
    private func verifyAttachedCards(_ context: String) async {
        do {
            let methods = try await paymentService.fetchPaymentMethods()
            let summary = methods
                .map { "\($0.brand)****\($0.last4) [\($0.id)]" }
                .joined(separator: ", ")
            debugLog("🔎 [\(context)] Backend /payment/methods → \(methods.count) attached card(s): \(summary.isEmpty ? "none" : summary)")
        } catch {
            debugLog("🔎 [\(context)] Backend /payment/methods FAILED: \(String(describing: error))")
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
