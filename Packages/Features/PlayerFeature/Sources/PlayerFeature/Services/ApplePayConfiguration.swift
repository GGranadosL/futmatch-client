import Foundation

// MARK: - ApplePayConfiguration

/// Apple Pay settings handed to Stripe's PaymentSheet.
///
/// `merchantId` must match the Merchant ID registered in Apple Developer, the
/// `com.apple.developer.in-app-payments` entitlement of the app target, and the
/// Apple Pay certificate uploaded to Stripe. `merchantCountryCode` is the country
/// of the Stripe account, not of the player.
struct ApplePayConfiguration {
    let merchantId: String
    let merchantCountryCode: String

    static let interfut = ApplePayConfiguration(
        merchantId: "merchant.com.futmatch.client",
        merchantCountryCode: "MX"
    )
}
