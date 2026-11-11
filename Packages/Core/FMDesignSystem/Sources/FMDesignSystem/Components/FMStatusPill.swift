import SwiftUI

/// Small capsule label for a state: "Activo", "Pagado", "Cancelado", "Confiable"…
public struct FMStatusPill: View {
    public enum Tone {
        case success, danger, warning, info, neutral
    }

    private let text: String
    private let tone: Tone

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(FMTypography.labelSmall)
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
            .fixedSize()
    }

    private var foreground: Color {
        switch tone {
        case .success: return Self.successForeground
        case .danger: return FMColors.onErrorContainer
        case .warning: return Self.warningForeground
        case .info: return FMColors.onPrimaryContainer
        case .neutral: return FMColors.onSurfaceVariant
        }
    }

    private var background: Color {
        switch tone {
        case .success: return Self.successBackground
        case .danger: return FMColors.errorContainer
        case .warning: return Self.warningBackground
        case .info: return FMColors.primaryContainer
        case .neutral: return FMColors.surfaceContainerHighest
        }
    }

    private static let successForeground = Color.adaptive(light: "#1E5A1E", dark: "#B6F2AF")
    private static let successBackground = Color.adaptive(light: "#D8F2D3", dark: "#1F3D1E")
    private static let warningForeground = Color.adaptive(light: "#6B4500", dark: "#FFDDB0")
    private static let warningBackground = Color.adaptive(light: "#FFE7C2", dark: "#4A3200")
}
