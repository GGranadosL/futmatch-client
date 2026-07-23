import Foundation

public protocol FetchCustomPricingUseCaseProtocol {
    func execute(fieldId: String, maxPlayers: Int, priceInCents: Int) async throws -> PricingOption
}

struct FetchCustomPricingUseCase: FetchCustomPricingUseCaseProtocol {
    private let repository: PricingRepositoryProtocol

    init(repository: PricingRepositoryProtocol) {
        self.repository = repository
    }

    func execute(fieldId: String, maxPlayers: Int, priceInCents: Int) async throws -> PricingOption {
        try await repository.fetchCustom(fieldId: fieldId, maxPlayers: maxPlayers, priceInCents: priceInCents)
    }
}
