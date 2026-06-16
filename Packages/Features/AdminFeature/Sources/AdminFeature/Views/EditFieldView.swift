import SwiftUI
import MapKit
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
    @State private var showSuccessToast        = false
    @State private var showLocationLinkedToast = false

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
                locationSection
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.error)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
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
        .task { await viewModel.fetchLocations() }
        .onChange(of: viewModel.updatedField) { updated in
            guard let updated else { return }
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onUpdated?(updated)
                dismiss()
            }
        }
        .onChange(of: viewModel.locationLinked) { linked in
            guard linked else { return }
            showLocationLinkedToast = true
            viewModel.locationLinked = false
        }
        .fmToast("¡Cancha actualizada!", isPresented: $showSuccessToast, style: .success)
        .fmToast("¡Ubicación asignada!", isPresented: $showLocationLinkedToast, style: .success)
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

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ubicación")

            if let location = viewModel.assignedLocation {
                AssignedLocationPreview(location: location)
                locationMenu(label: changeLocationLabel)
            } else {
                locationMenu(label: assignLocationLabel)
            }
        }
    }

    private func locationMenu<L: View>(label: L) -> some View {
        Menu {
            if viewModel.availableLocations.isEmpty {
                Text(viewModel.isLoadingLocations ? "Cargando ubicaciones..." : "Sin ubicaciones disponibles")
            } else {
                ForEach(viewModel.availableLocations) { loc in
                    Button(loc.address) {
                        Task { await viewModel.assignLocation(loc) }
                    }
                }
            }
        } label: {
            label
        }
        .disabled(viewModel.isLinkingLocation)
    }

    private var assignLocationLabel: some View {
        HStack(spacing: 8) {
            if viewModel.isLinkingLocation {
                ProgressView().scaleEffect(0.85).tint(FMColors.primary)
            } else {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 18))
            }
            Text("Asignar ubicación")
                .font(FMTypography.labelLarge)
        }
        .foregroundColor(FMColors.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FMColors.primaryContainer.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(FMColors.primary.opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var changeLocationLabel: some View {
        HStack(spacing: 6) {
            if viewModel.isLinkingLocation {
                ProgressView().scaleEffect(0.85).tint(FMColors.primary)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
            }
            Text("Cambiar ubicación")
                .font(FMTypography.labelLarge)
        }
        .foregroundColor(FMColors.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(FMColors.primary, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(FMTypography.titleMedium).fontWeight(.bold).foregroundColor(FMColors.onBackground)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(FMTypography.bodySmall).foregroundColor(FMColors.onSurfaceVariant)
            .padding(.top, 6).padding(.leading, 16).padding(.bottom, 4)
    }
}

// MARK: - Assigned Location Preview

private struct AssignedLocationPreview: View {
    let location: AdminLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(FMColors.primary)
                    .font(.system(size: 16))
                Text(location.address)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onSurface)
                    .lineLimit(2)
            }

            FieldLocationMiniMapView(latitude: location.latitude, longitude: location.longitude)
                .frame(height: 140)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(FMColors.outlineVariant, lineWidth: 1)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

// MARK: - Mini Map (non-interactive, read-only)

struct FieldLocationMiniMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        )
        mapView.setRegion(region, animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapView.addAnnotation(annotation)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {}
}
