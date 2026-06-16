import SwiftUI
import MapKit
import FMDesignSystem

// MARK: - New Location View

struct NewLocationView: View {
    @StateObject private var viewModel: NewLocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessToast = false

    /// Called after a location is created successfully (lets the home refresh).
    private let onCreated: (() -> Void)?

    init(viewModel: @autoclosure @escaping () -> NewLocationViewModel, onCreated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onCreated = onCreated
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Country & City Selection
                countryAndCitySection

                // Map Section
                mapSection

                // Address Search
                addressSearchSection

                // Coordinates & Address
                coordinatesSection

                // Error message
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
                Text("Nueva ubicación")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: "Guardar ubicación",
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.isReadyToSave,
                action: { Task { await viewModel.save() } }
            )
        }
        .onChange(of: viewModel.createdLocation) { location in
            guard location != nil else { return }
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onCreated?()
                dismiss()
            }
        }
        .fmToast("¡Ubicación guardada!", isPresented: $showSuccessToast, style: .success)
        .task { await viewModel.onAppear() }
    }

    // MARK: - Sections

    private var countryAndCitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Seleccionar País y Ciudad")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)
                .padding(.bottom, 16)

            // Country dropdown
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
                HStack {
                    Text(viewModel.selectedCountryName)
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
            .padding(.bottom, 12)

            // City dropdown
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
                HStack {
                    Text(viewModel.selectedCityName)
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
        }
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

            // Search results
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
                    ProgressView()
                        .scaleEffect(0.8)
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

            FMTextField(
                label: "Número Exterior",
                text: $viewModel.exteriorNumber,
                placeholder: "Ej: 15, 7B, 23-A (opcional)"
            )
            .onChange(of: viewModel.exteriorNumber) { _ in
                viewModel.rebuildAddress()
            }

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

// MARK: - Map Container

struct MapViewContainer: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let latitude: Double
    let longitude: Double
    let onCoordinateChange: (Double, Double) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.showsUserLocation = true

        // Add tap gesture to place pin
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let newCenter = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Only recenter when the target is off-screen (e.g. a search result jump).
        // Tapping/dragging the pin keeps it within the visible area, so we leave the
        // current zoom untouched — assigning `region` here would reset the span and
        // make the map zoom out on every pin move.
        if !mapView.visibleMapRect.contains(MKMapPoint(newCenter)) {
            mapView.setCenter(newCenter, animated: true)
        }

        // Refresh the pin only if it actually moved, to avoid annotation flicker.
        let existing = mapView.annotations.compactMap { $0 as? MKPointAnnotation }.first
        if existing == nil ||
            abs(existing!.coordinate.latitude - newCenter.latitude) > 0.000001 ||
            abs(existing!.coordinate.longitude - newCenter.longitude) > 0.000001 {
            mapView.removeAnnotations(mapView.annotations)
            let annotation = MKPointAnnotation()
            annotation.coordinate = newCenter
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapViewContainer

        init(_ parent: MapViewContainer) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let tapPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)

            parent.onCoordinateChange(coordinate.latitude, coordinate.longitude)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            annotationView.markerTintColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
            annotationView.isDraggable = true
            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending || newState == .canceling {
                if let annotation = view.annotation {
                    parent.onCoordinateChange(annotation.coordinate.latitude, annotation.coordinate.longitude)
                }
            }
        }
    }
}
