import SwiftUI
import FMDesignSystem
import MapKit
import CoreData

// MARK: - Locations List View

struct AdminLocationsListView: View {
    @State private var locations: [AdminLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let factory: AdminDependencyFactory
    private let localizer: LocationLocalizer
    private let context: NSManagedObjectContext

    init(factory: AdminDependencyFactory, context: NSManagedObjectContext, localizer: LocationLocalizer = LocationLocalizer()) {
        self.factory = factory
        self.context = context
        self.localizer = localizer
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && locations.isEmpty {
                skeletonList
            } else if !isLoading && locations.isEmpty {
                FMEmptyStateCard(
                    icon: "mappin.circle.fill",
                    message: "No hay ubicaciones registradas"
                )
                .padding(.horizontal, 24)
                .padding(.top, 32)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 12) {
                            ForEach(locations) { location in
                                NavigationLink(destination: LocationDetailView(
                                    location: location,
                                    factory: factory,
                                    context: context,
                                    onDelete:  { Task { await loadLocations() } },
                                    onUpdated: { Task { await loadLocations() } }
                                )) {
                                    LocationCard(location: location, localizer: localizer)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)

                        if let error = errorMessage {
                            Text(error)
                                .font(FMTypography.bodySmall)
                                .foregroundColor(FMColors.error)
                                .padding(12)
                                .background(FMColors.errorContainer)
                                .cornerRadius(8)
                                .padding(24)
                        }

                        Spacer().frame(height: 32)
                    }
                }
                .refreshable { await loadLocations() }
            }
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text("Ubicaciones")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task { await loadLocations() }
    }

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    AdminLocationCardSkeleton()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .disabled(true)
    }

    private func loadLocations() async {
        let useCase = factory.makeFetchLocationsUseCase(context: context)

        // Show cache immediately so the list appears without a spinner.
        // Sort by address so cache and network arrive in the same order.
        let cached = useCase.executeCached().sorted { $0.address < $1.address }
        if !cached.isEmpty {
            locations = cached
        } else {
            isLoading = true
        }

        errorMessage = nil

        do {
            let fresh = try await useCase.execute().sorted { $0.address < $1.address }
            locations = fresh
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Location Card

private struct LocationCard: View {
    let location: AdminLocation
    let localizer: LocationLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let countryName = localizer.countryName(for: location.country)
            let cityName = localizer.cityName(for: location.city)
            // Header with name and badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.address)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onBackground)
                        .lineLimit(2)

                    Text("\(cityName), \(countryName)")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Label(String(format: "%.4f", location.latitude), systemImage: "mappin")
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    Label(String(format: "%.4f", location.longitude), systemImage: "mappin")
                        .font(FMTypography.labelSmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            }

            // Map preview
            MiniMapView(
                latitude: location.latitude,
                longitude: location.longitude,
                address: location.address
            )
            .frame(height: 120)
            .cornerRadius(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

// MARK: - Mini Map View

private struct MiniMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let address: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        mapView.setRegion(region, animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        annotation.title = address
        mapView.addAnnotation(annotation)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update is handled in makeUIView
    }
}

// MARK: - Preview

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return NavigationStack {
        AdminLocationsListView(factory: AdminDependencyFactory(), context: context)
    }
}
