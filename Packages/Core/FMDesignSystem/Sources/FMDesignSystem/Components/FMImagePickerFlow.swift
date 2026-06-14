import SwiftUI
import PhotosUI
import UIKit

// MARK: - FMImagePickerFlow Configuration

/// Texts and appearance for the image picker flow. All strings are injectable
/// so each feature can pass its own localized copy.
public struct FMImagePickerFlowConfig {
    public var title: String
    public var subtitle: String
    public var takePhotoTitle: String
    public var takePhotoSubtitle: String
    public var galleryTitle: String
    public var gallerySubtitle: String
    public var confirmTitle: String
    public var confirmMessage: String
    public var confirmButtonTitle: String
    public var cancelTitle: String
    /// When true the confirmation thumbnail is rendered as a circle (avatars).
    public var circularPreview: Bool

    public init(
        title: String,
        subtitle: String,
        takePhotoTitle: String,
        takePhotoSubtitle: String,
        galleryTitle: String,
        gallerySubtitle: String,
        confirmTitle: String,
        confirmMessage: String,
        confirmButtonTitle: String,
        cancelTitle: String,
        circularPreview: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.takePhotoTitle = takePhotoTitle
        self.takePhotoSubtitle = takePhotoSubtitle
        self.galleryTitle = galleryTitle
        self.gallerySubtitle = gallerySubtitle
        self.confirmTitle = confirmTitle
        self.confirmMessage = confirmMessage
        self.confirmButtonTitle = confirmButtonTitle
        self.cancelTitle = cancelTitle
        self.circularPreview = circularPreview
    }
}

// MARK: - View Extension

public extension View {
    /// Attaches the FutMatch image picker flow to a view:
    ///   1. Source picker sheet → "Take photo" / "Gallery"
    ///   2. Camera (fullScreenCover) or PhotosPicker → image selected
    ///   3. Confirmation sheet → confirm / cancel
    ///   4. Confirmed → `onPicked` is called with the chosen image
    ///
    /// `isPresented` is a trigger: set it to `true` to start the flow; the
    /// modifier resets it to `false` immediately, so it can be re-triggered.
    func fmImagePickerFlow(
        isPresented: Binding<Bool>,
        config: FMImagePickerFlowConfig,
        onPicked: @escaping (UIImage) -> Void
    ) -> some View {
        modifier(FMImagePickerFlowModifier(
            isPresented: isPresented,
            config: config,
            onPicked: onPicked
        ))
    }
}

// MARK: - Flow Modifier

/// Presentation strategy: all sheets are driven by a single `sheetItem` binding
/// (so iOS only ever manages one sheet at a time). The camera uses a separate
/// `fullScreenCover` which is orthogonal to sheets on iOS 16+.
private struct FMImagePickerFlowModifier: ViewModifier {
    @Binding var isPresented: Bool
    let config: FMImagePickerFlowConfig
    let onPicked: (UIImage) -> Void

    /// Drives the single sheet. Changing to nil dismisses; changing between
    /// cases is intentionally avoided (set nil first, then the new case).
    @State private var sheetItem: FlowSheet?
    /// Remembers which picker the user asked for so the sheet's `onDismiss`
    /// can launch it after the source-picker sheet is fully gone.
    @State private var pendingSource: PickerSource?

