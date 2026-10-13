import SwiftUI
import UIKit

/// Decorative jersey drawn with a vector path (ported from the Android `TeamIdentityLabel`
/// Canvas, 24x24 viewBox) so both platforms render the same shape.
public struct FMTeamJersey: View {
    private let color: Color
    private let size: CGFloat

    public init(color: Color, size: CGFloat = 20) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 24
            let silhouette = Self.silhouette.applying(CGAffineTransform(scaleX: scale, y: scale))
            let isLight = Self.luminance(of: color) > 0.5

            context.fill(silhouette, with: .color(color))

            // Subtle darker side panel adds depth without changing the team color.
            let panel = Path(CGRect(x: 14.5, y: 10, width: 3, height: 11))
                .applying(CGAffineTransform(scaleX: scale, y: scale))
            context.fill(panel, with: .color(Self.darkened(color, by: 0.12)))

            context.stroke(
                silhouette,
                with: .color(FMColors.outline),
                style: StrokeStyle(lineWidth: 0.85 * scale, lineJoin: .round)
            )

            let seam: Color = isLight ? Color.black.opacity(0.25) : Color.white.opacity(0.45)

            var collar = Path()
            collar.move(to: CGPoint(x: 8, y: 3))
            collar.addCurve(
                to: CGPoint(x: 16, y: 3),
                control1: CGPoint(x: 9, y: 6.5),
                control2: CGPoint(x: 15, y: 6.5)
            )
            context.stroke(
                collar.applying(CGAffineTransform(scaleX: scale, y: scale)),
                with: .color(seam),
                style: StrokeStyle(lineWidth: 1.2 * scale)
            )

            var hem = Path()
            hem.move(to: CGPoint(x: 8, y: 18.5))
            hem.addLine(to: CGPoint(x: 16, y: 18.5))
            context.stroke(
                hem.applying(CGAffineTransform(scaleX: scale, y: scale)),
                with: .color(seam),
                style: StrokeStyle(lineWidth: 0.7 * scale)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Geometry

    private static let silhouette: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 8, y: 3))
        path.addLine(to: CGPoint(x: 3, y: 5.5))
        path.addLine(to: CGPoint(x: 1, y: 10.5))
        path.addLine(to: CGPoint(x: 5, y: 12))
        path.addLine(to: CGPoint(x: 6.5, y: 9.5))
        path.addLine(to: CGPoint(x: 6.5, y: 21))
        path.addLine(to: CGPoint(x: 17.5, y: 21))
        path.addLine(to: CGPoint(x: 17.5, y: 9.5))
        path.addLine(to: CGPoint(x: 19, y: 12))
        path.addLine(to: CGPoint(x: 23, y: 10.5))
        path.addLine(to: CGPoint(x: 21, y: 5.5))
        path.addLine(to: CGPoint(x: 16, y: 3))
        path.addCurve(
            to: CGPoint(x: 8, y: 3),
            control1: CGPoint(x: 15, y: 6.5),
            control2: CGPoint(x: 9, y: 6.5)
        )
        path.closeSubpath()
        return path
    }()

    // MARK: - Color helpers

    private static func components(of color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    /// Relative luminance (same weighting Compose's `Color.luminance()` uses).
    static func luminance(of color: Color) -> CGFloat {
        func linear(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let c = components(of: color)
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    private static func darkened(_ color: Color, by amount: CGFloat) -> Color {
        let c = components(of: color)
        let k = 1 - amount
        return Color(.sRGB, red: Double(c.r * k), green: Double(c.g * k), blue: Double(c.b * k), opacity: 1)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(["#315DA8", "#E8E5DE", "#B43C4A", "#292D34"], id: \.self) { hex in
            FMTeamJersey(color: Color(fmHex: hex) ?? .gray, size: 40)
        }
    }
    .padding()
}
