import Foundation

@MainActor
public final class NewMatchViewModel: ObservableObject {

    // MARK: - Form Inputs

    @Published public var selectedField: FieldIdName?
    @Published public var date: Date = Date()
    @Published public var startTime: Date = {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published public var endTime: Date = {
        Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @Published public var maxPlayersText: String = ""
    @Published public var selectedOrganizer: Organizer?
    @Published public var selectedGender: MatchGender?
    @Published public var selectedLevel: MatchPlayerLevel?
    @Published public var selectedPricingOption: PricingOption?

    // MARK: - Submit / Load State

    @Published public private(set) var availableFields: [FieldIdName] = []
    @Published public private(set) var isLoadingFields: Bool = false
    @Published public private(set) var availableOrganizers: [Organizer] = []
    @Published public private(set) var isLoadingOrganizers: Bool = false
    @Published public private(set) var isSaving: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var createdMatch: AdminMatch?

    // MARK: - Dependencies

    private let createMatchUseCase: CreateMatchUseCaseProtocol
    private let fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol
    private let fetchOrganizersUseCase: FetchOrganizersUseCaseProtocol
    public let fetchPricingEstimateUseCase: FetchPricingEstimateUseCaseProtocol
    public let fetchCustomPricingUseCase: FetchCustomPricingUseCaseProtocol

    init(
        createMatchUseCase: CreateMatchUseCaseProtocol,
        fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol,
        fetchOrganizersUseCase: FetchOrganizersUseCaseProtocol,
        fetchPricingEstimateUseCase: FetchPricingEstimateUseCaseProtocol,
        fetchCustomPricingUseCase: FetchCustomPricingUseCaseProtocol
    ) {
        self.createMatchUseCase = createMatchUseCase
        self.fetchFieldIdNamesUseCase = fetchFieldIdNamesUseCase
        self.fetchOrganizersUseCase = fetchOrganizersUseCase
        self.fetchPricingEstimateUseCase = fetchPricingEstimateUseCase
        self.fetchCustomPricingUseCase = fetchCustomPricingUseCase
    }

    // MARK: - Load Fields & Organizers

    public func loadFields() async {
        isLoadingFields = true
        availableFields = (try? await fetchFieldIdNamesUseCase.execute()) ?? []
        isLoadingFields = false
    }

    public func loadOrganizers() async {
        isLoadingOrganizers = true
        availableOrganizers = (try? await fetchOrganizersUseCase.execute()) ?? []
        isLoadingOrganizers = false
    }

    // MARK: - Validation

    public var maxPlayers: Int? {
        guard let v = Int(maxPlayersText.filter(\.isNumber)), v > 0 else { return nil }
        if let field = selectedField, field.maxPlayersAllowed > 0, v > field.maxPlayersAllowed {
            return nil
        }
        return v
    }

    /// Non-nil when the user typed a max-players value outside the field's allowed range.
    /// Used to show an inline error and block "Continuar" even though `maxPlayers` is nil.
    public var maxPlayersError: String? {
        guard let field = selectedField, field.maxPlayersAllowed > 0 else { return nil }
        guard let typed = Int(maxPlayersText.filter(\.isNumber)), typed > 0 else { return nil }
        guard typed > field.maxPlayersAllowed else { return nil }
        return L10n.NewMatch.Players.exceedsFieldMax(field.maxPlayersAllowed)
    }

    public var isValid: Bool {
        selectedField != nil
            && maxPlayers != nil
            && selectedOrganizer != nil
            && selectedGender != nil
            && selectedLevel != nil
    }

    // MARK: - Save

    public func save() async {
        guard
            isValid,
            let field = selectedField,
            let organizer = selectedOrganizer,
            let maxPlayers,
            let gender = selectedGender,
            let level = selectedLevel,
            let option = selectedPricingOption
        else { return }

        let params = CreateMatchParams(
            fieldId: field.id,
            fieldName: field.name,
            organizerId: organizer.id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            minPlayers: option.minimumPlayersToStart,
            maxPlayers: maxPlayers,
            priceInCents: option.pricePerPlayerInCents,
            gender: gender,
            playerLevel: level
        )

        isSaving = true
        errorMessage = nil
        do {
            createdMatch = try await createMatchUseCase.execute(params)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
