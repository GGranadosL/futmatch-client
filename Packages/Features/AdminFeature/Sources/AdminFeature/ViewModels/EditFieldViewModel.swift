import Foundation
import NetworkFramework

/// Pre-fills the field form with existing data and calls `PATCH /fields/{id}`.
/// Mirrors `NewFieldViewModel` but operates on an existing `AdminFieldItem`.
@MainActor
public final class EditFieldViewModel: ObservableObject {

    // MARK: - Form Inputs (pre-filled from the existing field)

    @Published public var name: String
    @Published public var capacityText: String
    @Published public var priceText: String
    @Published public var hasParking: Bool
    @Published public var description: String
    @Published public var rules: [FieldRuleDraft]
    @Published public var extraInfo: String
    @Published public var fieldType: FieldType?
    @Published public var footwearType: FootwearType?

    // MARK: - Submit State

    @Published public private(set) var isSaving: Bool = false
    @Published public var errorMessage: String?
    /// Set on a successful update to the freshly-edited item, so the detail/list
    /// screens can refresh their UI without waiting for a network round-trip.
    @Published public private(set) var updatedField: AdminFieldItem?

    private let originalField: AdminFieldItem
    private let updateFieldUseCase: UpdateFieldUseCaseProtocol

    public static let nameMaxLength = NewFieldViewModel.nameMaxLength

    // MARK: - Init

    public init(field: AdminFieldItem, updateFieldUseCase: UpdateFieldUseCaseProtocol) {
        self.originalField = field
        self.updateFieldUseCase = updateFieldUseCase

        // Pre-fill from existing field
        self.name         = field.name
        self.capacityText = field.capacity > 0 ? "\(field.capacity)" : ""
        self.priceText    = field.priceInCents > 0 ? String(format: "$%.2f", Double(field.priceInCents) / 100.0) : ""
        self.hasParking   = field.hasParking
        self.description  = field.description ?? ""
        // Parse the stored "1. …\n2. …" string back into editable rows.
        let parsedRules = FieldRulesFormatter.parse(field.rules ?? "")
        self.rules        = parsedRules.isEmpty ? [FieldRuleDraft()] : parsedRules.map { FieldRuleDraft(text: $0) }
        self.extraInfo    = field.extraInfo ?? ""
        self.fieldType    = field.fieldType
        self.footwearType = field.footwearType
    }

    // MARK: - Validation (identical to NewFieldViewModel)

    private var trimmedName:        String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Rules joined into the backend `"1. …\n2. …"` format, ignoring blank rows.
    private var formattedRules: String { FieldRulesFormatter.format(rules.map(\.text)) }
    private var hasRules: Bool { !formattedRules.isEmpty }

    public var priceInCents: Int? {
        let cleaned = priceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(cleaned), amount > 0 else { return nil }
        return Int((amount * 100).rounded())
    }

    public var capacity: Int? {
        guard let v = Int(capacityText.filter(\.isNumber)), v > 0 else { return nil }
        return v
    }

    public var nameError: String? {
        trimmedName.count > Self.nameMaxLength ? "Máximo \(Self.nameMaxLength) caracteres" : nil
    }

    public var isValid: Bool {
        !trimmedName.isEmpty
            && trimmedName.count <= Self.nameMaxLength
            && capacity != nil
            && priceInCents != nil
            && !trimmedDescription.isEmpty
            && hasRules
    }

    // MARK: - Format

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
        guard isValid, let capacity, let priceInCents else { return }
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
            try await updateFieldUseCase.execute(fieldId: originalField.id, params)
            // Build the updated item locally (the edit form leaves images/address
            // untouched, so they carry over from the original) so the detail and
            // list screens reflect the change immediately.
            updatedField = AdminFieldItem(
                id: originalField.id,
                name: trimmedName,
                priceInCents: priceInCents,
                capacity: capacity,
                imageUrl: originalField.imageUrl,
                images: originalField.images,
                address: originalField.address,
                description: trimmedDescription,
                rules: formattedRules,
                extraInfo: trimmedExtra.isEmpty ? nil : trimmedExtra,
                hasParking: hasParking,
                fieldType: fieldType,
                footwearType: footwearType
            )
        } catch {
            errorMessage = error.apiErrorMessage ?? error.localizedDescription
        }
        isSaving = false
    }
}
