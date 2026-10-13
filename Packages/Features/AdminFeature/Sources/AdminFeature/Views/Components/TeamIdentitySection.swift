import SwiftUI
import FMDesignSystem

/// "Equipos" card shared by the create and edit match forms: two dropdowns with a
/// color dot, where Team B excludes whatever Team A selected.
struct TeamIdentitySection: View {
    @Binding var selectedTeamA: TeamVisualCatalogItem?
    @Binding var selectedTeamB: TeamVisualCatalogItem?
    @Binding var activeDropdownId: String?
    let teamAOptions: [TeamVisualCatalogItem]
    let teamBOptions: [TeamVisualCatalogItem]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading && teamAOptions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.NewMatch.loadingTeams)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                .padding(.vertical, 8)
            } else {
                FMDropdownField(
                    label: L10n.NewMatch.teamALabel,
                    dropdownId: "teamA",
                    selectedOption: $selectedTeamA,
                    activeDropdownId: $activeDropdownId,
                    options: teamAOptions
                )
                .zIndex(2)

                FMDropdownField(
                    label: L10n.NewMatch.teamBLabel,
                    dropdownId: "teamB",
                    selectedOption: $selectedTeamB,
                    activeDropdownId: $activeDropdownId,
                    options: teamBOptions
                )
                .zIndex(1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.error)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(FMColors.primary)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.NewMatch.Section.Teams.title)
                    .font(FMTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(FMColors.onBackground)
                Text(L10n.NewMatch.Section.Teams.description)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
    }
}
