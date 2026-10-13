import SwiftUI
import FMDesignSystem

struct EditMatchView: View {
    @StateObject private var viewModel: EditMatchViewModel
    @Environment(\.dismiss) private var dismiss

    private let onUpdated: (() -> Void)?
    private let navSubtitle: String

    @State private var activeDropdownId: String? = nil
    @State private var focusMinPlayers = false
    @State private var focusMaxPlayers = false
    @State private var focusPrice = false
    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var showConfirmation = false

    init(viewModel: @autoclosure @escaping () -> EditMatchViewModel, subtitle: String = "admin", onUpdated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.navSubtitle = subtitle
        self.onUpdated = onUpdated
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    locationSection
                    dateTimeSection
                    playersSection
                    costSection
                    genderSection
                    levelSection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .background(FMColors.background.ignoresSafeArea())

            if showConfirmation {
                FMConfirmationAlert(
                    icon: "info.circle.fill",
                    title: L10n.EditMatch.confirmTitle,
                    message: L10n.EditMatch.confirmMessage,
                    primaryButtonTitle: L10n.EditMatch.confirmButton,
                    isLoading: viewModel.isSaving,
                    onPrimaryAction: { Task { await viewModel.save() } },
                    onSecondaryAction: { showConfirmation = false }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                AdminNavTitle(title: L10n.EditMatch.title, subtitle: navSubtitle)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: L10n.EditMatch.saveChanges,
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isValid && viewModel.hasChanges,
                action: { showConfirmation = true }
            )
        }
        .onChange(of: viewModel.updatedMatch) { match in
            guard match != nil else { return }
            showConfirmation = false
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onUpdated?()
                dismiss()
            }
        }
        .onChange(of: viewModel.errorMessage) { error in
            guard let error else { return }
            showConfirmation = false
            errorToastMessage = error
            showErrorToast = true
        }
        .fmToast(L10n.EditMatch.successMessage, isPresented: $showSuccessToast, style: .success)
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
        .task { await viewModel.loadFields() }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "mappin.circle.fill", title: L10n.NewMatch.Section.Location.title, description: L10n.NewMatch.Section.Location.description)

            if viewModel.isLoadingFields {
                HStack(spacing: 8) {
                    ProgressView().tint(FMColors.primary)
                    Text(L10n.NewMatch.loadingFields)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            } else {
                FMDropdownField(
                    label: L10n.NewMatch.fieldLabel,
                    dropdownId: "field",
                    selectedOption: $viewModel.selectedField,
                    activeDropdownId: $activeDropdownId,
                    options: viewModel.availableFields
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        .zIndex(1)
        .padding(.bottom, 8)
    }

    // MARK: - Date & Time Section

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar.circle.fill", title: L10n.NewMatch.Section.DateTime.title, description: L10n.NewMatch.Section.DateTime.description)

            FMDateField(label: L10n.NewMatch.dateLabel, date: $viewModel.date, displayFormat: "dd/MMMM/yyyy")

            HStack(spacing: 12) {
                timeField(label: L10n.NewMatch.startTimeLabel, selection: $viewModel.startTime)
                timeField(label: L10n.NewMatch.endTimeLabel, selection: $viewModel.endTime)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Players Section

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "person.2.circle.fill", title: L10n.NewMatch.Section.Players.title, description: L10n.NewMatch.Section.Players.description)

            HStack(alignment: .top, spacing: 12) {
                FMTextField(
                    label: L10n.NewMatch.Players.min,
                    text: $viewModel.minPlayersText,
                    keyboardType: .numberPad,
                    trailingIcon: viewModel.minPlayersText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                    onTrailingIconTap: { viewModel.minPlayersText = "" }
                )
                .focused($focusMinPlayers)
                .keyboardNavigation(hasPrevious: false, hasNext: true, onPrevious: {}, onNext: { focusMaxPlayers = true })

                FMTextField(
                    label: L10n.NewMatch.Players.max,
                    text: $viewModel.maxPlayersText,
                    keyboardType: .numberPad,
                    trailingIcon: viewModel.maxPlayersText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                    onTrailingIconTap: { viewModel.maxPlayersText = "" }
                )
                .focused($focusMaxPlayers)
                .keyboardNavigation(hasPrevious: true, hasNext: true, onPrevious: { focusMinPlayers = true }, onNext: { focusPrice = true })
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Cost Section

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "dollarsign.circle.fill", title: L10n.NewMatch.Section.Cost.title, description: L10n.NewMatch.Section.Cost.description)

            FMTextField(
                label: L10n.NewMatch.priceLabel,
                text: $viewModel.priceText,
                keyboardType: .decimalPad,
                trailingIcon: viewModel.priceText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                onTrailingIconTap: { viewModel.priceText = "" }
            )
            .focused($focusPrice)
            .keyboardNavigation(hasPrevious: true, hasNext: false, onPrevious: { focusMaxPlayers = true }, onNext: {})
            .onChange(of: focusPrice) { isFocused in
                if !isFocused { viewModel.formatPriceOnBlur() }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Gender Section

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "person.fill", title: L10n.NewMatch.Section.Gender.title, description: L10n.NewMatch.Section.Gender.description)

            FMDropdownField(
                label: L10n.NewMatch.genderLabel,
                dropdownId: "gender",
                selectedOption: $viewModel.selectedGender,
                activeDropdownId: $activeDropdownId,
                options: MatchGender.allCases,
                opensUpward: true
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Level Section

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "star.circle.fill", title: L10n.NewMatch.Section.Level.title, description: L10n.NewMatch.Section.Level.description)

            FMDropdownField(
                label: L10n.NewMatch.levelLabel,
                dropdownId: "level",
                selectedOption: $viewModel.selectedLevel,
                activeDropdownId: $activeDropdownId,
                options: MatchPlayerLevel.allCases,
                opensUpward: true
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(FMColors.primary)
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(FMTypography.titleMedium).fontWeight(.semibold).foregroundColor(FMColors.onBackground)
                Text(description).font(FMTypography.bodySmall).foregroundColor(FMColors.onSurfaceVariant)
            }
        }
    }

    private func timeField(label: String, selection: Binding<Date>) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8).stroke(FMColors.secondary, lineWidth: 1).frame(height: 56)
            Text(label)
                .font(FMTypography.label)
                .foregroundColor(FMColors.secondary)
                .background(FMColors.background)
                .padding(.horizontal, 4)
                .offset(x: 12, y: -28)
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .accentColor(FMColors.primary)
                .padding(.horizontal, 16)
                .frame(height: 56)
        }
        .frame(maxWidth: .infinity)
    }
}
