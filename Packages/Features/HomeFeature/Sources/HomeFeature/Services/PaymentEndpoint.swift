import Foundation
import NetworkFramework

// MARK: - PaymentEndpoint

enum PaymentEndpoint: APIEndpoint {
    case customerSheetInit
    case setupIntent
    case paymentMethods
    case deletePaymentMethod(id: String)
    case paymentHistory

    var path: String {
        switch self {
        case .customerSheetInit:
            return "/payment/customer-sheet/init"
        case .setupIntent:
            return "/payment/setup-intent"
        case .paymentMethods:
            return "/payment/methods"
        case .deletePaymentMethod(let id):
            return "/payment/methods/\(id)"
        case .paymentHistory:
            return "/user/payments"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .customerSheetInit, .setupIntent:
            return .post
        case .paymentMethods, .paymentHistory:
            return .get
        case .deletePaymentMethod:
            return .delete
        }
    }

    var body: Data? { nil }
}
