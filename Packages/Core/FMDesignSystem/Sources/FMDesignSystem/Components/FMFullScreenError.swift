import SwiftUI

/// Full-screen error state shown when a screen has no cached content and its
/// load failed. Displays an icon, title, message, and a retry button.
public struct FMFullScreenError: View {
    private let title: String
    private let message: String
    private let retryTitle: String
    private let onRetry: () -> Void

    public init(
        title: String,
        message: String,
        retryTitle: String,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 64, weight: .regular))
                .foregroundColor(FMColors.error)
                .padding(.bottom, 24)

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
                .padding(.top, 8)

            Button(action: onRetry) {
                Text(retryTitle)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMColors.primary)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background)
    }
}
