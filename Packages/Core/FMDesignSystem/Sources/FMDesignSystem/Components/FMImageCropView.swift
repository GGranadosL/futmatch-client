import SwiftUI
import UIKit

/// Shape of the crop window shown by `FMImageCropView`.
public enum FMImageCropShape {
    /// Square crop shown through a circular mask (avatars).
    case circle
    /// Square crop shown through a rounded-square mask.
    case square
}

/// Full-screen crop step: the user drags and pinches the photo inside a square
/// window, and confirming returns only the part inside that window.
struct FMImageCropView: View {
    let image: UIImage
    let shape: FMImageCropShape
    let title: String
    let hint: String?
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    private let maxZoom: CGFloat = 5
    /// Longest side of the exported image, in pixels.
    private let maxOutputSide: CGFloat = 1080

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width - 32, 1)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(FMTypography.titleMedium)
                        .foregroundColor(.white)
                    if let hint {
                        Text(hint)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                cropArea(side: side, fullWidth: geo.size.width)

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    FMPrimaryButton(title: confirmTitle) {
                        onConfirm(croppedImage(side: side))
                    }
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(FMTypography.labelLarge)
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Crop area

    private func cropArea(side: CGFloat, fullWidth: CGFloat) -> some View {
        let liveZoom = clampedZoom(zoom * pinch)
        let display = displaySize(side: side, zoom: liveZoom)
        let liveOffset = clampedOffset(
            CGSize(width: offset.width + drag.width, height: offset.height + drag.height),
            display: display,
            side: side
        )

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: display.width, height: display.height)
                .offset(liveOffset)

            // Dim everything outside the crop window.
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .mask(
                    ZStack {
                        Rectangle()
                        maskShape(side: side).blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .allowsHitTesting(false)

            maskOutline(side: side)
                .allowsHitTesting(false)
        }
        .frame(width: fullWidth, height: side)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        zoom = clampedZoom(zoom * value)
                        offset = clampedOffset(offset, display: displaySize(side: side, zoom: zoom), side: side)
                    },
                DragGesture()
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        let moved = CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        )
                        offset = clampedOffset(moved, display: displaySize(side: side, zoom: zoom), side: side)
                    }
            )
        )
    }

    @ViewBuilder
    private func maskShape(side: CGFloat) -> some View {
        switch shape {
        case .circle: Circle().frame(width: side, height: side)
        case .square: RoundedRectangle(cornerRadius: 16).frame(width: side, height: side)
        }
    }

    @ViewBuilder
    private func maskOutline(side: CGFloat) -> some View {
        switch shape {
        case .circle:
            Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5).frame(width: side, height: side)
        case .square:
            RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.9), lineWidth: 1.5).frame(width: side, height: side)
        }
    }

    // MARK: - Geometry

    /// Size of the photo on screen. At zoom 1 its shorter side fills the window.
    private func displaySize(side: CGFloat, zoom: CGFloat) -> CGSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
        let fill = side / min(size.width, size.height)
        return CGSize(width: size.width * fill * zoom, height: size.height * fill * zoom)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), maxZoom)
    }

    /// Keeps the photo covering the whole crop window — no empty edges.
    private func clampedOffset(_ value: CGSize, display: CGSize, side: CGFloat) -> CGSize {
        let maxX = max((display.width - side) / 2, 0)
        let maxY = max((display.height - side) / 2, 0)
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }

    // MARK: - Export

    /// Renders only what is inside the crop window. Drawing through
    /// `UIImage.draw(in:)` also bakes in the orientation of camera photos.
    private func croppedImage(side: CGFloat) -> UIImage {
        let display = displaySize(side: side, zoom: zoom)
        let finalOffset = clampedOffset(offset, display: display, side: side)

        // Source pixels covered by the window, capped so uploads stay small.
        let pointsPerScreenPoint = image.size.width / display.width
        let sourcePixels = side * pointsPerScreenPoint * image.scale
        let outputSide = max(min(sourcePixels, maxOutputSide).rounded(), 1)
        let factor = outputSide / side

        let origin = CGPoint(
            x: (side - display.width) / 2 + finalOffset.width,
            y: (side - display.height) / 2 + finalOffset.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(
                x: origin.x * factor,
                y: origin.y * factor,
                width: display.width * factor,
                height: display.height * factor
            ))
        }
    }
}
