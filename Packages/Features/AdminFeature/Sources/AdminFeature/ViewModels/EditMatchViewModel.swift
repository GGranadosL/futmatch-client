import Foundation

@MainActor
final class EditMatchViewModel: ObservableObject {

    // MARK: - Form Inputs (pre-filled from the existing match)

    @Published var selectedField: FieldIdName?
    @Published var date: Date
    @Published var startTime: Date
    @Published var endTime: Date
    @Published var minPlayersText: String
    @Published var maxPlayersText: String
    @Published var priceText: String
    @Published var selectedGender: MatchGender?
    @Published var selectedLevel: MatchPlayerLevel?

    // MARK: - Submit / Load State

    @Published private(set) var availableFields: [FieldIdName] = []
    @Published private(set) var isLoadingFields = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var updatedMatch: AdminMatch?

    // MARK: - Dependencies

    private let originalMatchId: String
    private let originalFieldId: String
    private let updateUseCase: UpdateAdminMatchUseCaseProtocol
    private let fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol

    init(
        match: AdminMatch,
        updateUseCase: UpdateAdminMatchUseCaseProtocol,
        fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol
    ) {
        self.originalMatchId = match.id
        self.originalFieldId = match.fieldId

        self.date = match.startDate
        self.startTime = match.startDate
        self.endTime = match.endDate
        self.minPlayersText = match.minPlayers > 0 ? String(match.minPlayers) : ""
        self.maxPlayersText = match.spotsTotal > 0 ? String(match.spotsTotal) : ""
        self.selectedGender = match.gender
        self.selectedLevel = match.playerLevel

        let raw = match.price
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " MXN", with: "")
            .trimmingCharacters(in: .whitespaces)
        self.priceText = raw

        self.updateUseCase = updateUseCase
        self.fetchFieldIdNamesUseCase = fetchFieldIdNamesUseCase
    }

    // MARK: - Load Fields

    func loadFields() async {
        isLoadingFields = true
        availableFields = (try? await fetchFieldIdNamesUseCase.execute()) ?? []
        if selectedField == nil {
            selectedField = availableFields.first { $0.id == originalFieldId }
        }
        isLoadingFields = false
    }

    // MARK: - Validation

    var minPlayers: Int? {
        guard let v = Int(minPlayersText.filter(\.isNumber)), v > 0 else { return nil }
        return v
    }

    var maxPlayers: Int? {
        guard let v = Int(maxPlayersText.filter(\.isNumber)), v > 0 else { return nil }
        return v
    }

    var priceInCents: Int? {
        let cleaned = priceText
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        return Int((amount * 100).rounded())
    }

    var isValid: Bool {
        guard let minPlayers, let maxPlayers else { return false }
        return selectedField != nil
            && minPlayers < maxPlayers
            && priceInCents != nil
            && selectedGender != nil
            && selectedLevel != nil
    }

    // MARK: - Price Formatting

    func formatPriceOnBlur() {
        let cleaned = priceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let amount = Double(cleaned), amount > 0 else { return }
        priceText = String(format: "$%.2f", amount)
    }

    // MARK: - Save

    func save() async {
        guard
            isValid,
            let field = selectedField,
            let minPlayers,
            let maxPlayers,
            let priceInCents,
            let gender = selectedGender,
            let level = selectedLevel
        else { return }

        let params = UpdateMatchParams(
            matchId: originalMatchId,
            fieldId: field.id,
            fieldName: field.name,
            date: date,
            startTime: startTime,
            endTime: endTime,
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            priceInCents: priceInCents,
            gender: gender,
            playerLevel: level
        )

        isSaving = true
        errorMessage = nil
        do {
            updatedMatch = try await updateUseCase.execute(params)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
