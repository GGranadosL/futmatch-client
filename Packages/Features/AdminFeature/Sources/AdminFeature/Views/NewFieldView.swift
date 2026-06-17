import SwiftUI
import FMDesignSystem

// MARK: - NewFieldView

/// "Nueva Cancha" form — creates a field via `POST /fields/create`.
/// Reuses `FMTextField`, `FMChipGroupOptional`, `FMStickyActionBar` and
/// `FMBackButton` from the design system.
struct NewFieldView: View {
    @StateObject private var viewModel: NewFieldViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after a field is created successfully (lets the home refresh).
    private let onCreated: (() -> Void)?

    // MARK: - Focus: UIKit fields (FMTextField uses UIKitTextField internally)

    @State private var focusName = false
    @State private var focusCapacity = false
    @State private var focusPrice = false

    @State private var focusDescription = false
    @State private var focusExtra = false

    @State private var showSuccessToast = false

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> NewFieldViewModel, onCreated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onCreated = onCreated
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                generalSection
                fieldInfoSection
                rulesSection
                fieldTypeSection
                footwearSection

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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.NewField.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: "Guardar cancha",
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isValid,
                action: { Task { await viewModel.save() } }
            )
        }
        .onChange(of: viewModel.createdField) { field in
            guard field != nil else { return }
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onCreated?()
                dismiss()
            }
        }
        .fmToast("¡Cancha guardada exitosamente!", isPresented: $showSuccessToast, style: .success)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Información del general")
                .padding(.bottom, 16)

            FMTextField(
                label: L10n.NewField.fieldName,
                text: $viewModel.name,
                autocapitalization: .sentences,
                errorMessage: viewModel.nameError,
                trailingIcon: viewModel.name.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                onTrailingIconTap: { viewModel.name = "" }
            )
            .focused($focusName)
            .keyboardNavigation(
                hasPrevious: false, hasNext: true,
                onPrevious: {},
                onNext: { focusCapacity = true }
            )
            hint("Ej. Estadio Central")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    FMTextField(
                        label: L10n.NewField.capacity,
                        text: $viewModel.capacityText,
                        keyboardType: .numberPad,
                        trailingIcon: viewModel.capacityText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                        onTrailingIconTap: { viewModel.capacityText = "" }
                    )
                    .focused($focusCapacity)
                    .keyboardNavigation(
                        hasPrevious: true, hasNext: true,
                        onPrevious: { focusName = true },
                        onNext: { focusPrice = true }
                    )
                    hint("No. Jugadores")
                }

                VStack(alignment: .leading, spacing: 0) {
                    FMTextField(
                        label: L10n.NewField.price,
                        text: $viewModel.priceText,
                        keyboardType: .decimalPad,
                        trailingIcon: viewModel.priceText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                        onTrailingIconTap: { viewModel.priceText = "" }
                    )
                    .focused($focusPrice)
                    .keyboardNavigation(
                        hasPrevious: true, hasNext: true,
                        onPrevious: { focusCapacity = true },
                        onNext: { focusDescription = true }
                    )
                    .onChange(of: focusPrice) { isFocused in
                        if !isFocused { viewModel.formatPriceOnBlur() }
                    }
                    hint("Ej. $500.00")
                }
            }
            .padding(.top, 16)

            parkingToggle
                .padding(.top, 16)
        }
    }

    private var parkingToggle: some View {
        HStack {
            Text(L10n.NewField.parking)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onSurface)
            Spacer()
            Toggle("", isOn: $viewModel.hasParking)
                .labelsHidden()
                .tint(FMColors.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(FMColors.secondary, lineWidth: 1)
        )
    }

    // MARK: - Field Info Section

    private var fieldInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Información del campo")

            FMTextField(label: L10n.NewField.description, text: $viewModel.description, autocapitalization: .sentences)
                .focused($focusDescription)
                .keyboardNavigation(
                    hasPrevious: true, hasNext: true,
                    onPrevious: { focusPrice = true },
                    onNext: { focusExtra = true }
                )

            FMTextField(label: L10n.NewField.extraInfo, text: $viewModel.extraInfo, autocapitalization: .sentences)
                .focused($focusExtra)
                .keyboardNavigation(
                    hasPrevious: true, hasNext: false,
                    onPrevious: { focusDescription = true },
                    onNext: {}
                )
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Reglas")
            FieldRulesEditor(rules: $viewModel.rules)
        }
    }

    // MARK: - Chip Sections

    private var fieldTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tipo de cancha:")
            FMChipGroupOptional(
                options: FieldType.allCases,
                selected: $viewModel.fieldType
            )
        }
    }

    private var footwearSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tipo de calzado:")
            FMChipGroupOptional(
                options: FootwearType.allCases,
                selected: $viewModel.footwearType
            )
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(FMTypography.titleMedium)
            .fontWeight(.bold)
            .foregroundColor(FMColors.onBackground)
    }

    /// Small hint line shown below a field — uses `bodySmall` (12 pt) so it's
    /// clearly secondary to the field label (14–16 pt), giving proper hierarchy.
    private func hint(_ text: String) -> some View {
        Text(text)
            .font(FMTypography.bodySmall)          // 12 pt — visually lighter
            .foregroundColor(FMColors.onSurfaceVariant)
            .padding(.top, 6)
            .padding(.leading, 16)
            .padding(.bottom, 4)
    }
}
