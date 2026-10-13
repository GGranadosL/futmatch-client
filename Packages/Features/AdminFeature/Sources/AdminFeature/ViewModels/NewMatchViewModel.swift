import Foundation

@MainActor
public final class NewMatchViewModel: ObservableObject {

    // MARK: - Form Inputs

    @Published public var selectedField: FieldIdName?
    @Published public var date: Date = {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }()
    @Published public var startTime: Date?
    @Published public var endTime: Date?
    @Published public var maxPlayersText: String = ""
    @Published public var selectedOrganizer: Organizer?
    @Published public var selectedGender: MatchGender?
    @Published public var selectedLevel: MatchPlayerLevel?
    @Published public var selectedPricingOption: PricingOption?
    @Published public var selectedTeamA: TeamVisualCatalogItem?
    @Published public var selectedTeamB: TeamVisualCatalogItem?

    // MARK: - Submit / Load State

    @Published public private(set) var availableFields: [FieldIdName] = []
    @Published public private(set) var isLoadingFields: Bool = false
    @Published public private(set) var availableOrganizers: [Organizer] = []
    @Published public private(set) var isLoadingOrganizers: Bool = false
    @Published public private(set) var availableTeams: [TeamVisualCatalogItem] = []
    @Published public private(set) var isLoadingTeams: Bool = false
    /// Last catalog load error; the stored catalog and valid selections are kept.
    @Published public var teamsErrorMessage: String?
    @Published public private(set) var isSaving: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var createdMatch: AdminMatch?

    // MARK: - Dependencies

    private let createMatchUseCase: CreateMatchUseCaseProtocol
    private let fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol
    private let fetchOrganizersUseCase: FetchOrganizersUseCaseProtocol
    private let fetchTeamCatalogUseCase: FetchTeamCatalogUseCaseProtocol
    public let fetchPricingEstimateUseCase: FetchPricingEstimateUseCaseProtocol
    public let fetchCustomPricingUseCase: FetchCustomPricingUseCaseProtocol

    init(
        createMatchUseCase: CreateMatchUseCaseProtocol,
        fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol,
        fetchOrganizersUseCase: FetchOrganizersUseCaseProtocol,
        fetchTeamCatalogUseCase: FetchTeamCatalogUseCaseProtocol,
        fetchPricingEstimateUseCase: FetchPricingEstimateUseCaseProtocol,
        fetchCustomPricingUseCase: FetchCustomPricingUseCaseProtocol
    ) {
        self.createMatchUseCase = createMatchUseCase
        self.fetchFieldIdNamesUseCase = fetchFieldIdNamesUseCase
        self.fetchOrganizersUseCase = fetchOrganizersUseCase
        self.fetchTeamCatalogUseCase = fetchTeamCatalogUseCase
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

    // MARK: - Teams

    /// Team B can't repeat the identity picked for Team A.
    public var teamBOptions: [TeamVisualCatalogItem] {
        availableTeams.filter { $0.id != selectedTeamA?.id }
    }

    public func loadTeams(forceRefresh: Bool = false) async {
        isLoadingTeams = true
        teamsErrorMessage = nil
        do {
            let teams = try await fetchTeamCatalogUseCase.execute(forceRefresh: forceRefresh)
            availableTeams = teams
            selectedTeamA = teams.first { $0.id == selectedTeamA?.id } ?? selectedTeamA
            selectedTeamB = teams.first { $0.id == selectedTeamB?.id } ?? selectedTeamB
        } catch {
            teamsErrorMessage = error.localizedDescription
        }
        isLoadingTeams = false
    }

    /// Both identities are required and must differ.
    public var hasValidTeams: Bool {
        guard let a = selectedTeamA, let b = selectedTeamB else { return false }
        return a.id != b.id
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

    /// Non-nil when the selected date is earlier than today.
    /// Used to show an inline error and block "Continuar".
    public var dateError: String? {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard Calendar.current.startOfDay(for: date) < startOfToday else { return nil }
        return L10n.NewMatch.Date.pastError
    }

    public var isValid: Bool {
        selectedField != nil
            && maxPlayers != nil
            && selectedOrganizer != nil
            && selectedGender != nil
            && selectedLevel != nil
            && hasValidTeams
            && startTime != nil
            && endTime != nil
            && dateError == nil
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
            let option = selectedPricingOption,
            let startTime,
            let endTime
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
            playerLevel: level,
            teamAId: selectedTeamA?.id,
            teamBId: selectedTeamB?.id
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
