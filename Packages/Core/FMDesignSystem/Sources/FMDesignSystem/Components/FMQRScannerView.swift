import AVFoundation
import SwiftUI
import UIKit

// MARK: - FMCameraAuthorizationStatus

/// Camera permission as the scanner sees it, collapsed to the three cases a
/// caller actually renders differently.
public enum FMCameraAuthorizationStatus: Equatable {
    /// Still asking the user, or waiting for the first authorization check.
    case undetermined
    case authorized
    /// Denied or restricted — only recoverable through Settings.
    case denied
}

// MARK: - FMQRScannerView

/// Live camera preview that reports the payload of any QR code it sees.
///
/// The view owns nothing beyond the capture session: it does not decide what a
/// payload means, show errors, or dismiss itself. Callers pause it (`isPaused`)
/// while they process a scan so a code lingering in frame can't fire twice.
///
/// ```swift
/// FMQRScannerView(isPaused: viewModel.isBusy) { payload in
///     viewModel.handleScan(payload)
/// } onAuthorizationChange: { status in
///     cameraStatus = status
/// }
/// ```
public struct FMQRScannerView: UIViewControllerRepresentable {

    private let isPaused: Bool
    private let onScan: (String) -> Void
    private let onAuthorizationChange: (FMCameraAuthorizationStatus) -> Void

    public init(
        isPaused: Bool,
        onScan: @escaping (String) -> Void,
        onAuthorizationChange: @escaping (FMCameraAuthorizationStatus) -> Void = { _ in }
    ) {
        self.isPaused = isPaused
        self.onScan = onScan
        self.onAuthorizationChange = onAuthorizationChange
    }

    public func makeUIViewController(context: Context) -> FMQRScannerViewController {
        let controller = FMQRScannerViewController()
        controller.onScan = onScan
        controller.onAuthorizationChange = onAuthorizationChange
        return controller
    }

    public func updateUIViewController(_ uiViewController: FMQRScannerViewController, context: Context) {
        // Closures are re-created on every SwiftUI update; refresh them so they
        // never capture a stale view-model reference.
        uiViewController.onScan = onScan
        uiViewController.onAuthorizationChange = onAuthorizationChange
        uiViewController.setPaused(isPaused)
    }

    public static func dismantleUIViewController(
        _ uiViewController: FMQRScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopSession()
    }
}

// MARK: - FMQRScannerViewController

/// UIKit host for the `AVCaptureSession`. Public only because
/// `UIViewControllerRepresentable` requires its view-controller type to be as
/// visible as the representable itself.
public final class FMQRScannerViewController: UIViewController {

    var onScan: ((String) -> Void)?
    var onAuthorizationChange: ((FMCameraAuthorizationStatus) -> Void)?

    private let session = AVCaptureSession()
    /// `startRunning()` blocks for a noticeable beat, so all session lifecycle
    /// work happens off the main queue.
    private let sessionQueue = DispatchQueue(label: "com.futmatch.qrscanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var isPaused = false

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAuthorization()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onAuthorizationChange?(.authorized)
            configureAndStart()
        case .notDetermined:
            onAuthorizationChange?(.undetermined)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.onAuthorizationChange?(granted ? .authorized : .denied)
                    if granted { self.configureAndStart() }
                }
            }
        default:
            onAuthorizationChange?(.denied)
        }
    }

    // MARK: - Session

    private func configureAndStart() {
        guard !isConfigured else {
            startSession()
            return
        }
        isConfigured = true

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        session.commitConfiguration()

        // Must be set after the output is attached, otherwise `.qr` is not yet
        // an available type and AVFoundation raises.
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        startSession()
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setPaused(_ paused: Bool) {
        // Only gates the delegate callback — the preview keeps running so the
        // camera doesn't visibly freeze while a request is in flight.
        isPaused = paused
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension FMQRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isPaused else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let payload = object.stringValue
        else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(payload)
    }
}

// MARK: - FMQRScannerFrame

/// Corner-bracket viewfinder drawn over the camera preview.
public struct FMQRScannerFrame: View {

    private let size: CGFloat
    private let cornerLength: CGFloat = 32
    private let lineWidth: CGFloat = 4

    public init(size: CGFloat = 240) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)

            ForEach(Corner.allCases, id: \.self) { corner in
                bracket
                    .rotationEffect(corner.rotation)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
            }
        }
        .frame(width: size, height: size)
    }

    private var bracket: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: cornerLength))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: cornerLength, y: 0))
        }
        .stroke(FMColors.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .frame(width: cornerLength, height: cornerLength)
    }

    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomTrailing, bottomLeading

        var rotation: Angle {
            switch self {
            case .topLeading:     return .degrees(0)
            case .topTrailing:    return .degrees(90)
            case .bottomTrailing: return .degrees(180)
            case .bottomLeading:  return .degrees(270)
            }
        }

        var alignment: Alignment {
            switch self {
            case .topLeading:     return .topLeading
            case .topTrailing:    return .topTrailing
            case .bottomTrailing: return .bottomTrailing
            case .bottomLeading:  return .bottomLeading
            }
        }
    }
}
