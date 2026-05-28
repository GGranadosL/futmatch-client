import SwiftUI
import UIKit
import FMDesignSystem

// MARK: - UIKit Image Picker

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Step 3: Football Profile
struct OnboardingStep3View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    @State private var showImageSourceSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImagePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                FMOnboardingHeader(
                    title: L10n.Step3.title,
                    subtitle: L10n.Step3.subtitle
                )
                .padding(.top, 24)
                
                // Profile Photo
                VStack(spacing: 12) {
                    ZStack {
                        if let profileImage = viewModel.profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            // Placeholder
                            Circle()
                                .fill(FMColors.background)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(FMColors.secondary)
                        }
                        
                        // Camera badge
                        Circle()
                            .fill(FMColors.primary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 35, y: 35)
                    }
                    .onTapGesture {
                        showImageSourceSheet = true
                    }
                    
                    Text(L10n.Step3.uploadPhoto)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                }
                .padding(.vertical, 16)
                
                // Position Selection — user must explicitly pick one; no default highlight
                FMChipGroupOptional(
                    title: L10n.Step3.mainPosition,
                    options: PositionOption.allCases,
                    selected: $viewModel.playerPosition
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(FMColors.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMPrimaryButton(
                title: L10n.Button.nextStep,
                isEnabled: viewModel.isStep3Valid
            ) {
                viewModel.nextStep()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(FMColors.background)
        }
        .onDisappear {
            // Save draft only when leaving the step
            Task {
                await viewModel.saveDraftIfNeeded()
            }
        }
        .confirmationDialog(
            L10n.Step3.uploadPhoto,
            isPresented: $showImageSourceSheet,
            titleVisibility: .visible
        ) {
            Button(L10n.Step3.takePhoto) {
                imagePickerSource = .camera
                showImagePicker = true
            }
            Button(L10n.Step3.chooseFromGallery) {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }
            Button(L10n.Step3.cancel, role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSource) { uiImage in
                viewModel.profileImage = Image(uiImage: uiImage)
                // Compress to JPEG (0.8 quality) and store for the register request.
                viewModel.profileImageData = uiImage.jpegData(compressionQuality: 0.8)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingStep3View(viewModel: OnboardingViewModel())
}
