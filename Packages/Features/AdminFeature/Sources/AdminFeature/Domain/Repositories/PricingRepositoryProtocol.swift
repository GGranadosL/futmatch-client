import Foundation

protocol PricingRepositoryProtocol {
    func fetchEstimate(fieldId: String, maxPlayers: Int) async throws -> PricingEstimate
    func fetchCustom(fieldId: String, maxPlayers: Int, priceInCents: Int) async throws -> PricingOption
}
