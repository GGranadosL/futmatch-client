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
    @Published var selectedTeamA: TeamVisualCatalogItem?
    @Published var selectedTeamB: TeamVisualCatalogItem?

    // MARK: - Submit / Load State

    @Published private(set) var availableFields: [FieldIdName] = []
    @Published private(set) var isLoadingFields = false
    @Published private(set) var availableTeams: [TeamVisualCatalogItem] = []
    @Published private(set) var isLoadingTeams = false
    @Published var teamsErrorMessage: String?
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var updatedMatch: AdminMatch?

    // MARK: - Dependencies

    private let originalMatchId: String
    private let originalFieldId: String
    /// The form exactly as it was loaded, so Save can stay disabled until something differs.
    private let originalForm: FormSnapshot
    private let updateUseCase: UpdateAdminMatchUseCaseProtocol
    private let fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol
    private let fetchTeamCatalogUseCase: FetchTeamCatalogUseCaseProtocol?
    /// Snapshot stored on the match; the match carries no catalog ids, so it is
    /// matched against the catalog by name + color to preselect the dropdowns.
    private let originalTeamVisuals: AdminMatchTeamVisuals?
    /// Catalog ids the form started with, known once the catalog resolves them.
    private var originalTeamIds: (a: String, b: String)?

    init(
        match: AdminMatch,
        updateUseCase: UpdateAdminMatchUseCaseProtocol,
        fetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol,
        fetchTeamCatalogUseCase: FetchTeamCatalogUseCaseProtocol? = nil
    ) {
        self.originalTeamVisuals = match.teamVisuals
        self.fetchTeamCatalogUseCase = fetchTeamCatalogUseCase
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

        self.originalForm = FormSnapshot(
            fieldId: match.fieldId,
            day: Calendar.current.startOfDay(for: match.startDate),
            startMinuteOfDay: Self.minuteOfDay(match.startDate),
            endMinuteOfDay: Self.minuteOfDay(match.endDate),
            minPlayers: match.minPlayers > 0 ? match.minPlayers : nil,
            maxPlayers: match.spotsTotal > 0 ? match.spotsTotal : nil,
            priceInCents: Self.parsePriceInCents(raw),
            gender: match.gender,
            playerLevel: match.playerLevel
        )
    }

    // MARK: - Teams

    var supportsTeamSelection: Bool { fetchTeamCatalogUseCase != nil }

    /// Team B can't repeat the identity picked for Team A.
    var teamBOptions: [TeamVisualCatalogItem] {
        availableTeams.filter { $0.id != selectedTeamA?.id }
    }

    func loadTeams(forceRefresh: Bool = false) async {
        guard let fetchTeamCatalogUseCase else { return }
        isLoadingTeams = true
        teamsErrorMessage = nil
        do {
            let teams = try await fetchTeamCatalogUseCase.execute(forceRefresh: forceRefresh)
            availableTeams = teams
            if originalTeamIds == nil, let visuals = originalTeamVisuals,
               let a = teams.first(where: { $0.matches(visuals.teamA) }),
               let b = teams.first(where: { $0.matches(visuals.teamB) }), a.id != b.id {
                originalTeamIds = (a.id, b.id)
                if selectedTeamA == nil { selectedTeamA = a }
                if selectedTeamB == nil { selectedTeamB = b }
            }
            selectedTeamA = teams.first { $0.id == selectedTeamA?.id } ?? selectedTeamA
            selectedTeamB = teams.first { $0.id == selectedTeamB?.id } ?? selectedTeamB
        } catch {
            teamsErrorMessage = error.localizedDescription
        }
        isLoadingTeams = false
    }

    /// The pair differs from what the form started with. Unknown (false) until the
    /// catalog resolved the original ids, so a slow load never reads as an edit.
    private var teamsChanged: Bool {
        guard let original = originalTeamIds else {
            // Match had no usable snapshot: any complete selection is a change.
            return originalTeamVisuals == nil && selectedTeamA != nil && selectedTeamB != nil
        }
        return selectedTeamA?.id != original.a || selectedTeamB?.id != original.b
    }

    /// Teams are optional on edit (omitting keeps the snapshot) but are sent as a pair.
    private var hasValidTeams: Bool {
        switch (selectedTeamA, selectedTeamB) {
        case (nil, nil): return true
        case let (a?, b?): return a.id != b.id
        default: return false
        }
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

    var priceInCents: Int? { Self.parsePriceInCents(priceText) }

    private static func parsePriceInCents(_ text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        return Int((amount * 100).rounded())
    }

    /// Compared field by field rather than by raw `Date`/`String` equality: the date
    /// picker hands back a full timestamp, so re-picking the same day or retyping
    /// "170" as "$170.00" would otherwise register as an edit.
    private struct FormSnapshot: Equatable {
        let fieldId: String
        let day: Date
        let startMinuteOfDay: Int
        let endMinuteOfDay: Int
        let minPlayers: Int?
        let maxPlayers: Int?
        let priceInCents: Int?
        let gender: MatchGender?
        let playerLevel: MatchPlayerLevel?
    }

    private static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var currentForm: FormSnapshot {
        FormSnapshot(
            // `selectedField` is nil until `loadFields()` resolves it, which would
            // otherwise read as "the field changed" while the screen is still loading.
            fieldId: selectedField?.id ?? originalFieldId,
            day: Calendar.current.startOfDay(for: date),
            startMinuteOfDay: Self.minuteOfDay(startTime),
            endMinuteOfDay: Self.minuteOfDay(endTime),
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            priceInCents: priceInCents,
            gender: selectedGender,
            playerLevel: selectedLevel
        )
    }

    /// False while the form still matches the match it was loaded from — saving then would
    /// be a no-op round trip.
    var hasChanges: Bool { currentForm != originalForm || teamsChanged }

    var isValid: Bool {
        guard let minPlayers, let maxPlayers else { return false }
        return selectedField != nil
            // `<=`, not `<`: a match that only starts at full capacity (min == max) is
            // legitimate, and creation allows it — with `<` those matches could never be
            // edited again, because Save stayed disabled no matter what was changed.
            && minPlayers <= maxPlayers
            && priceInCents != nil
            && selectedGender != nil
            && selectedLevel != nil
            && hasValidTeams
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
            playerLevel: level,
            teamAId: teamsChanged ? selectedTeamA?.id : nil,
            teamBId: teamsChanged ? selectedTeamB?.id : nil
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
