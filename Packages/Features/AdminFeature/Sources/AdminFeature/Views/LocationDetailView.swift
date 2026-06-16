import SwiftUI
import MapKit
import FMDesignSystem
import CoreData

// MARK: - Location Detail (Edit) View

struct LocationDetailView: View {
    @StateObject private var viewModel: EditLocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showUpdateToast = false
    @State private var showDeleteToast = false
    @State private var showDeleteErrorToast = false
    @State private var deleteErrorMessage = "No se pudo eliminar la ubicación"

    private let locationId: String
    private let factory: AdminDependencyFactory
    private let context: NSManagedObjectContext
    private let onDelete: () -> Void
    private let onUpdated: () -> Void

    init(
        location: AdminLocation,
        factory: AdminDependencyFactory,
        context: NSManagedObjectContext,
        localizer: LocationLocalizer = LocationLocalizer(),
        onDelete: @escaping () -> Void = {},
        onUpdated: @escaping () -> Void = {}
    ) {
        self.locationId = location.id
        self.factory = factory
        self.context = context
        self.onDelete = onDelete
        self.onUpdated = onUpdated
        _viewModel = StateObject(wrappedValue: factory.makeEditLocationViewModel(location: location, context: context))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                countryAndCitySection
                mapSection
                addressSearchSection
                coordinatesSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.error)
                        .padding(12)
                        .background(FMColors.errorContainer)
                        .cornerRadius(8)
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
                Text("Editar ubicación")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isDeleting {
                    ProgressView()
                        .tint(FMColors.error)
                } else {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(FMColors.error)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: "Actualizar ubicación",
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isReadyToSave,
                action: { Task { await viewModel.save() } }
            )
        }
        .alert("Eliminar ubicación", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                Task { await deleteLocation() }
            }
        } message: {
            Text("¿Estás seguro de que deseas eliminar esta ubicación?")
        }
        .onChange(of: viewModel.updatedLocation) { location in
            guard location != nil else { return }
            showUpdateToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onUpdated()
                dismiss()
            }
        }
        .fmToast("¡Ubicación actualizada!", isPresented: $showUpdateToast, style: .success)
        .fmToast("¡Ubicación eliminada!", isPresented: $showDeleteToast, style: .success)
        .fmToast(deleteErrorMessage, isPresented: $showDeleteErrorToast, style: .error)
        .task { await viewModel.onAppear() }
    }

    // MARK: - Delete

    private func deleteLocation() async {
        isDeleting = true
        do {
            try await factory.makeDeleteLocationUseCase(context: context).execute(id: locationId)
            // Success: show the toast, then navigate back to the locations list.
            showDeleteToast = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onDelete()
            dismiss()
        } catch {
            // Failure: surface a visible error toast and stay so the user can retry.
            deleteErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "No se pudo eliminar la ubicación"
            showDeleteErrorToast = true
            isDeleting = false
        }
    }

    // MARK: - Sections

    private var countryAndCitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Seleccionar País y Ciudad")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)
                .padding(.bottom, 16)

            Menu {
                ForEach(viewModel.catalog, id: \.code) { country in
                    Button(action: { viewModel.selectCountry(country.code) }) {
                        HStack {
                            Text(country.name)
                            if viewModel.selectedCountry == country.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                menuLabel(viewModel.selectedCountryName)
            }
            .padding(.bottom, 12)

            Menu {
                ForEach(viewModel.citiesForSelectedCountry, id: \.code) { city in
                    Button(action: { viewModel.selectCity(city.code) }) {
                        HStack {
                            Text(city.name)
                            if viewModel.selectedCity == city.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                menuLabel(viewModel.selectedCityName)
            }
        }
    }

    private func menuLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(FMColors.onBackground)
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundColor(FMColors.onSurfaceVariant)
        }
        .padding(12)
        .background(FMColors.surfaceContainerLowest)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Marcar Ubicación")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)

            MapViewContainer(
                region: $viewModel.mapRegion,
                latitude: viewModel.latitude,
                longitude: viewModel.longitude,
                onCoordinateChange: { lat, lon in
                    viewModel.updateMapCoordinates(latitude: lat, longitude: lon)
                }
            )
            .frame(height: 280)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.cityValidationError != nil ? FMColors.error : FMColors.outlineVariant, lineWidth: 1)
            )

            if let cityError = viewModel.cityValidationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(cityError)
                        .font(FMTypography.bodySmall)
                }
                .foregroundColor(FMColors.error)
                .padding(10)
                .background(FMColors.errorContainer)
                .cornerRadius(8)
            }
        }
    }

    private var addressSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Buscar Dirección")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)

            FMTextField(
                label: "Buscar dirección",
                text: $viewModel.searchQuery,
                placeholder: "Calle, colonia, ciudad...",
                autocapitalization: .sentences,
                trailingIcon: viewModel.searchQuery.isEmpty ? nil : Image(systemName: "xmark.circle.fill"),
                onTrailingIconTap: { viewModel.searchQuery = "" }
            )
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.searchAddresses(newValue)
            }

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.searchResults) { result in
                        Button(action: { viewModel.selectSearchResult(result) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name)
                                    .font(FMTypography.bodySmall)
                                    .foregroundColor(FMColors.onBackground)
                                    .lineLimit(2)
                                Text(result.address)
                                    .font(FMTypography.labelSmall)
                                    .foregroundColor(FMColors.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(FMColors.surfaceContainer)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 8)
            }

            if viewModel.isSearching {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Buscando...")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                .padding(12)
            }
        }
    }

    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información de Ubicación")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)

            FMTextField(
                label: "Dirección",
                text: $viewModel.address,
                autocapitalization: .sentences
            )

            HStack(spacing: 12) {
                FMTextField(
                    label: "Latitud",
                    text: latitudeBinding,
                    keyboardType: .decimalPad
                )
                FMTextField(
                    label: "Longitud",
                    text: longitudeBinding,
                    keyboardType: .decimalPad
                )
            }
        }
    }

    private var latitudeBinding: Binding<String> {
        Binding(
            get: { viewModel.latitude == 0 ? "" : String(format: "%.6f", viewModel.latitude) },
            set: { if let d = Double($0) { viewModel.latitude = d } }
        )
    }

    private var longitudeBinding: Binding<String> {
        Binding(
            get: { viewModel.longitude == 0 ? "" : String(format: "%.6f", viewModel.longitude) },
            set: { if let d = Double($0) { viewModel.longitude = d } }
        )
    }
}
