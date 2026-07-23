import SwiftUI
import FMDesignSystem

struct AppGateSoftUpdateView: View {
    let title: String
    let message: String
    let updateButtonLabel: String
    let skipButtonLabel: String
    let storeUrl: String
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundColor(FMColors.primary)
                .padding(.bottom, 32)

            Text(title)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(message)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 12) {
                FMPrimaryButton(title: updateButtonLabel) {
                    openStore()
                }

                FMTextButton(title: skipButtonLabel) {
                    onSkip()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background.ignoresSafeArea())
    }

    private func openStore() {
        guard let url = URL(string: storeUrl) else { return }
        UIApplication.shared.open(url)
    }
}
