import SwiftUI
import FMDesignSystem

// MARK: - DesktopEnrollmentConfirmationSheet

/// Shows the server-reported identity of the desktop that generated the QR and
/// asks the administrator to authorize it. Nothing is sent until **Authorize**
/// is tapped — dismissing makes no backend request.
struct DesktopEnrollmentConfirmationSheet: View {
    let details: DesktopEnrollmentDetails
    let isLoading: Bool
    let errorMessage: String?
    let onAuthorize: () -> Void
    let onCancel: () -> Void

    /// Measured natural height of the content; drives a self-sizing detent.
    @State private var contentHeight: CGFloat = 0
    @State private var showErrorToast = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FMColors.outlineVariant)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.DesktopEnrollment.confirmTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                Text(L10n.DesktopEnrollment.confirmSubtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 12) {
                detailRow(label: L10n.DesktopEnrollment.deviceLabel, value: details.deviceInfo)
                detailRow(label: L10n.DesktopEnrollment.appVersionLabel, value: details.appVersion)
                detailRow(label: L10n.DesktopEnrollment.osVersionLabel, value: details.osVersion)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            authorizeButton
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Button(action: onCancel) {
                Text(L10n.DesktopEnrollment.cancelButton)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurface)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .padding(.vertical, 16)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: EnrollmentSheetHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(EnrollmentSheetHeightKey.self) { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(FMColors.surfaceContainerLowest.ignoresSafeArea())
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(isLoading)
        .onChange(of: errorMessage) { message in
            guard message != nil else { return }
            showErrorToast = true
        }
        // The toast lives inside the sheet: one attached to the presenter would
        // be hidden underneath it.
        .fmToast(errorMessage ?? "", isPresented: $showErrorToast, style: .error)
    }

    // MARK: - Detail Row

    /// `value` is nil for enrollments made by desktop builds that predate this
    /// metadata — show the localized fallback rather than inventing anything.
    private func detailRow(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FMTypography.labelSmall)
                .foregroundColor(FMColors.onSurfaceVariant)
            Text(value ?? L10n.DesktopEnrollment.notAvailable)
                .font(FMTypography.bodyMedium)
                .foregroundColor(value == nil ? FMColors.onSurfaceVariant : FMColors.onSurface)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Authorize Button

    private var authorizeButton: some View {
        Button(action: onAuthorize) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.DesktopEnrollment.authorizeButton)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(isLoading ? FMColors.primary.opacity(0.6) : FMColors.primary))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - EnrollmentSheetHeightKey

private struct EnrollmentSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#Preview {
    Color.gray
        .sheet(isPresented: .constant(true)) {
            DesktopEnrollmentConfirmationSheet(
                details: DesktopEnrollmentDetails(
                    deviceInfo: "Futmatch Desktop/1.0.0 (macOS 15.6.1; arm64)",
                    appVersion: "1.0.0",
                    osVersion: nil
                ),
                isLoading: false,
                errorMessage: nil,
                onAuthorize: {},
                onCancel: {}
            )
        }
}
