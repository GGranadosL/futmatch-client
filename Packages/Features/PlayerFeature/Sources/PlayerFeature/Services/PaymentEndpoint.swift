import Foundation
import NetworkFramework

// MARK: - PaymentEndpoint

enum PaymentEndpoint: APIEndpoint {
    case customerSheetInit
    case setupIntent
    case paymentMethods
    case deletePaymentMethod(id: String)
    case paymentHistory
    case pollPayment(matchId: String)
    case paymentStatus(matchId: String)

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
        case .pollPayment(let matchId):
            return "/payment/poll/\(matchId)"
        case .paymentStatus(let matchId):
            return "/payment/status/\(matchId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .customerSheetInit, .setupIntent:
            return .post
        case .paymentMethods, .paymentHistory, .pollPayment, .paymentStatus:
            return .get
        case .deletePaymentMethod:
            return .delete
        }
    }

    var body: Data? { nil }
}
