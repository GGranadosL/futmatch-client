import Foundation
import NetworkFramework

@MainActor
public final class NewFieldViewModel: ObservableObject {

    // MARK: - Form Inputs

    @Published public var name: String = ""
    @Published public var capacityText: String = ""
    @Published public var priceText: String = ""
    @Published public var hasParking: Bool = false
    @Published public var description: String = ""
    @Published public var rules: [FieldRuleDraft] = [FieldRuleDraft()]
    @Published public var extraInfo: String = ""
    @Published public var fieldType: FieldType?
    @Published public var footwearType: FootwearType?

    // MARK: - Submit State

    @Published public private(set) var isSaving: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var createdField: Field?

    private let createFieldUseCase: CreateFieldUseCaseProtocol

    /// Backend `name` limit.
    public static let nameMaxLength = 30

    public init(createFieldUseCase: CreateFieldUseCaseProtocol) {
        self.createFieldUseCase = createFieldUseCase
    }

    // MARK: - Validation

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Rules joined into the backend `"1. …\n2. …"` format, ignoring blank rows.
    private var formattedRules: String { FieldRulesFormatter.format(rules.map(\.text)) }
    private var hasRules: Bool { !formattedRules.isEmpty }

    /// Price in cents parsed from the text field, or nil when invalid/empty.
    /// Accepts "$500.00", "500,00", "500" etc.
    public var priceInCents: Int? {
        let cleaned = priceText
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        return Int((amount * 100).rounded())
    }

    public var capacity: Int? {
        guard let value = Int(capacityText.filter(\.isNumber)), value > 0 else { return nil }
        return value
    }

    /// Inline error for the name field (length over the backend limit).
    public var nameError: String? {
        trimmedName.count > Self.nameMaxLength ? "Máximo \(Self.nameMaxLength) caracteres" : nil
    }

    /// True when every required field passes validation.
    public var isValid: Bool {
        !trimmedName.isEmpty
            && trimmedName.count <= Self.nameMaxLength
            && capacity != nil
            && priceInCents != nil
            && !trimmedDescription.isEmpty
            && hasRules
    }

    // MARK: - Price Formatting

    /// Call when the price field loses focus. Parses whatever the user typed
    /// ("500", "500.5", "500.00") and reformats it as "$500.00".
    public func formatPriceOnBlur() {
        let cleaned = priceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let amount = Double(cleaned), amount > 0 else { return }
        priceText = String(format: "$%.2f", amount)
    }

    // MARK: - Actions

    /// Submits the form. On success sets `createdField`; on failure sets `errorMessage`.
    public func save() async {
        guard
            isValid,
            let capacity,
            let priceInCents
        else { return }

        let trimmedExtra = extraInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = CreateFieldParams(
            name: trimmedName,
            priceInCents: priceInCents,
            capacity: capacity,
            description: trimmedDescription,
            rules: formattedRules,
            footwearType: footwearType,
            fieldType: fieldType,
            hasParking: hasParking,
            extraInfo: trimmedExtra.isEmpty ? nil : trimmedExtra
        )

        isSaving = true
        errorMessage = nil
        do {
            createdField = try await createFieldUseCase.execute(params)
        } catch {
            errorMessage = error.apiErrorMessage ?? error.localizedDescription
        }
        isSaving = false
    }
}
