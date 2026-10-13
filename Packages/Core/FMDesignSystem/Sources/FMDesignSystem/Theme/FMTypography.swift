import SwiftUI

// MARK: - Typography (Montserrat)
// Based on Material 3 Typography scale
public struct FMTypography {
    
    // MARK: - Display
    public static let displayLarge = Font.montserrat(size: 57)
    public static let displayMedium = Font.montserrat(size: 45)
    public static let displaySmall = Font.montserrat(size: 36)
    
    // MARK: - Headline
    public static let headlineLarge = Font.montserrat(size: 32)
    public static let headlineMedium = Font.montserrat(size: 28)
    public static let headlineSmall = Font.montserrat(size: 24)
    
    // MARK: - Title
    public static let titleLarge = Font.montserrat(size: 22)
    public static let titleMedium = Font.montserratMedium(size: 16)
    public static let titleSmall = Font.montserratMedium(size: 14)
    
    // MARK: - Body
    public static let bodyLarge = Font.montserrat(size: 16)
    public static let bodyMedium = Font.montserrat(size: 14)
    public static let bodySmall = Font.montserrat(size: 12)
    
    // MARK: - Label
    public static let labelLarge = Font.montserratMedium(size: 14)
    public static let labelMedium = Font.montserratMedium(size: 12)
    public static let labelSmall = Font.montserratMedium(size: 11)
    
    // MARK: - Semantic Aliases (for convenience)
    public static let title = headlineMedium
    public static let title2 = titleLarge
    public static let title3 = headlineSmall
    public static let caption = bodyMedium
    public static let captionMedium = Font.montserratMedium(size: 14)
    public static let smallCaption = bodySmall
    public static let button = Font.montserratSemiBold(size: 16)
    public static let label = labelMedium
    public static let inputText = bodyLarge
}
