import SwiftUI

// MARK: - FutMatch Typography (Inter)
// Based on Material 3 Typography scale
public struct FMTypography {
    
    // MARK: - Display
    public static let displayLarge = Font.inter(size: 57)
    public static let displayMedium = Font.inter(size: 45)
    public static let displaySmall = Font.inter(size: 36)
    
    // MARK: - Headline
    public static let headlineLarge = Font.inter(size: 32)
    public static let headlineMedium = Font.inter(size: 28)
    public static let headlineSmall = Font.inter(size: 24)
    
    // MARK: - Title
    public static let titleLarge = Font.inter(size: 22)
    public static let titleMedium = Font.interMedium(size: 16)
    public static let titleSmall = Font.interMedium(size: 14)
    
    // MARK: - Body
    public static let bodyLarge = Font.inter(size: 16)
    public static let bodyMedium = Font.inter(size: 14)
    public static let bodySmall = Font.inter(size: 12)
    
    // MARK: - Label
    public static let labelLarge = Font.interMedium(size: 14)
    public static let labelMedium = Font.interMedium(size: 12)
    public static let labelSmall = Font.interMedium(size: 11)
    
    // MARK: - Semantic Aliases (for convenience)
    public static let title = headlineMedium
    public static let title2 = titleLarge
    public static let title3 = headlineSmall
    public static let caption = bodyMedium
    public static let captionMedium = Font.interMedium(size: 14)
    public static let smallCaption = bodySmall
    public static let button = Font.interSemiBold(size: 16)
    public static let label = labelMedium
    public static let inputText = bodyLarge
}
