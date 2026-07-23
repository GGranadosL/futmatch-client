import Foundation

struct PricingRepository: PricingRepositoryProtocol {
    private let service: PricingService

    init(service: PricingService) {
        self.service = service
    }

    func fetchEstimate(fieldId: String, maxPlayers: Int) async throws -> PricingEstimate {
        let dto = try await service.fetchEstimate(fieldId: fieldId, maxPlayers: maxPlayers)
        return dto.toDomain()
    }

    func fetchCustom(fieldId: String, maxPlayers: Int, priceInCents: Int) async throws -> PricingOption {
        let dto = try await service.fetchCustom(fieldId: fieldId, maxPlayers: maxPlayers, priceInCents: priceInCents)
        return dto.toDomain()
    }
}
