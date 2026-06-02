import SwiftUI
import FMDesignSystem
import SharedModels

struct EditPositionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel

    @State private var selectedPosition: PlayerPosition?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.EditProfile.editPosition)
                            .font(FMTypography.titleLarge)
                            .foregroundColor(FMColors.onBackground)

                        Text(L10n.EditProfile.editPositionDesc)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }

                    VStack(spacing: 12) {
                        ForEach(PlayerPosition.allCases, id: \.self) { position in
                            Button {
                                selectedPosition = position
                            } label: {
                                Text(position.displayName)
                                    .font(FMTypography.bodyMedium)
                                    .foregroundColor(selectedPosition == position ? FMColors.onSecondaryContainer : FMColors.onSurfaceVariant)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(selectedPosition == position ? FMColors.secondaryContainer : FMColors.surfaceContainerLowest)
                                    )
                            }
                        }
                    }

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
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            FMPrimaryButton(
                title: L10n.Common.save,
                isLoading: isLoading,
                isEnabled: selectedPosition != nil
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
                Text(L10n.EditProfile.editPosition)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .onAppear {
            selectedPosition = userSession.currentUser?.playerPosition
        }
    }

    private func saveChanges() {
        guard let position = selectedPosition else { return }
        guard position != userSession.currentUser?.playerPosition else {
            dismiss()
            return
        }
        isLoading = true
        error = nil

        Task {
            do {
                try await userSession.updateProfile(playerPosition: position)
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
        EditPositionView()
            .environmentObject(UserSession())
            .environmentObject(HomeViewModel())
    }
}
