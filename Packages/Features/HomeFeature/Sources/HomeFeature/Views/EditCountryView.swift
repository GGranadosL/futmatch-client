import SwiftUI
import FMDesignSystem
import SharedModels

struct EditCountryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var homeViewModel: HomeViewModel

    @State private var selectedCountry: Country?
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var error: String?

    private let countries = Country.fallback

    var filteredCountries: [Country] {
        if searchText.isEmpty {
            return countries
        }
        return countries.filter { country in
            country.name.localizedCaseInsensitiveContains(searchText) ||
            country.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    searchAndCountriesSection
                    errorSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            FMPrimaryButton(
                title: L10n.Common.save,
                isLoading: isLoading,
                isEnabled: selectedCountry != nil
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
                Text(L10n.EditProfile.editCountry)
                    .font(FMTypography.titleMedium)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .onAppear {
            selectedCountry = countries.first { $0.iso == userSession.currentUser?.country }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.EditProfile.editCountry)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            Text(L10n.EditProfile.editCountryDesc)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }

    private var searchAndCountriesSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(FMColors.onSurfaceVariant)

                TextField(L10n.EditProfile.searchCountry, text: $searchText)
                    .font(FMTypography.bodyMedium)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(FMColors.surfaceContainerLowest)
            .cornerRadius(8)

            countriesList
        }
    }

    private var countriesList: some View {
        VStack(spacing: 12) {
            ForEach(filteredCountries) { country in
                Button {
                    selectedCountry = country
                } label: {
                    HStack(spacing: 12) {
                        Text(country.displayName)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onBackground)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if selectedCountry?.iso == country.iso {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(FMColors.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(FMColors.surfaceContainerLowest)
                    .cornerRadius(8)
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
        guard let country = selectedCountry else { return }
        guard country.iso != userSession.currentUser?.country else {
            dismiss()
            return
        }
        isLoading = true
        error = nil

        Task {
            do {
                try await userSession.updateProfile(countryISO: country.iso)
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
        EditCountryView()
            .environmentObject(UserSession())
            .environmentObject(HomeViewModel())
    }
}
