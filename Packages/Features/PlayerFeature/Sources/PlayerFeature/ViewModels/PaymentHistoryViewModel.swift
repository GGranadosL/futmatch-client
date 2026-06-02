import Foundation

// MARK: - PaymentHistoryViewModel

@MainActor
final class PaymentHistoryViewModel: ObservableObject {

    @Published private(set) var payments: [PaymentHistoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            payments = try await paymentService.fetchPaymentHistory()
        } catch {
            guard !(error is CancellationError) else { return }
            self.error = error.localizedDescription
            payments = []
        }
        isLoading = false
    }
}

// MARK: - Formatting Helpers

extension PaymentHistoryItem {
    var formattedAmount: String {
        let value = Double(amount) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: Double(createdAt) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedShortDate: String {
        let date = Date(timeIntervalSince1970: Double(createdAt) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MMM/yyyy"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: date)
    }

    var brandIcon: String {
        switch paymentMethod?.brand.lowercased() {
        case "visa": return "creditcard"
        case "mastercard": return "creditcard"
        case "amex": return "creditcard"
        default: return "creditcard"
        }
    }

    var isRefunded: Bool {
        refund != nil
    }

    var statusKey: String {
        if isRefunded { return "refunded" }
        return status
    }
}
