import SwiftUI
import FMDesignSystem

// MARK: - NewMatchView

struct NewMatchView: View {
    @StateObject private var viewModel: NewMatchViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCreated: (() -> Void)?
    private let navSubtitle: String

    // Tracks which dropdown is currently open — only one at a time.
    @State private var activeDropdownId: String? = nil

    // Focus tokens for text fields
    @State private var focusMaxPlayers = false

    // Navigation
    @State private var showPricingScreen = false

    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> NewMatchViewModel, subtitle: String = "admin", onCreated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.navSubtitle = subtitle
        self.onCreated = onCreated
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                locationSection
                dateTimeSection
                playersSection
                genderSection
                levelSection
                organizerSection

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
        .navigationDestination(isPresented: $showPricingScreen) {
            if let field = viewModel.selectedField, let maxPlayers = viewModel.maxPlayers {
                MatchPricingView(
                    fieldId: field.id,
                    fieldName: field.name,
                    maxPlayers: maxPlayers,
                    fetchPricingEstimate: viewModel.fetchPricingEstimateUseCase,
                    fetchCustomPricing: viewModel.fetchCustomPricingUseCase,
                    isSaving: viewModel.isSaving
                ) { option in
                    viewModel.selectedPricingOption = option
                    Task {
                        await viewModel.save()
                        if viewModel.createdMatch != nil {
                            showPricingScreen = false
                            showSuccessToast = true
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            onCreated?()
                            dismiss()
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.errorMessage) { error in
            guard let error = error else { return }
            errorToastMessage = error
            showErrorToast = true
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                AdminNavTitle(title: L10n.NewMatch.title, subtitle: navSubtitle)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: "Continuar",
                isLoading: false,
                isEnabled: viewModel.isValid,
                action: { showPricingScreen = true }
            )
        }
        .fmToast(L10n.NewMatch.saved, isPresented: $showSuccessToast, style: .success)
        .fmToast(errorToastMessage, isPresented: $showErrorToast, style: .error)
        .task { await viewModel.loadFields() }
        .task { await viewModel.loadOrganizers() }
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
                displayFormat: "dd/MMMM/yyyy",
                errorMessage: viewModel.dateError
            )

            HStack(spacing: 12) {
                timeFieldButton(label: L10n.NewMatch.startTimeLabel, dropdownId: "startTime")
                timeFieldButton(label: L10n.NewMatch.endTimeLabel, dropdownId: "endTime")
            }

            if let dropdownId = activeDropdownId, dropdownId == "startTime" || dropdownId == "endTime" {
                timePickerPanel(dropdownId: dropdownId)
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

            FMTextField(
                label: L10n.NewMatch.Players.max,
                text: $viewModel.maxPlayersText,
                keyboardType: .numberPad,
                trailingIcon: viewModel.maxPlayersText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                onTrailingIconTap: { viewModel.maxPlayersText = "" }
            )
            .focused($focusMaxPlayers)
            .keyboardNavigation(
                hasPrevious: false, hasNext: false,
                onPrevious: {},
                onNext: {}
            )

            if let error = viewModel.maxPlayersError {
                Text(error)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.error)
            } else if let field = viewModel.selectedField, field.maxPlayersAllowed > 0 {
                Text(L10n.NewMatch.Players.fieldMax(field.maxPlayersAllowed))
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }

    // MARK: - Organizer Section

    private var organizerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "person.circle.fill", title: L10n.NewMatch.Section.Organizer.title, description: L10n.NewMatch.Section.Organizer.description)

            if viewModel.isLoadingOrganizers {
                HStack(spacing: 8) {
                    ProgressView().tint(FMColors.primary)
                    Text(L10n.NewMatch.loadingOrganizers)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            } else {
                FMDropdownField(
                    label: L10n.NewMatch.organizerLabel,
                    dropdownId: "organizer",
                    selectedOption: $viewModel.selectedOrganizer,
                    activeDropdownId: $activeDropdownId,
                    options: viewModel.availableOrganizers,
                    opensUpward: true
                )
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

    private func timeBinding(for dropdownId: String) -> Binding<Date?> {
        dropdownId == "startTime" ? $viewModel.startTime : $viewModel.endTime
    }

    private func defaultTimeSeed(for dropdownId: String) -> Date {
        let hour = dropdownId == "startTime" ? 20 : 22
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func timeFieldButton(label: String, dropdownId: String) -> some View {
        let selection = timeBinding(for: dropdownId)
        let isExpanded = activeDropdownId == dropdownId

        return Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation(.easeInOut(duration: 0.2)) {
                activeDropdownId = isExpanded ? nil : dropdownId
            }
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isExpanded ? FMColors.primary : FMColors.secondary, lineWidth: isExpanded ? 2 : 1)
                    .frame(height: 56)

                Text(label)
                    .font(FMTypography.label)
                    .foregroundColor(isExpanded ? FMColors.primary : FMColors.secondary)
                    .background(FMColors.background)
                    .padding(.horizontal, 4)
                    .offset(x: 12, y: -28)

                HStack {
                    if let time = selection.wrappedValue {
                        Text(formattedTime(time))
                            .font(FMTypography.inputText)
                            .foregroundColor(FMColors.primary)
                    } else {
                        Text(L10n.NewMatch.timePlaceholder)
                            .font(FMTypography.inputText)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    Spacer()

                    Image(systemName: "clock")
                        .foregroundColor(FMColors.primary)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func timePickerPanel(dropdownId: String) -> some View {
        let selection = timeBinding(for: dropdownId)
        let pickerBinding = Binding<Date>(
            get: { selection.wrappedValue ?? defaultTimeSeed(for: dropdownId) },
            set: { selection.wrappedValue = $0 }
        )

        return VStack(spacing: 8) {
            DatePicker("", selection: pickerBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selection.wrappedValue == nil {
                        selection.wrappedValue = defaultTimeSeed(for: dropdownId)
                    }
                    activeDropdownId = nil
                }
            } label: {
                Text(L10n.NewMatch.timeDone)
                    .font(FMTypography.button)
                    .foregroundColor(FMColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.background)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.onSurface, lineWidth: 1)
        )
    }
}

