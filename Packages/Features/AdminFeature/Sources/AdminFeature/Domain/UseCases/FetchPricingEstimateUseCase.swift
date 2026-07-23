import Foundation

public protocol FetchPricingEstimateUseCaseProtocol {
    func execute(fieldId: String, maxPlayers: Int) async throws -> PricingEstimate
}

struct FetchPricingEstimateUseCase: FetchPricingEstimateUseCaseProtocol {
    private let repository: PricingRepositoryProtocol

    init(repository: PricingRepositoryProtocol) {
        self.repository = repository
    }

    func execute(fieldId: String, maxPlayers: Int) async throws -> PricingEstimate {
        try await repository.fetchEstimate(fieldId: fieldId, maxPlayers: maxPlayers)
    }
}
