import SwiftUI
import FMDesignSystem
import SharedModels

struct EditGenderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel

    @State private var selectedGender: Gender?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    gendersSection
                    errorSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            FMPrimaryButton(
                title: L10n.Common.save,
                isLoading: isLoading,
                isEnabled: selectedGender != nil
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
                Text(L10n.EditProfile.editGender)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .onAppear {
            selectedGender = userSession.currentUser?.gender
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.EditProfile.editGender)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            Text(L10n.EditProfile.editGenderDesc)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }

    private var gendersSection: some View {
        VStack(spacing: 12) {
            ForEach(Gender.allCases, id: \.self) { gender in
                Button {
                    selectedGender = gender
                } label: {
                    Text(gender.displayName)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(selectedGender == gender ? FMColors.onSecondaryContainer : FMColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(selectedGender == gender ? FMColors.secondaryContainer : FMColors.surfaceContainerLowest)
                        )
                }
            }
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
        guard let gender = selectedGender else { return }
        guard gender != userSession.currentUser?.gender else {
            dismiss()
            return
        }
        isLoading = true
        error = nil

        Task {
            do {
                try await userSession.updateProfile(gender: gender)
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
        EditGenderView()
            .environmentObject(UserSession())
            .environmentObject(HomeViewModel())
    }
}
