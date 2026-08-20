import SwiftUI
import FMDesignSystem

/// MFA Verification View - for login flow
struct MFAVerificationView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var onVerificationSuccess: (() -> Void)?
    /// Pops back to the login form with the email field focused. The resend endpoint
    /// is keyed by `mfaChallengeToken`, so a mistyped address can only be fixed by
    /// re-running login — this is the affordance that tells the user so.
    var onChangeEmail: (() -> Void)?

    @State private var countdown: Int = 60
    /// Absolute expiry date — source of truth for the countdown, survives background/relaunch.
    @State private var countdownExpiry: Date
    @State private var timer: Timer?

    init(
        viewModel: LoginViewModel,
        onVerificationSuccess: (() -> Void)? = nil,
        onChangeEmail: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onVerificationSuccess = onVerificationSuccess
        self.onChangeEmail = onChangeEmail
        let seconds = viewModel.resendCodeTimeInSeconds
        self._countdown = State(initialValue: seconds)
        self._countdownExpiry = State(initialValue: Date().addingTimeInterval(Double(seconds)))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    codeInputSection
                    resendSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            
            bottomSection
        }
        .background(FMColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(FMColors.onSurface)
                }
            }
        }
        .onAppear {
            refreshCountdown()
            startTicking()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshCountdown()
                startTicking()
            } else {
                timer?.invalidate()
            }
        }
        .onChange(of: viewModel.isLoginSuccessful) { newValue in
            if newValue {
                onVerificationSuccess?()
            }
        }
        .onChange(of: viewModel.showError) { isShowingError in
            // Clear the entered code on error so the user isn't stuck deleting a stale/invalid code by hand.
            if isShowingError {
                viewModel.verificationCode = ""
            }
        }
        .alert(L10n.Login.errorTitle, isPresented: $viewModel.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(FMColors.primary)
            
            Text(L10n.MFA.title)
                .font(FMTypography.title)
                .foregroundColor(FMColors.onSurface)
            
            Text(L10n.MFA.subtitle)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            emailChip

            changeEmailLink
        }
    }

    /// The address the code was sent to, boxed so it reads as a value to double-check
    /// rather than as a tail of the subtitle above it. A mistyped domain that still
    /// passes email validation (`gmial.com`, `gmail.con`) is the common failure here,
    /// and this is the last point where the user can catch it.
    private var emailChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(FMColors.primary)

            Text(viewModel.email)
                .font(FMTypography.titleMedium)
                .foregroundColor(FMColors.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Truncate in the middle so the domain — the half that's usually
                // wrong — stays visible on long addresses.
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(FMColors.surfaceContainerLowest))
        .overlay(Capsule().stroke(FMColors.outlineVariant, lineWidth: 1))
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var changeEmailLink: some View {
        Button {
            onChangeEmail?()
        } label: {
            HStack(spacing: 4) {
                Text(L10n.MFA.wrongEmail)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.onSurfaceVariant)

                Text(L10n.MFA.changeEmail)
                    .font(FMTypography.captionMedium)
                    .foregroundColor(FMColors.primary)
            }
            .contentShape(Rectangle())
        }
    }
    
    private var codeInputSection: some View {
        FMCodeInputField(
            code: $viewModel.verificationCode,
            codeLength: 6
        ) { _ in
            Task { await viewModel.verifyMFACode() }
        }
        .padding(.top, 24)
    }
    
    private var resendSection: some View {
        VStack(spacing: 8) {
            if countdown > 0 {
                Text(L10n.Verification.resendIn(countdown))
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.onSurfaceVariant)
            } else {
                Button {
                    Task {
                        await viewModel.resendMFACode()
                        countdownExpiry = Date().addingTimeInterval(Double(viewModel.resendCodeTimeInSeconds))
                        refreshCountdown()
                        startTicking()
                    }
                } label: {
                    Text(L10n.Verification.resend)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .padding(.top, 16)
    }
    
    private var bottomSection: some View {
        FMPrimaryButton(
            title: L10n.MFA.verify,
            isLoading: viewModel.isLoading,
            isEnabled: viewModel.verificationCode.count == 6
        ) {
            Task {
                await viewModel.verifyMFACode()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 16)
    }
    
    // MARK: - Helpers

    /// Recomputes `countdown` from the stored expiry `Date` rather than trusting the in-memory
    /// value, so the display is correct even after the app was backgrounded or relaunched.
    private func refreshCountdown() {
        let remaining = max(0, Int(countdownExpiry.timeIntervalSinceNow))
        countdown = remaining
        if remaining == 0 {
            timer?.invalidate()
        }
    }

    private func startTicking() {
        timer?.invalidate()
        guard countdown > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            refreshCountdown()
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = LoginViewModel()
    viewModel.email = "jingowork@gmail.com"
    return NavigationStack {
        MFAVerificationView(viewModel: viewModel)
    }
}
