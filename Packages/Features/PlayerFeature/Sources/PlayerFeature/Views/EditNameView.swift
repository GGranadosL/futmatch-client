import SwiftUI
import FMDesignSystem
import SharedModels

struct EditNameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    fieldsSection
                    errorSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            FMPrimaryButton(
                title: L10n.Common.save,
                isLoading: isLoading,
                isEnabled: !firstName.trimmingCharacters(in: .whitespaces).isEmpty && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                saveChanges()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(FMColors.background)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(L10n.EditProfile.editName)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .onAppear {
            firstName = userSession.currentUser?.name ?? ""
            lastName = userSession.currentUser?.lastName ?? ""
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.EditProfile.editName)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            Text(L10n.EditProfile.editNameDesc)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }

    private var fieldsSection: some View {
        VStack(spacing: 20) {
            FMTextField(
                label: L10n.EditProfile.firstName,
                text: $firstName
            )

            FMTextField(
                label: L10n.EditProfile.lastName,
                text: $lastName
            )
        }
    }

    private var errorSection: some View {
        Group {
            if let error = error {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(FMColors.error)
                    Text(error)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.error)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FMColors.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func saveChanges() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)

        guard trimmedFirst != (userSession.currentUser?.name ?? "") ||
              trimmedLast != (userSession.currentUser?.lastName ?? "") else {
            dismiss()
            return
        }

        isLoading = true
        error = nil

        Task {
            do {
                try await userSession.updateProfile(
                    firstName: trimmedFirst,
                    lastName: trimmedLast
                )
                await homeViewModel.load()
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditNameView()
            .environmentObject(UserSession())
            .environmentObject(HomeViewModel())
    }
}
