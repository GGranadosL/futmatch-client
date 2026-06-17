import SwiftUI
import FMDesignSystem

// MARK: - NewMatchView

struct NewMatchView: View {
    @StateObject private var viewModel: NewMatchViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCreated: (() -> Void)?

    // Tracks which dropdown is currently open — only one at a time.
    @State private var activeDropdownId: String? = nil

    // Focus tokens for text fields
    @State private var focusMinPlayers = false
    @State private var focusMaxPlayers = false
    @State private var focusPrice = false

    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var showPublishConfirmation = false

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> NewMatchViewModel, onCreated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onCreated = onCreated
    }

    // MARK: - Body

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

            if showPublishConfirmation {
                FMConfirmationAlert(
                    icon: "info.circle.fill",
                    title: L10n.NewMatch.Publish.title,
                    message: L10n.NewMatch.Publish.message,
                    primaryButtonTitle: L10n.NewMatch.Publish.confirm,
                    isLoading: viewModel.isSaving,
                    onPrimaryAction: { Task { await viewModel.save() } },
                    onSecondaryAction: { showPublishConfirmation = false }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.NewMatch.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: L10n.NewMatch.save,
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isValid,
                action: { showPublishConfirmation = true }
            )
        }
        .onChange(of: viewModel.createdMatch) { match in
            guard match != nil else { return }
            showPublishConfirmation = false
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onCreated?()
                dismiss()
            }
        }
        .onChange(of: viewModel.errorMessage) { error in
            guard let error = error else { return }
            showPublishConfirmation = false
            errorToastMessage = error
            showErrorToast = true
        }
        .fmToast(L10n.NewMatch.saved, isPresented: $showSuccessToast, style: .success)
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

            FMDateField(
                label: L10n.NewMatch.dateLabel,
                date: $viewModel.date,
                displayFormat: "dd/MMMM/yyyy"
            )

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
                .keyboardNavigation(
                    hasPrevious: false, hasNext: true,
                    onPrevious: {},
                    onNext: { focusMaxPlayers = true }
                )

                FMTextField(
                    label: L10n.NewMatch.Players.max,
                    text: $viewModel.maxPlayersText,
                    keyboardType: .numberPad,
                    trailingIcon: viewModel.maxPlayersText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                    onTrailingIconTap: { viewModel.maxPlayersText = "" }
                )
                .focused($focusMaxPlayers)
                .keyboardNavigation(
                    hasPrevious: true, hasNext: true,
                    onPrevious: { focusMinPlayers = true },
                    onNext: { focusPrice = true }
                )
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
            .keyboardNavigation(
                hasPrevious: true, hasNext: false,
                onPrevious: { focusMaxPlayers = true },
                onNext: {}
            )
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
                Text(title)
                    .font(FMTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(FMColors.onBackground)
                Text(description)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
    }

    private func timeField(label: String, selection: Binding<Date>) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(FMColors.secondary, lineWidth: 1)
                .frame(height: 56)

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

