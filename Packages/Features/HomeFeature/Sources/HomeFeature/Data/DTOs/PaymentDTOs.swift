import Foundation

// MARK: - Customer Session

struct CustomerSessionData: Decodable {
    let customerId: String
    let customerSessionClientSecret: String
    let publishableKey: String
}

struct CustomerSessionResponse: Decodable {
    let data: CustomerSessionData
}

// MARK: - Setup Intent

struct SetupIntentData: Decodable {
    let customerId: String
    let clientSecret: String
    let publishableKey: String
}

struct SetupIntentResponse: Decodable {
    let data: SetupIntentData
}

// MARK: - Payment Method

struct PaymentMethodItem: Decodable, Identifiable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
}

struct PaymentMethodsResponse: Decodable {
    let data: [PaymentMethodItem]
}

// MARK: - Payment History

struct PaymentHistoryItem: Decodable, Identifiable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let createdAt: Int64
    let paidAt: Int64?
    let paymentMethod: PaymentMethodInfo?
    let refund: RefundInfo?
}

struct PaymentMethodInfo: Decodable {
    let last4: String
    let brand: String
}

struct RefundInfo: Decodable {
    let id: String
    let amount: Int
    let status: String
    let createdAt: Int64
    let refundedAt: Int64?
}

struct PaymentHistoryResponse: Decodable {
    let data: [PaymentHistoryItem]
}
