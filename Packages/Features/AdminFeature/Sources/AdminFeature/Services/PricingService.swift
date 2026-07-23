import Foundation
import NetworkFramework

struct PricingService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchEstimate(fieldId: String, maxPlayers: Int) async throws -> PricingEstimateResponseDTO {
        let body = PricingEstimateRequestDTO(maxPlayers: maxPlayers)
        let wrapper: PricingEstimateResponseWrapperDTO = try await apiClient.request(
            endpoint: FieldEndpoint.pricingEstimate(fieldId: fieldId),
            body: body
        )
        return wrapper.data
    }

    func fetchCustom(fieldId: String, maxPlayers: Int, priceInCents: Int) async throws -> CustomPricingResponseDTO {
        let body = CustomPricingRequestDTO(maxPlayers: maxPlayers, pricePerPlayerInCents: priceInCents)
        let wrapper: CustomPricingResponseWrapperDTO = try await apiClient.request(
            endpoint: FieldEndpoint.pricingCustom(fieldId: fieldId),
            body: body
        )
        return wrapper.data
    }
}