    @State private var showCamera  = false
    @State private var showGallery = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { presented in
                guard presented else { return }
                // Consume the trigger right away so the flow can be re-launched.
                isPresented = false
                sheetItem = .sourcePicker
            }
            // ── Single sheet driven by sheetItem ──────────────────────────
            // onDismiss fires AFTER the dismiss animation fully completes, so
            // it's the only safe moment to present the next picker.
            .sheet(item: $sheetItem, onDismiss: presentPendingSource) { item in
                switch item {
                case .sourcePicker:
                    FMImageSourcePickerSheet(
                        config: config,
                        onCamera:  { pendingSource = .camera;  sheetItem = nil },
                        onGallery: { pendingSource = .gallery; sheetItem = nil },
                        onCancel:  { sheetItem = nil }
                    )
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)

                case .confirmation(let image):
                    FMImageConfirmationSheet(
                        image: image,
                        config: config,
                        onConfirm: {
                            onPicked(image)
                            pendingImage = nil
                            sheetItem    = nil
                        },
                        onCancel: {
                            pendingImage = nil
                            sheetItem    = nil
                        }
                    )
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.hidden)
                }
            }
            // ── Camera (fullScreenCover is orthogonal to .sheet on iOS 16+) ──
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                // onDismiss fires after the cover animation fully completes
                if let img = pendingImage {
                    sheetItem = .confirmation(img)
                }
            }) {
                FMCameraPicker(image: $pendingImage, isPresented: $showCamera)
                    .ignoresSafeArea()
            }
            // ── Gallery ───────────────────────────────────────────────────
            .photosPicker(isPresented: $showGallery, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let img  = UIImage(data: data) else { return }
                    pendingImage = img
                    // The system photo picker needs a short window to finish its
                    // own dismiss animation before we can present another sheet.
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    sheetItem = .confirmation(img)
                }
            }
    }

    /// Called by the sheet's `onDismiss` (after the close animation finishes).
    /// If the user chose a source, present the camera or photo picker now —
    /// this is the only moment with no presentation overlap.
    private func presentPendingSource() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .camera:
            showCamera = true
        case .gallery:
            pickerItem = nil   // reset so onChange always fires on the next pick
            showGallery = true
        }
    }
}

// MARK: - Supporting types

private enum FlowSheet: Identifiable {
    case sourcePicker
    case confirmation(UIImage)

    var id: String {
        switch self {
        case .sourcePicker: return "sourcePicker"
        case .confirmation: return "confirmation"
        }
    }
}

private enum PickerSource { case camera, gallery }

// MARK: - Source Picker Sheet

private struct FMImageSourcePickerSheet: View {
    let config: FMImagePickerFlowConfig
    let onCamera:  () -> Void
    let onGallery: () -> Void
    let onCancel:  () -> Void

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(config.title)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
                Text(config.subtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()

            optionRow(
                icon: "camera.fill",
                title: config.takePhotoTitle,
                subtitle: config.takePhotoSubtitle,
                disabled: !isCameraAvailable,
                action: onCamera
            )

            Divider()

            optionRow(
                icon: "photo.on.rectangle",
                title: config.galleryTitle,
                subtitle: config.gallerySubtitle,
                action: onGallery
            )

            Divider()

            Button(action: onCancel) {
                Text(config.cancelTitle)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        }
        .background(FMColors.background)
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(disabled ? FMColors.onSurfaceVariant : FMColors.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(disabled ? FMColors.surfaceContainerLow : FMColors.primaryContainer)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(disabled ? FMColors.onSurfaceVariant : FMColors.onBackground)
                    Text(subtitle)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            // Inside the label so the plain button's hit area covers the whole
            // row, including the empty gap between the text and the chevron.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Image Confirmation Sheet

private struct FMImageConfirmationSheet: View {
    let image: UIImage
    let config: FMImagePickerFlowConfig
    let onConfirm: () -> Void
    let onCancel:  () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Thumbnail + text
            HStack(spacing: 16) {
                thumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(config.confirmTitle)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onBackground)
                    Text(config.confirmMessage)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 20)

            VStack(spacing: 10) {
                FMPrimaryButton(title: config.confirmButtonTitle, action: onConfirm)

                Button(action: onCancel) {
                    Text(config.cancelTitle)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(FMColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var thumbnail: some View {
        let base = Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 88, height: 88)
        if config.circularPreview {
            base.clipShape(Circle())
        } else {
            base.clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Camera Picker

private struct FMCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FMCameraPicker

        init(_ parent: FMCameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image       = info[.originalImage] as? UIImage
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
