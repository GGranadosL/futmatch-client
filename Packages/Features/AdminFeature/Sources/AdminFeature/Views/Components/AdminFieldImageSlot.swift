import SwiftUI
import UIKit
import FMDesignSystem

// MARK: - AdminFieldImageSlot

/// Single image upload slot for the field detail screen.
///
/// Tap flow (provided by `fmImagePickerFlow`):
///   1. Source picker sheet  → "Tomar Foto" / "Galería de Fotos"
///   2. Camera (fullScreenCover) or PhotosPicker → image selected
///   3. Confirmation sheet   → "Usar imagen" / "Cancelar"
///   4. Confirmed            → `onPicked` is called so the owner can upload
struct AdminFieldImageSlot: View {
    let position: Int
    let remoteURL: String?
    let localImage: UIImage?
    let isBusy: Bool
    let onPicked: (UIImage) -> Void
    let onRemove: () -> Void

    @State private var showPickerFlow = false
    /// Downloaded copy of `remoteURL`, loaded lazily and cached.
    @State private var remoteImage: UIImage?

    // MARK: - Body

    var body: some View {
        Button { showPickerFlow = true } label: {
            slotContent.overlay { busyOverlay }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .task(id: remoteURL) { await loadRemoteImage() }
        .fmImagePickerFlow(
            isPresented: $showPickerFlow,
            config: FMImagePickerFlowConfig(
                title: "Subir imagen",
                subtitle: "Selecciona el origen de la fotografía\npara la nueva cancha.",
                takePhotoTitle: "Tomar Foto",
                takePhotoSubtitle: "Usa la cámara de tu dispositivo",
                galleryTitle: "Galería de Fotos",
                gallerySubtitle: "Elige desde tus archivos",
                confirmTitle: "Confirmar imagen",
                confirmMessage: "¿Deseas usar esta fotografía para la cancha?",
                confirmButtonTitle: "Usar imagen",
                cancelTitle: "Cancelar"
            ),
            onPicked: onPicked
        )
    }

    // MARK: - Slot visual

    private var displayImage: UIImage? { localImage ?? remoteImage }

    @ViewBuilder
    private var slotContent: some View {
        if let image = displayImage {
            filledSlot(image: image)
        } else {
            emptySlot
        }
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if isBusy {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.35))
                .overlay { ProgressView().tint(.white) }
        }
    }

    // MARK: - Remote image loading

    private func loadRemoteImage() async {
        guard let imagePath = remoteURL, !imagePath.isEmpty else {
            remoteImage = nil
            return
        }
        remoteImage = await FieldImageLoader.load(imagePath)
    }

    // MARK: - Slot appearance

    private var emptySlot: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(FMColors.onSurfaceVariant)
            Text("SUBIR")
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
        // Fill whatever fixed square the parent gives this slot.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }

    private func filledSlot(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            // Fit (not fill) so the whole photo is visible without cropping.
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FMColors.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if !isBusy {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .padding(4)
                }
            }
    }
}
