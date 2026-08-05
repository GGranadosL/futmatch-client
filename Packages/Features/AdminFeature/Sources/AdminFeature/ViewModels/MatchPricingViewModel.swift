import Foundation
import Combine

@MainActor
final class MatchPricingViewModel: ObservableObject {
    let estimate: PricingEstimate
    let fieldId: String

    @Published var selectedOption: PricingOption
    @Published var customPriceText: String = ""
    @Published var isLoadingCustom = false
    @Published var customError: String?

    private let fetchCustom: FetchCustomPricingUseCaseProtocol
    private var debounceTask: Task<Void, Never>?

    init(
        estimate: PricingEstimate,
        fieldId: String,
        fetchCustom: FetchCustomPricingUseCaseProtocol
    ) {
        self.estimate = estimate
        self.fieldId = fieldId
        self.fetchCustom = fetchCustom
        self.selectedOption = estimate.pricingOptions.first { $0.pricePerPlayerInCents == estimate.selectedOption.pricePerPlayerInCents }
            ?? estimate.selectedOption
        // Pre-fill the input with the recommended/selected price (spec: "el input
        // de precio se llena con la opción recomendada").
        self.customPriceText = String(format: "%.0f", Double(estimate.selectedOption.pricePerPlayerInCents) / 100.0)
    }

    func selectChip(_ option: PricingOption) {
        selectedOption = option
        customPriceText = formatPrice(option.pricePerPlayerInCents)
        customError = nil
    }

    func onCustomPriceChanged(_ text: String) {
        customPriceText = text
        guard let priceInCents = parsePrice(text) else {
            debounceTask?.cancel()
            return
        }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            if let existing = estimate.pricingOptions.first(where: { $0.pricePerPlayerInCents == priceInCents }) {
                selectedOption = existing
                customError = nil
                return
            }

            isLoadingCustom = true
            customError = nil
            do {
                let option = try await fetchCustom.execute(
                    fieldId: fieldId,
                    maxPlayers: estimate.maxPlayers,
                    priceInCents: priceInCents
                )
                selectedOption = option
            } catch {
                customError = error.localizedDescription
            }
            isLoadingCustom = false
        }
    }

    private func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "%.0f", dollars)
    }

    private func parsePrice(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let dollars = Double(cleaned), dollars >= 0 else { return nil }
        return Int(dollars * 100)
    }
}
