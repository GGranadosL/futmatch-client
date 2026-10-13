import SwiftUI

/// Readable team name accompanied by a decorative jersey in the team color.
/// The jersey is omitted when the color is missing or cannot be parsed; the name
/// is never tinted so it stays legible for white/black/low-contrast colors.
public struct FMTeamIdentityLabel: View {
    private let name: String
    private let colorHex: String?
    private let font: Font

    public init(name: String, colorHex: String?, font: Font = FMTypography.labelMedium) {
        self.name = name
        self.colorHex = colorHex
        self.font = font
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let colorHex, let color = Color(fmHex: colorHex) {
                FMTeamJersey(color: color)
            }
            Text(name)
                .font(font)
                .fontWeight(.semibold)
                .foregroundColor(FMColors.onSurface)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FMTeamIdentityLabel(name: "All Blacks", colorHex: "#292D34")
        FMTeamIdentityLabel(name: "Los Blancos", colorHex: "#E8E5DE")
        FMTeamIdentityLabel(name: "Equipo A", colorHex: nil)
    }
    .padding()
}
