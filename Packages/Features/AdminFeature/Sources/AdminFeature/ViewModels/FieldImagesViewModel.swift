import Foundation
import UIKit
import NetworkFramework

// MARK: - Slot Model

/// One slot in the field images grid, matching a backend image `position`.
public struct FieldImageSlot: Identifiable, Equatable {
    public let position: Int
    /// Backend image id — non-nil when an image already exists at this position.
    public var imageId: String?
    /// URL of the existing remote image (cleared once replaced by a fresh pick).
    public var remoteURL: String?
    /// Freshly picked image, shown optimistically while/after uploading.
    public var localImage: UIImage?
    /// True while an upload/replace/delete request is in flight for this slot.
    public var isBusy: Bool

    public var id: Int { position }

    /// Whether the slot currently shows an image (local or remote).
    public var hasImage: Bool { localImage != nil || remoteURL != nil }

    init(position: Int, imageId: String? = nil, remoteURL: String? = nil) {
        self.position = position
        self.imageId = imageId
        self.remoteURL = remoteURL
        self.localImage = nil
        self.isBusy = false
    }
}

// MARK: - ViewModel

/// Owns the image slots for the field detail screen and persists changes to the
/// backend immediately: picking an image uploads (or replaces) it, and removing
/// one deletes it.
@MainActor
public final class FieldImagesViewModel: ObservableObject {

    @Published public private(set) var slots: [FieldImageSlot]
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    private let fieldId: String
    private let uploadUseCase: UploadFieldImageUseCaseProtocol
    private let replaceUseCase: ReplaceFieldImageUseCaseProtocol
    private let deleteUseCase: DeleteFieldImageUseCaseProtocol

    /// Longest side (in pixels) every uploaded image is downscaled to, so
    /// photos upload at a uniform, reasonable resolution — not too high, not
    /// too low. 1280px is a good middle ground for field/court photos.
    private let maxImageDimension: CGFloat = 1280
    /// JPEG quality used when encoding a picked image for upload.
    private let compressionQuality: CGFloat = 0.8

    public init(
        field: AdminFieldItem,
        maxImages: Int,
        uploadUseCase: UploadFieldImageUseCaseProtocol,
        replaceUseCase: ReplaceFieldImageUseCaseProtocol,
        deleteUseCase: DeleteFieldImageUseCaseProtocol
    ) {
        self.fieldId = field.id
        self.uploadUseCase = uploadUseCase
        self.replaceUseCase = replaceUseCase
        self.deleteUseCase = deleteUseCase

        let count = max(1, maxImages)
        self.slots = (0..<count).map { position in
            if let existing = field.images.first(where: { $0.position == position }) {
                // Full data from API — we have the imageId and can replace/delete.
                return FieldImageSlot(position: position, imageId: existing.id, remoteURL: existing.url)
            }
            // Loaded from CoreData cache: images[] is empty but imageUrl may exist.
            // Pre-fill position 0 with the cached primary URL so the slot shows the
            // image. imageId will be populated by refreshImages(using:).
            if position == 0, let cachedURL = field.imageUrl {
                return FieldImageSlot(position: 0, imageId: nil, remoteURL: cachedURL)
            }
            return FieldImageSlot(position: position)
        }
    }

    /// Re-fetches the admin fields list and updates each slot's `imageId` and
    /// `remoteURL` with fresh data. Call this when the detail view appears to
    /// avoid uploading to a position that already has an image on the server.
    public func refreshImages(using fetchFields: FetchAdminFieldsUseCaseProtocol) async {
        do {
            let fields = try await fetchFields.execute()
            guard let fresh = fields.first(where: { $0.id == fieldId }) else { return }
            for image in fresh.images {
                guard let idx = slots.firstIndex(where: { $0.position == image.position }),
                      slots[idx].localImage == nil   // don't overwrite a pending local pick
                else { continue }
                slots[idx].imageId   = image.id
                slots[idx].remoteURL = image.url
            }
        } catch {
            // Silently ignore — slots keep their cached state and the user can
            // still attempt an upload; server will return a meaningful error if needed.
        }
    }

    /// Upload a brand-new image or replace the existing one at `position`.
    public func handlePicked(_ image: UIImage, at position: Int) async {
        guard let index = slots.firstIndex(where: { $0.position == position }) else { return }
        // Normalise resolution before showing/uploading: keeps every photo at a
        // uniform size and prevents a huge source image from breaking the UI.
        guard let normalized = image.normalizedForUpload(
            maxDimension: maxImageDimension,
            compressionQuality: compressionQuality
        ) else {
            errorMessage = "No se pudo procesar la imagen."
            return
        }
        let data = normalized.data

        let previousLocal = slots[index].localImage
        slots[index].localImage = normalized.image   // optimistic preview (downscaled)
        slots[index].isBusy = true
        errorMessage = nil

        do {
            let newId: String
            let isReplace = slots[index].imageId != nil
            if let imageId = slots[index].imageId {
                newId = try await replaceUseCase.execute(fieldId: fieldId, imageId: imageId, imageData: data)
            } else {
                newId = try await uploadUseCase.execute(fieldId: fieldId, position: position, imageData: data)
            }
            slots[index].imageId = newId
            slots[index].remoteURL = nil   // the local image is now the source of truth
            successMessage = isReplace ? "Imagen actualizada" : "Imagen guardada"
        } catch {
            slots[index].localImage = previousLocal   // revert optimistic preview
            errorMessage = error.apiErrorMessage ?? error.localizedDescription
        }

        slots[index].isBusy = false
    }

    /// Delete the image at `position`. No-op for an empty slot.
    public func removeImage(at position: Int) async {
        guard let index = slots.firstIndex(where: { $0.position == position }) else { return }

        // Nothing persisted yet — just clear any local preview.
        guard let imageId = slots[index].imageId else {
            slots[index].localImage = nil
            return
        }

        slots[index].isBusy = true
        errorMessage = nil

        do {
            try await deleteUseCase.execute(fieldId: fieldId, imageId: imageId)
            slots[index].imageId = nil
            slots[index].remoteURL = nil
            slots[index].localImage = nil
            successMessage = "Imagen eliminada"
        } catch {
            errorMessage = error.apiErrorMessage ?? error.localizedDescription
        }

        slots[index].isBusy = false
    }
}
