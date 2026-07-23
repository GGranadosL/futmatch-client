import SwiftUI
import FMDesignSystem

// MARK: - MatchPricingView (loader)

/// Loads the pricing estimate on appear, then hands off to
/// `MatchPricingContentView` which owns the `@StateObject` view model so that
/// chip selection and custom-price recalculation drive live UI updates.
struct MatchPricingView: View {
    let fieldId: String
    let fieldName: String
    let maxPlayers: Int
    let fetchPricingEstimate: FetchPricingEstimateUseCaseProtocol
    let fetchCustomPricing: FetchCustomPricingUseCaseProtocol
    let isSaving: Bool
    let onConfirm: (PricingOption) -> Void

    @State private var estimate: PricingEstimate?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var hasStartedLoading = false

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text(L10n.Pricing.loading)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.background)
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Text(error)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.error)
                    Button(L10n.Common.retry) {
                        loadPricing()
                    }
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.primary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.background)
            } else if let estimate {
                MatchPricingContentView(
                    estimate: estimate,
                    fieldId: fieldId,
                    fieldName: fieldName,
                    maxPlayers: maxPlayers,
                    fetchCustom: fetchCustomPricing,
                    isSaving: isSaving,
                    onConfirm: onConfirm
                )
            }
        }
        .task {
            guard !hasStartedLoading else { return }
            hasStartedLoading = true
            loadPricing()
        }
    }

    private func loadPricing() {
        isLoading = true
        loadError = nil

        Task {
            do {
                estimate = try await fetchPricingEstimate.execute(fieldId: fieldId, maxPlayers: maxPlayers)
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - MatchPricingContentView (owns the observable view model)

private struct MatchPricingContentView: View {
    let fieldName: String
    let maxPlayers: Int
    let isSaving: Bool
    let onConfirm: (PricingOption) -> Void

    @StateObject private var viewModel: MatchPricingViewModel

    init(
        estimate: PricingEstimate,
        fieldId: String,
        fieldName: String,
        maxPlayers: Int,
        fetchCustom: FetchCustomPricingUseCaseProtocol,
        isSaving: Bool,
        onConfirm: @escaping (PricingOption) -> Void
    ) {
        self.fieldName = fieldName
        self.maxPlayers = maxPlayers
        self.isSaving = isSaving
        self.onConfirm = onConfirm
        _viewModel = StateObject(
            wrappedValue: MatchPricingViewModel(
                estimate: estimate,
                fieldId: fieldId,
                fetchCustom: fetchCustom
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoBar
                priceInputCard
                currentSelectionCard
                minimumCard
                breakdownCard
                Spacer(minLength: 80)
            }
            .padding(16)
        }
        .background(FMColors.background)
        .navigationTitle(L10n.Pricing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    Text(L10n.Pricing.title)
                        .font(FMTypography.titleSmall)
                        .foregroundColor(FMColors.onSurface)
                    Text("\(fieldName) · Máx. \(maxPlayers) jugadores")
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            FMStickyActionBar(
                title: L10n.Pricing.confirm,
                isLoading: isSaving,
                isEnabled: viewModel.selectedOption.isViable && !viewModel.isLoadingCustom && !isSaving,
                action: {
                    onConfirm(viewModel.selectedOption)
                }
            )
        }
    }

    private var infoBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Pricing.fieldCost)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(formatCurrency(viewModel.estimate.fieldCostInCents))
                    .font(FMTypography.titleSmall)
                    .foregroundColor(FMColors.onSurface)
            }
            Divider()
                .frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Pricing.organizerFee)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(formatCurrency(viewModel.estimate.organizerFeeInCents))
                    .font(FMTypography.titleSmall)
                    .foregroundColor(FMColors.onSurface)
            }
            Divider()
                .frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Pricing.breakEven)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                // Break-even depends on the price, so it tracks the selected
                // option (not the estimate-level constant).
                Text("\(viewModel.selectedOption.breakEvenPlayersRequired)")
                    .font(FMTypography.titleSmall)
                    .foregroundColor(FMColors.onSurface)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private var priceInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Pricing.pricePerPlayer ?? "Precio por jugador")
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurface)

            FMTextField(
                label: L10n.Pricing.pricePerPlayer ?? "Precio",
                text: Binding(
                    get: { viewModel.customPriceText },
                    set: { viewModel.onCustomPriceChanged($0) }
                ),
                keyboardType: .decimalPad
            )

            if viewModel.isLoadingCustom {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FMColors.primary)
                    Text(L10n.Pricing.recalculating)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            }

            if let error = viewModel.customError {
                Text(error)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.error)
            }

            chipGrid

            Text(L10n.Pricing.customHint)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private var chipGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.estimate.pricingOptions, id: \.id) { option in
                pricingChip(option: option, isSelected: viewModel.selectedOption.id == option.id) {
                    viewModel.selectChip(option)
                }
            }
        }
    }

    private func pricingChip(option: PricingOption, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(formatCurrency(option.pricePerPlayerInCents))
                    .font(FMTypography.titleSmall)
                    .foregroundColor(isSelected ? .white : FMColors.primary)
                if option.isRecommended {
                    Text(L10n.Pricing.recommended)
                        .font(FMTypography.labelSmall)
                        .foregroundColor(isSelected ? .white : FMColors.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 8).fill(FMColors.primary)
                    : RoundedRectangle(cornerRadius: 8).fill(FMColors.background)
            )
            .overlay(
                isSelected
                    ? nil
                    : RoundedRectangle(cornerRadius: 8).stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
    }

    private var currentSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Pricing.currentSelection)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurface)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatCurrency(viewModel.selectedOption.pricePerPlayerInCents))
                        .font(FMTypography.displayMedium)
                        .foregroundColor(FMColors.onSurface)
                    Text(L10n.Pricing.perPlayer)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if viewModel.selectedOption.isViable {
                        Label(L10n.Pricing.viable, systemImage: "checkmark.circle.fill")
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.secondary)
                    } else {
                        Label(L10n.Pricing.notViable, systemImage: "exclamationmark.triangle.fill")
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.error)
                    }
                    if viewModel.selectedOption.isRecommended {
                        Text(L10n.Pricing.recommended)
                            .font(FMTypography.labelSmall)
                            .foregroundColor(FMColors.primary)
                    }
                }
            }

            if !viewModel.selectedOption.isViable {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FMColors.error)
                    Text(L10n.Pricing.notViableHint)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.error)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(FMColors.errorContainer))
            }

            Divider()

            HStack(spacing: 16) {
                metricColumn(
                    title: L10n.Pricing.minToStart,
                    value: "\(viewModel.selectedOption.minimumPlayersToStart)"
                )
                metricColumn(
                    title: L10n.Pricing.profitMin,
                    value: formatCurrency(viewModel.selectedOption.estimatedProfitAtMinimumPlayersInCents)
                )
                metricColumn(
                    title: L10n.Pricing.profitFull,
                    value: formatCurrency(viewModel.selectedOption.estimatedProfitAtFullCapacityInCents)
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Text(value)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurface)
        }
        .frame(maxWidth: .infinity)
    }

    private var minimumCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(L10n.Pricing.minToStart)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurface)
            Text(L10n.Pricing.minToStartHint)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text("\(viewModel.selectedOption.minimumPlayersToStart)")
                .font(FMTypography.displayLarge)
                .foregroundColor(FMColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private var breakdownCard: some View {
        let breakdown = viewModel.selectedOption.breakdownAtFullCapacity
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Pricing.breakdownTitle(breakdown.players))
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurface)
            Text(L10n.Pricing.breakdownHint)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)

            breakdownRow(L10n.Pricing.grossRevenue, formatCurrency(breakdown.grossRevenueInCents), FMColors.onSurface)
            breakdownRow(L10n.Pricing.stripeFixed, "-\(formatCurrency(breakdown.stripeFixedFeeInCents))", FMColors.error)
            breakdownRow(L10n.Pricing.stripePct, "-\(formatCurrency(breakdown.stripePercentFeeInCents))", FMColors.error)
            breakdownRow(L10n.Pricing.totalStripe, "-\(formatCurrency(breakdown.totalStripeFeesInCents))", FMColors.error)
            breakdownRow(L10n.Pricing.netAfterStripe, formatCurrency(breakdown.netRevenueInCents), FMColors.onSurface)

            Divider().padding(.vertical, 4)

            breakdownRow(L10n.Pricing.fieldCost, "-\(formatCurrency(breakdown.fieldCostInCents))", FMColors.error)
            breakdownRow(L10n.Pricing.organizerFee, "-\(formatCurrency(breakdown.organizerFeeInCents))", FMColors.error)

            Divider().padding(.vertical, 4)

            breakdownRow(
                L10n.Pricing.estimatedProfit,
                formatCurrency(breakdown.estimatedProfitInCents),
                FMColors.primary,
                isBold: true
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private func breakdownRow(_ label: String, _ value: String, _ color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? FMTypography.labelMedium : FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(isBold ? FMTypography.labelMedium : FMTypography.bodySmall)
                .foregroundColor(color)
        }
    }

    private func formatCurrency(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.0f", dollars)
    }
}
