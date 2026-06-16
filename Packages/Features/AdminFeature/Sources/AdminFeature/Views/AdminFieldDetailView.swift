import SwiftUI
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
                priceSection
                capacitySection
                parkingSection
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
                viewModel: factory.makeEditFieldViewModel(field: field, context: context),
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
            sectionTitle("Precio por reserva")
            Text(field.formattedPrice)
                .font(FMTypography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(FMColors.primary)
        }
    }

    // MARK: - Parking

    private var parkingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Estacionamiento")
            HStack(spacing: 10) {
                Image(systemName: field.hasParking ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(field.hasParking ? FMColors.primary : FMColors.onSurfaceVariant)
                Text(field.hasParking ? "Cuenta con estacionamiento" : "No cuenta con estacionamiento")
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(field.hasParking ? FMColors.onSurface : FMColors.onSurfaceVariant)
            }
        }
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

    // MARK: - Location placeholder

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ubicación")
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)

                VStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 30))
                        .foregroundColor(FMColors.onSurfaceVariant)
                    Text("Asignar ubicación")
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(FMTypography.headlineSmall)
            .fontWeight(.bold)
            .foregroundColor(FMColors.onBackground)
    }
}
