import Foundation

// MARK: - Pricing Option Label

public enum PricingOptionLabel: String, Codable {
    case recommended = "RECOMMENDED"
    case suggested = "SUGGESTED"
    case custom = "CUSTOM"
}

// MARK: - Pricing Breakdown

public struct PricingBreakdown: Equatable {
    public let players: Int
    public let grossRevenueInCents: Int
    public let stripeFixedFeeInCents: Int
    public let stripePercentFeeInCents: Int
    public let totalStripeFeesInCents: Int
    public let netRevenueInCents: Int
    public let fieldCostInCents: Int
    public let organizerFeeInCents: Int
    public let targetProfitInCents: Int
    public let estimatedProfitInCents: Int

    public init(
        players: Int,
        grossRevenueInCents: Int,
        stripeFixedFeeInCents: Int,
        stripePercentFeeInCents: Int,
        totalStripeFeesInCents: Int,
        netRevenueInCents: Int,
        fieldCostInCents: Int,
        organizerFeeInCents: Int,
        targetProfitInCents: Int,
        estimatedProfitInCents: Int
    ) {
        self.players = players
        self.grossRevenueInCents = grossRevenueInCents
        self.stripeFixedFeeInCents = stripeFixedFeeInCents
        self.stripePercentFeeInCents = stripePercentFeeInCents
        self.totalStripeFeesInCents = totalStripeFeesInCents
        self.netRevenueInCents = netRevenueInCents
        self.fieldCostInCents = fieldCostInCents
        self.organizerFeeInCents = organizerFeeInCents
        self.targetProfitInCents = targetProfitInCents
        self.estimatedProfitInCents = estimatedProfitInCents
    }
}

// MARK: - Pricing Option

public struct PricingOption: Equatable, Identifiable {
    public let id: String
    public let pricePerPlayerInCents: Int
    public let breakEvenPlayersRequired: Int
    public let minimumPlayersToStart: Int
    public let estimatedProfitAtMinimumPlayersInCents: Int
    public let estimatedProfitAtFullCapacityInCents: Int
    public let isViable: Bool
    public let isRecommended: Bool
    public let label: PricingOptionLabel
    public let breakdownAtMinimumPlayersToStart: PricingBreakdown
    public let breakdownAtFullCapacity: PricingBreakdown

    public init(
        pricePerPlayerInCents: Int,
        breakEvenPlayersRequired: Int,
        minimumPlayersToStart: Int,
        estimatedProfitAtMinimumPlayersInCents: Int,
        estimatedProfitAtFullCapacityInCents: Int,
        isViable: Bool,
        isRecommended: Bool,
        label: PricingOptionLabel,
        breakdownAtMinimumPlayersToStart: PricingBreakdown,
        breakdownAtFullCapacity: PricingBreakdown
    ) {
        self.id = UUID().uuidString
        self.pricePerPlayerInCents = pricePerPlayerInCents
        self.breakEvenPlayersRequired = breakEvenPlayersRequired
        self.minimumPlayersToStart = minimumPlayersToStart
        self.estimatedProfitAtMinimumPlayersInCents = estimatedProfitAtMinimumPlayersInCents
        self.estimatedProfitAtFullCapacityInCents = estimatedProfitAtFullCapacityInCents
        self.isViable = isViable
        self.isRecommended = isRecommended
        self.label = label
        self.breakdownAtMinimumPlayersToStart = breakdownAtMinimumPlayersToStart
        self.breakdownAtFullCapacity = breakdownAtFullCapacity
    }
}

// MARK: - Pricing Estimate

public struct PricingEstimate: Equatable {
    public let fieldId: String
    public let fieldName: String
    public let fieldCapacity: Int
    public let maxPlayers: Int
    public let fieldCostInCents: Int
    public let organizerFeeInCents: Int
    public let currency: String
    public let maxPricePerPlayerInCents: Int
    public let priceStepInCents: Int
    public let breakEvenPlayersRequired: Int
    public let recommendedOption: PricingOption
    public let pricingOptions: [PricingOption]
    public let selectedOption: PricingOption

    public init(
        fieldId: String,
        fieldName: String,
        fieldCapacity: Int,
        maxPlayers: Int,
        fieldCostInCents: Int,
        organizerFeeInCents: Int,
        currency: String,
        maxPricePerPlayerInCents: Int,
        priceStepInCents: Int,
        breakEvenPlayersRequired: Int,
        recommendedOption: PricingOption,
        pricingOptions: [PricingOption],
        selectedOption: PricingOption
    ) {
        self.fieldId = fieldId
        self.fieldName = fieldName
        self.fieldCapacity = fieldCapacity
        self.maxPlayers = maxPlayers
        self.fieldCostInCents = fieldCostInCents
        self.organizerFeeInCents = organizerFeeInCents
        self.currency = currency
        self.maxPricePerPlayerInCents = maxPricePerPlayerInCents
        self.priceStepInCents = priceStepInCents
        self.breakEvenPlayersRequired = breakEvenPlayersRequired
        self.recommendedOption = recommendedOption
        self.pricingOptions = pricingOptions
        self.selectedOption = selectedOption
    }
}
