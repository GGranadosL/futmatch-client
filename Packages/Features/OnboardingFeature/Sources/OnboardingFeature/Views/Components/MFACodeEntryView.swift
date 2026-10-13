import SwiftUI
import FMDesignSystem

/// The one emailed-code screen, shared by every flow that verifies one: login MFA,
/// registration, password recovery and social account linking.
///
/// Takes plain values and closures rather than an `ObservableObject`, so it is not
/// tied to any one ViewModel — that coupling is what produced four near-identical
/// copies of this screen, each with its own subtly different timer.
///
/// It owns the 1 Hz tick; the caller owns the dates. Everything shown is derived
/// from `window`'s absolute dates and the current time, so the countdown is right
/// after the app has been backgrounded, and a code that expired while the app was
/// away is expired the moment the screen comes back.
struct MFACodeEntryView<Footer: View>: View {
    @Environment(\.scenePhase) private var scenePhase

    let iconSystemName: String
    let title: String
    let subtitle: String
    /// Address the code was sent to, shown in a chip. `nil` hides it — the linking
    /// flow must not reveal the existing account's email.
    let email: String?
    @Binding var code: String
    let isLoading: Bool
    let verifyButtonTitle: String
    /// Backend-reported countdowns. `nil` while no code has been issued yet.
    let window: MFACodeWindow?
    let onVerify: () -> Void
    let onResend: () -> Void
    @ViewBuilder let footer: () -> Footer

    private let codeLength = 6

    /// Re-read every tick; the whole view is a function of this and `window`.
    @State private var now = Date()
    @State private var timer: Timer?

    init(
        iconSystemName: String = "lock.shield",
        title: String,
        subtitle: String,
        email: String? = nil,
        code: Binding<String>,
        isLoading: Bool,
        verifyButtonTitle: String,
        window: MFACodeWindow?,
        onVerify: @escaping () -> Void,
        onResend: @escaping () -> Void,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.subtitle = subtitle
        self.email = email
        self._code = code
        self.isLoading = isLoading
        self.verifyButtonTitle = verifyButtonTitle
        self.window = window
        self.onVerify = onVerify
        self.onResend = onResend
        self.footer = footer
    }

    private var isCodeExpired: Bool { window?.isCodeExpired(at: now) ?? false }
    /// With no window the deadlines are unknown, so nothing is blocked — the screen
    /// must never end up with an unusable code and no way to ask for another.
    private var canResend: Bool { window?.canResend(at: now) ?? true }
    private var secondsUntilResend: Int { window?.secondsUntilResend(at: now) ?? 0 }

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
        .onAppear {
            now = Date()
            startTicking()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: window) { _ in
            // A resend replaces both deadlines; restart the tick in case it had
            // stopped because the previous code was already dead.
            now = Date()
            startTicking()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Nothing ticked while the app was away; recompute from the clock
                // rather than resuming a counter that stopped mid-countdown.
                now = Date()
                startTicking()
            } else {
                timer?.invalidate()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: iconSystemName)
                .font(.system(size: 60))
                .foregroundColor(FMColors.primary)

            Text(title)
                .font(FMTypography.title)
                .foregroundColor(FMColors.onSurface)

            Text(subtitle)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            if let email {
                emailChip(email)
            }

            footer()
        }
    }

    /// The address the code was sent to, boxed so it reads as a value to double-check
    /// rather than as a tail of the subtitle above it. A mistyped domain that still
    /// passes email validation (`gmial.com`, `gmail.con`) is the common failure here,
    /// and this is the last point where the user can catch it.
    private func emailChip(_ email: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(FMColors.primary)

            Text(email)
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

    private var codeInputSection: some View {
        FMCodeInputField(code: $code, codeLength: codeLength) { _ in
            guard !isCodeExpired else { return }
            onVerify()
        }
        .disabled(isCodeExpired)
        .opacity(isCodeExpired ? 0.4 : 1)
        .padding(.top, 24)
    }

    private var resendSection: some View {
        VStack(spacing: 8) {
            if isCodeExpired {
                Text(L10n.MFA.codeExpired)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.error)
                    .multilineTextAlignment(.center)
            }

            if canResend {
                Button {
                    onResend()
                } label: {
                    Text(isCodeExpired ? L10n.MFA.requestNewCode : L10n.Verification.resend)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                        .contentShape(Rectangle())
                }
                .disabled(isLoading)
            } else {
                Text(L10n.Verification.resendIn(secondsUntilResend))
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
        .padding(.top, 16)
    }

    private var bottomSection: some View {
        FMPrimaryButton(
            title: verifyButtonTitle,
            isLoading: isLoading,
            isEnabled: code.count == codeLength && !isCodeExpired
        ) {
            onVerify()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 16)
    }

    // MARK: - Timer

    /// Ticks only while something is still counting down. Once the code has expired
    /// and the resend is unlocked, nothing on screen changes with time.
    private func startTicking() {
        timer?.invalidate()
        guard window != nil, !(isCodeExpired && canResend) else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                now = Date()
                if isCodeExpired && canResend {
                    timer?.invalidate()
                }
            }
        }
    }
}
