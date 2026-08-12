import SwiftUI
import UIKit
import FMDesignSystem

// MARK: - DesktopEnrollmentScannerView

/// Full-screen QR scanner used by an administrator to authorize a Futmatch
/// Desktop installation.
///
/// Scanning never approves anything on its own: a scan only fetches the
/// enrollment details, which are then shown for explicit confirmation.
struct DesktopEnrollmentScannerView: View {
    @StateObject private var viewModel: DesktopEnrollmentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cameraStatus: FMCameraAuthorizationStatus = .undetermined
    @State private var showErrorToast = false
    @State private var showSuccessToast = false

    init(viewModel: @autoclosure @escaping () -> DesktopEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraStatus == .denied {
                cameraDeniedState
            } else {
                scanner
            }

            closeButton
        }
        .sheet(isPresented: confirmationBinding) {
            if let enrollment = viewModel.state.enrollment {
                DesktopEnrollmentConfirmationSheet(
                    details: enrollment.details,
                    isLoading: viewModel.state.isApproving,
                    errorMessage: viewModel.sheetErrorMessage,
                    onAuthorize: { Task { await viewModel.approve() } },
                    onCancel: { viewModel.cancelConfirmation() }
                )
            }
        }
        .onChange(of: viewModel.errorMessage) { message in
            guard message != nil else { return }
            showErrorToast = true
        }
        .onChange(of: viewModel.didApprove) { didApprove in
            guard didApprove else { return }
            // Close the sheet first, then let the toast play on this screen
            // before it goes away — dismissing instantly would hide it.
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                dismiss()
            }
        }
        .fmToast(viewModel.errorMessage ?? "", isPresented: $showErrorToast, style: .error)
        .fmToast(L10n.DesktopEnrollment.successMessage, isPresented: $showSuccessToast, style: .success)
    }

    /// Drops the sheet as soon as approval lands so the success toast is visible.
    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isShowingConfirmation && !viewModel.didApprove },
            set: { isPresented in
                // Fires on swipe-to-dismiss too, which must not approve anything.
                if !isPresented { viewModel.cancelConfirmation() }
            }
        )
    }

    // MARK: - Scanner

    private static let frameSize: CGFloat = 240
    private static let frameCornerRadius: CGFloat = 24

    /// `GeometryReader` + explicit `.position()` keeps every layer — camera,
    /// dim overlay, viewfinder, text — anchored to the *same* full-bleed
    /// coordinate space. Mixing `ignoresSafeArea()` children with plain ones in
    /// a bare `ZStack` lets each layer compute its own center independently,
    /// which is what previously made the dim overlay's cut-out drift from the
    /// viewfinder and left an undimmed strip behind the status bar.
    private var scanner: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                FMQRScannerView(
                    isPaused: viewModel.state.isBusy,
                    onScan: { payload in Task { await viewModel.handleScan(payload) } },
                    onAuthorizationChange: { cameraStatus = $0 }
                )

                dimOverlay(canvasSize: proxy.size, holeCenter: center)

                ZStack {
                    FMQRScannerFrame(size: Self.frameSize)
                    if viewModel.state == .loadingDetails {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                    }
                }
                .position(center)

                VStack(spacing: 8) {
                    Text(L10n.DesktopEnrollment.scanTitle)
                        .font(FMTypography.titleLarge)
                        .foregroundColor(.white)
                    Text(L10n.DesktopEnrollment.scanInstruction)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 40)
                .frame(width: proxy.size.width)
                .position(x: center.x, y: center.y + Self.frameSize / 2 + 56)
            }
        }
        .ignoresSafeArea()
    }

    /// Paints the full screen at 45% black, then cuts a rounded-rect hole at
    /// `holeCenter` using an even-odd fill — a `Canvas` fill rule instead of
    /// `.mask`/`blendMode`, so the hole is defined in the exact same
    /// full-bleed coordinate space as everything else in `scanner`.
    private func dimOverlay(canvasSize: CGSize, holeCenter: CGPoint) -> some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            let hole = CGRect(
                x: holeCenter.x - Self.frameSize / 2,
                y: holeCenter.y - Self.frameSize / 2,
                width: Self.frameSize,
                height: Self.frameSize
            )
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: Self.frameCornerRadius, height: Self.frameCornerRadius))
            context.fill(path, with: .color(.black.opacity(0.45)), style: FillStyle(eoFill: true))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }

    // MARK: - Camera Denied

    private var cameraDeniedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                Text(L10n.DesktopEnrollment.cameraDeniedTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(.white)
                Text(L10n.DesktopEnrollment.cameraDeniedMessage)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text(L10n.DesktopEnrollment.openSettings)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 50)
                    .background(Capsule().fill(FMColors.primary))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Close

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
