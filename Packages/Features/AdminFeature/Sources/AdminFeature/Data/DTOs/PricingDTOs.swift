import Foundation

// MARK: - Request DTOs

struct PricingEstimateRequestDTO: Encodable {
    let maxPlayers: Int

    enum CodingKeys: String, CodingKey {
        case maxPlayers
    }
}

struct CustomPricingRequestDTO: Encodable {
    let maxPlayers: Int
    let pricePerPlayerInCents: Int

    enum CodingKeys: String, CodingKey {
        case maxPlayers
        case pricePerPlayerInCents
    }
}

// MARK: - Response DTOs

struct PricingBreakdownDTO: Decodable {
    let players: Int
    let grossRevenueInCents: Int
    let stripeFixedFeeInCents: Int
    let stripePercentFeeInCents: Int
    let totalStripeFeesInCents: Int
    let netRevenueInCents: Int
    let fieldCostInCents: Int
    let organizerFeeInCents: Int
    let targetProfitInCents: Int
    let estimatedProfitInCents: Int

    enum CodingKeys: String, CodingKey {
        case players
        case grossRevenueInCents
        case stripeFixedFeeInCents
        case stripePercentFeeInCents
        case totalStripeFeesInCents
        case netRevenueInCents
        case fieldCostInCents
        case organizerFeeInCents
        case targetProfitInCents
        case estimatedProfitInCents
    }

    func toDomain() -> PricingBreakdown {
        PricingBreakdown(
            players: players,
            grossRevenueInCents: grossRevenueInCents,
            stripeFixedFeeInCents: stripeFixedFeeInCents,
            stripePercentFeeInCents: stripePercentFeeInCents,
            totalStripeFeesInCents: totalStripeFeesInCents,
            netRevenueInCents: netRevenueInCents,
            fieldCostInCents: fieldCostInCents,
            organizerFeeInCents: organizerFeeInCents,
            targetProfitInCents: targetProfitInCents,
            estimatedProfitInCents: estimatedProfitInCents
        )
    }
}

struct PricingOptionDTO: Decodable {
    let pricePerPlayerInCents: Int
    let breakEvenPlayersRequired: Int
    let minimumPlayersToStart: Int
    let estimatedProfitAtMinimumPlayersInCents: Int
    let estimatedProfitAtFullCapacityInCents: Int
    let isViable: Bool
    let isRecommended: Bool
    let label: String
    let breakdownAtMinimumPlayersToStart: PricingBreakdownDTO
    let breakdownAtFullCapacity: PricingBreakdownDTO

    enum CodingKeys: String, CodingKey {
        case pricePerPlayerInCents
        case breakEvenPlayersRequired
        case minimumPlayersToStart
        case estimatedProfitAtMinimumPlayersInCents
        case estimatedProfitAtFullCapacityInCents
        case isViable
        case isRecommended
        case label
        case breakdownAtMinimumPlayersToStart
        case breakdownAtFullCapacity
    }

    func toDomain() -> PricingOption {
        PricingOption(
            pricePerPlayerInCents: pricePerPlayerInCents,
            breakEvenPlayersRequired: breakEvenPlayersRequired,
            minimumPlayersToStart: minimumPlayersToStart,
            estimatedProfitAtMinimumPlayersInCents: estimatedProfitAtMinimumPlayersInCents,
            estimatedProfitAtFullCapacityInCents: estimatedProfitAtFullCapacityInCents,
            isViable: isViable,
            isRecommended: isRecommended,
            label: PricingOptionLabel(rawValue: label) ?? .suggested,
            breakdownAtMinimumPlayersToStart: breakdownAtMinimumPlayersToStart.toDomain(),
            breakdownAtFullCapacity: breakdownAtFullCapacity.toDomain()
        )
    }
}

struct PricingEstimateResponseWrapperDTO: Decodable {
    let data: PricingEstimateResponseDTO
}

struct PricingEstimateResponseDTO: Decodable {
    let fieldId: String
    let fieldName: String
    let fieldCapacity: Int
    let maxPlayers: Int
    let fieldCostInCents: Int
    let organizerFeeInCents: Int
    let currency: String
    let constraints: ConstraintsDTO
    let operationalInsights: OperationalInsightsDTO
    let recommendedOption: PricingOptionDTO
    let pricingOptions: [PricingOptionDTO]
    let selectedOption: PricingOptionDTO

    enum CodingKeys: String, CodingKey {
        case fieldId
        case fieldName
        case fieldCapacity
        case maxPlayers
        case fieldCostInCents
        case organizerFeeInCents
        case currency
        case constraints
        case operationalInsights
        case recommendedOption
        case pricingOptions
        case selectedOption
    }

    func toDomain() -> PricingEstimate {
        PricingEstimate(
            fieldId: fieldId,
            fieldName: fieldName,
            fieldCapacity: fieldCapacity,
            maxPlayers: maxPlayers,
            fieldCostInCents: fieldCostInCents,
            organizerFeeInCents: organizerFeeInCents,
            currency: currency,
            maxPricePerPlayerInCents: constraints.maxPricePerPlayerInCents,
            priceStepInCents: constraints.priceStepInCents,
            breakEvenPlayersRequired: operationalInsights.breakEvenPlayersRequired,
            recommendedOption: recommendedOption.toDomain(),
            pricingOptions: pricingOptions.map { $0.toDomain() },
            selectedOption: selectedOption.toDomain()
        )
    }
}

struct ConstraintsDTO: Decodable {
    let minimumProfitInCents: Int
    let maxPricePerPlayerInCents: Int
    let priceStepInCents: Int
    let stripePercentFeeBps: Int
    let stripeFixedFeeCents: Int
    let futmatchProfitBps: Int
    let usesFieldOverrides: Bool

    enum CodingKeys: String, CodingKey {
        case minimumProfitInCents
        case maxPricePerPlayerInCents
        case priceStepInCents
        case stripePercentFeeBps
        case stripeFixedFeeCents
        case futmatchProfitBps
        case usesFieldOverrides
    }
}

struct OperationalInsightsDTO: Decodable {
    let breakEvenPlayersRequired: Int
    let recommendedMinimumPlayersToStart: Int

    enum CodingKeys: String, CodingKey {
        case breakEvenPlayersRequired
        case recommendedMinimumPlayersToStart
    }
}

struct CustomPricingResponseWrapperDTO: Decodable {
    let data: CustomPricingResponseDTO
}

struct CustomPricingResponseDTO: Decodable {
    let fieldId: String
    let fieldName: String
    let fieldCapacity: Int
    let maxPlayers: Int
    let currency: String
    let constraints: ConstraintsDTO
    let result: PricingOptionDTO

    enum CodingKeys: String, CodingKey {
        case fieldId
        case fieldName
        case fieldCapacity
        case maxPlayers
        case currency
        case constraints
        case result
    }

    func toDomain() -> PricingOption {
        result.toDomain()
    }
}
