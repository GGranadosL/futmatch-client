import SwiftUI
import MapKit
import FMDesignSystem
import CoreData

// MARK: - AdminFieldDetailView

struct AdminFieldDetailView: View {
    /// Held in `@State` so an edit can refresh this screen in place without
    /// having to leave and re-enter from the list.
    @State private var field: AdminFieldItem
    private let factory: AdminDependencyFactory
    /// Notifies the parent (fields list) when the field changes, so its card
    /// reflects the edit too.
    private let onFieldUpdated: ((AdminFieldItem) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var showEdit = false
    @State private var showSuccessToast = false
    @State private var availableLocations: [AdminLocation] = []
    @State private var isLoadingLocations = false
    @State private var isLinkingLocation = false
    @State private var showLocationLinkedToast = false
    @State private var locationError: String?
    /// Owns the image slots and persists uploads/replacements/deletions.
    /// Slot count comes from Remote Config (`maxImages`, default 1).
    @StateObject private var imagesViewModel: FieldImagesViewModel

    init(
        field: AdminFieldItem,
        maxImages: Int,
        factory: AdminDependencyFactory,
        onFieldUpdated: ((AdminFieldItem) -> Void)? = nil
    ) {
        _field = State(initialValue: field)
        self.factory = factory
        self.onFieldUpdated = onFieldUpdated
        _imagesViewModel = StateObject(
            wrappedValue: factory.makeFieldImagesViewModel(field: field, maxImages: maxImages)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                imagesSection
                HStack(alignment: .top, spacing: 24) {
                    parkingSection
                    Spacer()
                    priceSection
                }
                capacitySection
                if let desc = field.description, !desc.isEmpty { descriptionSection(desc) }
                if let rules = field.rules, !rules.isEmpty { rulesSection(rules) }
                if let extra = field.extraInfo, !extra.isEmpty { extraInfoSection(extra) }
                locationSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(FMColors.background.ignoresSafeArea())
        .task {
            // Refresh image data from the API so we have real imageIds.
            // This prevents calling the UPLOAD endpoint on a position that
            // already has an image, which would cause a 400 from the server.
            await imagesViewModel.refreshImages(using: factory.makeFetchAdminFieldsUseCase())
        }
        .task {
            let useCase = factory.makeFetchLocationsUseCase(context: context)
            let cached = useCase.executeCached().sorted { $0.address < $1.address }
            if !cached.isEmpty { availableLocations = cached } else { isLoadingLocations = true }
            do {
                let fresh = try await useCase.execute().sorted { $0.address < $1.address }
                availableLocations = fresh
            } catch {}
            isLoadingLocations = false
        }
        .onChange(of: showLocationLinkedToast) { showing in
            guard showing else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showLocationLinkedToast = false
            }
        }
        .fmToast("¡Ubicación asignada!", isPresented: $showLocationLinkedToast, style: .success)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(field.name)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showEdit = true } label: {
                    Image("edit_icon", bundle: .main)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(FMColors.onSurface)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            EditFieldView(
                viewModel: factory.makeEditFieldViewModel(field: field),
                onUpdated: { updated in
                    field = updated
                    onFieldUpdated?(updated)
                }
            )
        }
        .onChange(of: imagesViewModel.successMessage) { message in
            guard message != nil else { return }
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                imagesViewModel.successMessage = nil
            }
        }
        .fmToast(imagesViewModel.successMessage ?? "", isPresented: $showSuccessToast, style: .success)
    }

    // MARK: - Images Section

    /// Fixed square (1:1) size for each image slot. A hard size (not
    /// aspectRatio + maxHeight) is essential inside a vertical ScrollView, where
    /// the proposed height is unbounded and aspectRatio would otherwise size off
    /// the full width and blow out the layout.
    private let imageSlotWidth: CGFloat = 120
    private let imageSlotHeight: CGFloat = 120

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Imágenes del campo")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(imagesViewModel.slots) { slot in
                        AdminFieldImageSlot(
                            position: slot.position,
                            remoteURL: slot.remoteURL,
                            localImage: slot.localImage,
                            isBusy: slot.isBusy,
                            onPicked: { image in
                                Task { await imagesViewModel.handlePicked(image, at: slot.position) }
                            },
                            onRemove: {
                                Task { await imagesViewModel.removeImage(at: slot.position) }
                            }
                        )
                        .frame(width: imageSlotWidth, height: imageSlotHeight)
                    }
                }
            }
            if let error = imagesViewModel.errorMessage {
                Text(error)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.error)
            }
        }
    }

    // MARK: - Price

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Precio")
            Text(field.formattedPrice)
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.primary)
        }
    }

    // MARK: - Parking

    private var parkingSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "parkingsign")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(red: 0.45, green: 0.55, blue: 0.85))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Estacionamiento")
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: field.hasParking ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(field.hasParking ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FMColors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Capacity

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Capacidad")
            Text("\(field.capacity) Jugadores")
                .font(FMTypography.bodyLarge)
                .foregroundColor(FMColors.onSurface)
        }
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Descripción")
            Text(text)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurface)
        }
    }

    // MARK: - Rules

    private func rulesSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Reglas")
            // Render each rule as a bullet point, stripping any stored "N. " prefix.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(
                    FieldRulesFormatter.parse(text),
                    id: \.self
                ) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(FMColors.primary)
                            .font(FMTypography.bodyMedium)
                        Text(line)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurface)
                    }
                }
            }
        }
    }

    // MARK: - Extra Info

    private func extraInfoSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Información extra")
            Text(text)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurface)
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ubicación")
            if let location = field.assignedLocation {
                FieldAssignedLocationPreview(location: location)
                locationMenu(label: changeLocationLabel)
            } else {
                locationMenu(label: assignLocationLabel)
            }
            if let err = locationError {
                Text(err)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.error)
            }
        }
    }

    private func locationMenu<L: View>(label: L) -> some View {
        Menu {
            if availableLocations.isEmpty {
                Text(isLoadingLocations ? "Cargando ubicaciones..." : "Sin ubicaciones disponibles")
            } else {
                ForEach(availableLocations) { loc in
                    Button(loc.address) {
                        Task { await assignLocation(loc) }
                    }
                }
            }
        } label: {
            label
        }
        .disabled(isLinkingLocation)
    }

    private var assignLocationLabel: some View {
        HStack(spacing: 8) {
            if isLinkingLocation {
                ProgressView().scaleEffect(0.85).tint(FMColors.primary)
            } else {
                Image(systemName: "mappin.circle").font(.system(size: 18))
            }
            Text("Asignar ubicación").font(FMTypography.labelLarge)
        }
        .foregroundColor(FMColors.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(FMColors.primaryContainer.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(FMColors.primary.opacity(0.5), lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var changeLocationLabel: some View {
        HStack(spacing: 6) {
            if isLinkingLocation {
                ProgressView().scaleEffect(0.85).tint(FMColors.primary)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14))
            }
            Text("Cambiar ubicación").font(FMTypography.labelLarge)
        }
        .foregroundColor(FMColors.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).stroke(FMColors.primary, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func assignLocation(_ location: AdminLocation) async {
        isLinkingLocation = true
        locationError = nil
        do {
            try await factory.makeLinkLocationUseCase().execute(fieldId: field.id, locationId: location.id)
            field = AdminFieldItem(
                id: field.id,
                name: field.name,
                priceInCents: field.priceInCents,
                capacity: field.capacity,
                imageUrl: field.imageUrl,
                images: field.images,
                address: field.address,
                description: field.description,
                rules: field.rules,
                extraInfo: field.extraInfo,
                hasParking: field.hasParking,
                fieldType: field.fieldType,
                footwearType: field.footwearType,
                locationId: location.id,
                assignedLocation: location
            )
            onFieldUpdated?(field)
            showLocationLinkedToast = true
        } catch {
            locationError = error.localizedDescription
        }
        isLinkingLocation = false
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(FMTypography.headlineSmall)
            .fontWeight(.bold)
            .foregroundColor(FMColors.onBackground)
    }
}

// MARK: - Assigned Location Preview

private struct FieldAssignedLocationPreview: View {
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
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(FMColors.outlineVariant, lineWidth: 1))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
    }
}

// MARK: - Mini Map (non-interactive)

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
