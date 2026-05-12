import SwiftUI
import UIKit
import FMDesignSystem
import SharedModels

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

// MARK: - EditProfileRow Model

private struct EditProfileRow: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
}

// MARK: - EditProfileView

/// Edit profile screen showing avatar, description, and editable user fields.
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel

    @State private var selectedImage: UIImage?
    @State private var showImageSourceSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    @State private var uploadError: String?

    private var user: User? { userSession.currentUser }

    private var profilePicURL: URL? {
        if let urlStr = homeViewModel.profileImageUrl, let url = URL(string: urlStr) {
            return url
        }
        return user?.profilePicURL
    }

    // MARK: - Row Data

    private var rows: [EditProfileRow] {
        [
            EditProfileRow(
                icon: "pencil",
                iconColor: FMColors.primary,
                title: L10n.EditProfile.name,
                value: user?.fullName ?? "—"
            ),
            EditProfileRow(
                icon: "envelope",
                iconColor: FMColors.primary,
                title: L10n.EditProfile.email,
                value: user?.email ?? "—"
            ),
            EditProfileRow(
                icon: "globe.americas",
                iconColor: FMColors.primary,
                title: L10n.EditProfile.country,
                value: user?.country ?? "—"
            ),
            EditProfileRow(
                icon: "person",
                iconColor: FMColors.primary,
                title: L10n.EditProfile.gender,
                value: user?.gender.displayName ?? "—"
            ),
            EditProfileRow(
                icon: "sportscourt",
                iconColor: FMColors.primary,
                title: L10n.EditProfile.mainPosition,
                value: user?.playerPosition.displayName ?? "—"
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    descriptionSection
                    rowsSection
                }
                .padding(.bottom, 40)
            }
        }
        .background(FMColors.background)
        .navigationBarHidden(true)
        .confirmationDialog(
            L10n.EditProfile.editAvatar,
            isPresented: $showImageSourceSheet,
            titleVisibility: .visible
        ) {
            Button(L10n.EditProfile.takePhoto) {
                imagePickerSource = .camera
                showImagePicker = true
            }
            Button(L10n.EditProfile.chooseFromGallery) {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }
            Button(L10n.EditProfile.cancel, role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSource) { uiImage in
                selectedImage = uiImage
                uploadProfilePic(uiImage)
            }
            .ignoresSafeArea()
        }
        .alert(L10n.EditProfile.uploadError, isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let uploadError {
                Text(uploadError)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Text(L10n.EditProfile.title)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onBackground)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Circle().fill(.white))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack {
                FMAvatar(
                    image: selectedImage.map { Image(uiImage: $0) },
                    url: selectedImage == nil ? profilePicURL : nil,
                    defaultImageName: user?.gender.defaultAvatarAssetName,
                    size: 100,
                    showCameraBadge: false
                )
                .overlay(
                    Circle()
                        .stroke(FMColors.outlineVariant, lineWidth: 2)
                )

                if isUploadingImage {
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 100, height: 100)
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                showImageSourceSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(L10n.EditProfile.editAvatar)
                        .font(FMTypography.labelLarge)
                }
                .foregroundColor(FMColors.onTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(FMColors.tertiary)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Text(L10n.EditProfile.description)
            .font(FMTypography.bodyMedium)
            .foregroundColor(FMColors.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    // MARK: - Rows Section

    private var rowsSection: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                profileRowView(row)

                if row.id != rows.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Row View

    private func profileRowView(_ row: EditProfileRow) -> some View {
        Button {
            // TODO: Navigate to row edit
        } label: {
            HStack(spacing: 14) {
                Image(systemName: row.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(row.iconColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)

                    Text(row.value)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurface)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FMColors.outline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Upload Profile Pic

    private func uploadProfilePic(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isUploadingImage = true
        uploadError = nil
        Task {
            do {
                try await userSession.uploadProfilePic(imageData: data)
                await homeViewModel.load()
            } catch {
                uploadError = error.localizedDescription
            }
            isUploadingImage = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(UserSession())
            .environmentObject(HomeViewModel())
    }
}
