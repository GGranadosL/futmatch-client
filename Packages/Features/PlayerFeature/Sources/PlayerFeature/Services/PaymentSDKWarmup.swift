import Foundation
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet

/// Touches Stripe types off the interaction path so their one-time dyld binding
/// and static-init cost lands during background app startup instead of stalling
/// the first screen that references `StripePaymentSheet` in a session (usually
/// Settings or the match payment flow).
enum PaymentSDKWarmup {
    static func prewarm() {
        _ = CustomerSheet.Configuration()
        _ = STPAPIClient.shared
    }
}
