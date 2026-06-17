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
    @Published public var minPlayersText: String = ""
    @Published public var maxPlayersText: String = ""
    @Published public var priceText: String = ""
    @Published public var selectedGender: MatchGender?
    @Published public var selectedLevel: MatchPlayerLevel?

    // MARK: - Submit / Load State

    @Published public private(set) var availableFields: [FieldIdName] = []
    @Published public private(set) var isLoadingFields: Bool = false
    @Published public private(set) var isSaving: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var createdMatch: AdminMatch?

    // MARK: - Dependencies

    private let createMatchUseCase: CreateMatchUseCaseProtocol
    private let fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol

    init(
        createMatchUseCase: CreateMatchUseCaseProtocol,
        fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol
    ) {
        self.createMatchUseCase = createMatchUseCase
        self.fetchFieldIdNamesUseCase = fetchFieldIdNamesUseCase
    }

    // MARK: - Load Fields

    public func loadFields() async {
        isLoadingFields = true
        availableFields = (try? await fetchFieldIdNamesUseCase.execute()) ?? []
        isLoadingFields = false
    }

    // MARK: - Validation

    public var minPlayers: Int? {
        guard let v = Int(minPlayersText.filter(\.isNumber)), v > 0 else { return nil }
        return v
    }

    public var maxPlayers: Int? {
        guard let v = Int(maxPlayersText.filter(\.isNumber)), v > 0 else { return nil }
        return v
    }

    public var priceInCents: Int? {
        let cleaned = priceText
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        return Int((amount * 100).rounded())
    }

    public var isValid: Bool {
        guard let minPlayers = minPlayers,
              let maxPlayers = maxPlayers else { return false }
        return selectedField != nil
            && minPlayers < maxPlayers
            && priceInCents != nil
            && selectedGender != nil
            && selectedLevel != nil
    }

    // MARK: - Price Formatting

    public func formatPriceOnBlur() {
        let cleaned = priceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let amount = Double(cleaned), amount > 0 else { return }
        priceText = String(format: "$%.2f", amount)
    }

    // MARK: - Save

    public func save() async {
        guard
            isValid,
            let field = selectedField,
            let minPlayers,
            let maxPlayers,
            let priceInCents,
            let gender = selectedGender,
            let level = selectedLevel
        else { return }

        let params = CreateMatchParams(
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
            createdMatch = try await createMatchUseCase.execute(params)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
