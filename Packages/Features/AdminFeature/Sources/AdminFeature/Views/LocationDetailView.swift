import SwiftUI
import MapKit
import FMDesignSystem
import CoreData

// MARK: - Location Detail View

struct LocationDetailView: View {
    let location: AdminLocation
    let localizer: LocationLocalizer
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    private let factory: AdminDependencyFactory
    private let context: NSManagedObjectContext

    init(
        location: AdminLocation,
        factory: AdminDependencyFactory,
        context: NSManagedObjectContext,
        localizer: LocationLocalizer = LocationLocalizer(),
        onDelete: @escaping () -> Void = {}
    ) {
        self.location = location
        self.factory = factory
        self.context = context
        self.localizer = localizer
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Map
                mapSection

                // Info
                infoSection

                // Coordinates
                coordinatesSection

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(location.address)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(FMColors.error)
                }
                .disabled(isDeleting)
            }
        }
        .alert("Eliminar ubicación", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                Task { await deleteLocation() }
            }
        } message: {
            Text("¿Estás seguro de que deseas eliminar esta ubicación?")
        }
    }

    private func deleteLocation() async {
        isDeleting = true
        do {
            try await factory.makeDeleteLocationUseCase(context: context).execute(id: location.id)
            onDelete()
            dismiss()
        } catch {
            isDeleting = false
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        LocationDetailMapView(
            latitude: location.latitude,
            longitude: location.longitude,
            address: location.address
        )
        .frame(height: 220)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Información")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)

            VStack(spacing: 12) {
                DetailRow(icon: "mappin.circle.fill", label: "Dirección", value: location.address)
                DetailRow(icon: "building.2.fill", label: "País", value: localizer.countryName(for: location.country))
                DetailRow(icon: "house.fill", label: "Ciudad", value: localizer.cityName(for: location.city))
            }
        }
    }

    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coordenadas")
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.onBackground)

            HStack(spacing: 12) {
                CoordinateCard(
                    label: "Latitud",
                    value: location.latitude,
                    format: "%.6f"
                )
                CoordinateCard(
                    label: "Longitud",
                    value: location.longitude,
                    format: "%.6f"
                )
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(FMColors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Text(value)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(FMColors.onBackground)
            }

            Spacer()
        }
        .padding(12)
        .background(FMColors.surfaceContainerLowest)
        .cornerRadius(8)
    }
}

// MARK: - Coordinate Card

private struct CoordinateCard: View {
    let label: String
    let value: Double
    let format: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text(String(format: format, value))
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onBackground)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(FMColors.surfaceContainerLowest)
        .cornerRadius(8)
    }
}

// MARK: - Map View

private struct LocationDetailMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let address: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        annotation.title = address
        mapView.addAnnotation(annotation)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {}
}
