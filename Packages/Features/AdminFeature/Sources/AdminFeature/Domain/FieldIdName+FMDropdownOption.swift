import FMDesignSystem

extension FieldIdName: FMDropdownOption {
    public var displayName: String { name }
}

extension MatchGender: FMDropdownOption {}
extension MatchPlayerLevel: FMDropdownOption {}

extension Organizer: FMDropdownOption {
    public var displayName: String { fullName }
}
