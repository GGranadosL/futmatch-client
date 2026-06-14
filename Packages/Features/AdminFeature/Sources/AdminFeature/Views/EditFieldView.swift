import SwiftUI
import FMDesignSystem

// MARK: - EditFieldView
// Same layout as NewFieldView, but backed by EditFieldViewModel (PATCH /fields/{id}).

struct EditFieldView: View {
    @StateObject private var viewModel: EditFieldViewModel
    @Environment(\.dismiss) private var dismiss
    private let onUpdated: ((AdminFieldItem) -> Void)?

    @State private var focusName        = false
    @State private var focusCapacity    = false
    @State private var focusPrice       = false
    @State private var focusDescription = false
    @State private var focusExtra       = false
    @State private var showSuccessToast = false

    init(viewModel: @autoclosure @escaping () -> EditFieldViewModel, onUpdated: ((AdminFieldItem) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onUpdated = onUpdated
    }

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
                Text("Editar Cancha")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: "Guardar cambios",
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isValid,
                action: { Task { await viewModel.save() } }
            )
        }
        .onChange(of: viewModel.updatedField) { updated in
            guard let updated else { return }
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onUpdated?(updated)
                dismiss()
            }
        }
        .fmToast("¡Cancha actualizada!", isPresented: $showSuccessToast, style: .success)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Información del general").padding(.bottom, 16)

            FMTextField(
                label: "Nombre de la cancha",
                text: $viewModel.name,
                autocapitalization: .sentences,
                errorMessage: viewModel.nameError,
                trailingIcon: viewModel.name.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                onTrailingIconTap: { viewModel.name = "" }
            )
            .focused($focusName)
            .keyboardNavigation(hasPrevious: false, hasNext: true, onPrevious: {}, onNext: { focusCapacity = true })
            hint("Ej. Estadio Central")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    FMTextField(
                        label: "Capacidad",
                        text: $viewModel.capacityText,
                        keyboardType: .numberPad,
                        trailingIcon: viewModel.capacityText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                        onTrailingIconTap: { viewModel.capacityText = "" }
                    )
                    .focused($focusCapacity)
                    .keyboardNavigation(hasPrevious: true, hasNext: true, onPrevious: { focusName = true }, onNext: { focusPrice = true })
                    hint("No. Jugadores")
                }
                VStack(alignment: .leading, spacing: 0) {
                    FMTextField(
                        label: "Precio",
                        text: $viewModel.priceText,
                        keyboardType: .decimalPad,
                        trailingIcon: viewModel.priceText.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                        onTrailingIconTap: { viewModel.priceText = "" }
                    )
                    .focused($focusPrice)
                    .keyboardNavigation(hasPrevious: true, hasNext: true, onPrevious: { focusCapacity = true }, onNext: { focusDescription = true })
                    .onChange(of: focusPrice) { if !$0 { viewModel.formatPriceOnBlur() } }
                    hint("Ej. $500.00")
                }
            }
            .padding(.top, 16)

            parkingToggle.padding(.top, 16)
        }
    }

    private var parkingToggle: some View {
        HStack {
            Text("Estacionamiento")
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onSurface)
            Spacer()
            Toggle("", isOn: $viewModel.hasParking).labelsHidden().tint(FMColors.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 8).stroke(FMColors.secondary, lineWidth: 1))
    }

    // MARK: - Field Info Section

    private var fieldInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Información del campo")
            FMTextField(label: "Descripción", text: $viewModel.description, autocapitalization: .sentences)
                .focused($focusDescription)
                .keyboardNavigation(hasPrevious: true, hasNext: true, onPrevious: { focusPrice = true }, onNext: { focusExtra = true })
            FMTextField(label: "Información extra", text: $viewModel.extraInfo, autocapitalization: .sentences)
                .focused($focusExtra)
                .keyboardNavigation(hasPrevious: true, hasNext: false, onPrevious: { focusDescription = true }, onNext: {})
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Reglas")
            FieldRulesEditor(rules: $viewModel.rules)
        }
    }

    private var fieldTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tipo de cancha:")
            FMChipGroupOptional(options: FieldType.allCases, selected: $viewModel.fieldType)
        }
    }

    private var footwearSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tipo de calzado:")
            FMChipGroupOptional(options: FootwearType.allCases, selected: $viewModel.footwearType)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(FMTypography.titleMedium).fontWeight(.bold).foregroundColor(FMColors.onBackground)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(FMTypography.bodySmall).foregroundColor(FMColors.onSurfaceVariant)
            .padding(.top, 6).padding(.leading, 16).padding(.bottom, 4)
    }
}
