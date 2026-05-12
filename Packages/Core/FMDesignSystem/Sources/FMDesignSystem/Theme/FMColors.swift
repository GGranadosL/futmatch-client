import SwiftUI
import UIKit

// MARK: - FutMatch Colors (Material 3 Color Scheme)
public struct FMColors {
    
    // MARK: - Primary
    public static let primary = Color.adaptive(light: "#3E5F90", dark: "#A7C8FF")
    public static let onPrimary = Color.adaptive(light: "#FFFFFF", dark: "#03305F")
    public static let primaryContainer = Color.adaptive(light: "#D5E3FF", dark: "#244777")
    public static let onPrimaryContainer = Color.adaptive(light: "#244777", dark: "#D5E3FF")
    
    // MARK: - Secondary
    public static let secondary = Color.adaptive(light: "#30628C", dark: "#9CCBFB")
    public static let onSecondary = Color.adaptive(light: "#FFFFFF", dark: "#003354")
    public static let secondaryContainer = Color.adaptive(light: "#CFE5FF", dark: "#104A73")
    public static let onSecondaryContainer = Color.adaptive(light: "#104A73", dark: "#CFE5FF")
    
    // MARK: - Tertiary
    public static let tertiary = Color.adaptive(light: "#6B538C", dark: "#D7BAFB")
    public static let onTertiary = Color.adaptive(light: "#FFFFFF", dark: "#3C255A")
    public static let tertiaryContainer = Color.adaptive(light: "#EDDCFF", dark: "#533B72")
    public static let onTertiaryContainer = Color.adaptive(light: "#533B72", dark: "#EDDCFF")
    
    // MARK: - Error
    public static let error = Color.adaptive(light: "#904A49", dark: "#FFB3B1")
    public static let onError = Color.adaptive(light: "#FFFFFF", dark: "#571D1F")
    public static let errorContainer = Color.adaptive(light: "#FFDAD8", dark: "#733333")
    public static let onErrorContainer = Color.adaptive(light: "#733333", dark: "#FFDAD8")
    
    // MARK: - Background
    public static let background = Color.adaptive(light: "#F9F9FF", dark: "#111318")
    public static let onBackground = Color.adaptive(light: "#191C20", dark: "#E1E2E9")
    
    // MARK: - Surface
    public static let surface = Color.adaptive(light: "#F6FAFE", dark: "#0F1417")
    public static let onSurface = Color.adaptive(light: "#171C1F", dark: "#DFE3E7")
    public static let surfaceVariant = Color.adaptive(light: "#DEE3EB", dark: "#42474E")
    public static let onSurfaceVariant = Color.adaptive(light: "#42474E", dark: "#C2C7CF")
    
    // MARK: - Surface Containers
    public static let surfaceDim = Color.adaptive(light: "#D6DADE", dark: "#0F1417")
    public static let surfaceBright = Color.adaptive(light: "#F6FAFE", dark: "#353A3D")
    public static let surfaceContainerLowest = Color.adaptive(light: "#FFFFFF", dark: "#0A0F12")
    public static let surfaceContainerLow = Color.adaptive(light: "#F0F4F8", dark: "#171C1F")
    public static let surfaceContainer = Color.adaptive(light: "#EAEEF2", dark: "#1B2023")
    public static let surfaceContainerHigh = Color.adaptive(light: "#E5E9ED", dark: "#262B2E")
    public static let surfaceContainerHighest = Color.adaptive(light: "#DFE3E7", dark: "#313539")
    
    // MARK: - Outline
    public static let outline = Color.adaptive(light: "#72787F", dark: "#8C9198")
    public static let outlineVariant = Color.adaptive(light: "#C2C7CF", dark: "#42474E")
    
    // MARK: - Fixed Colors
    public static let secondaryFixed = Color.adaptive(light: "#CFE5FF", dark: "#CFE5FF")
    public static let onSecondaryFixed = Color.adaptive(light: "#001D33", dark: "#001D33")
    
    // MARK: - Inverse
    public static let inverseSurface = Color.adaptive(light: "#2C3134", dark: "#DFE3E7")
    public static let inverseOnSurface = Color.adaptive(light: "#EDF1F5", dark: "#2C3134")
    public static let inversePrimary = Color.adaptive(light: "#A7C8FF", dark: "#3E5F90")
    
    // MARK: - Scrim
    public static let scrim = Color.adaptive(light: "#000000", dark: "#000000")
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Creates an adaptive color that automatically adjusts for light/dark mode
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(Color(hex: dark))
            default:
                return UIColor(Color(hex: light))
            }
        })
    }
}
