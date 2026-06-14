import SwiftUI
import CoreText

// MARK: - Font Registration
public enum FMFonts {
    /// Registers custom fonts from the bundle. Call this once at app launch.
    public static func registerFonts() {
        let fontNames = [
            "Inter-Regular",
            "Inter-Medium",
            "Inter-SemiBold",
            "Inter-Bold"
        ]
        
        for fontName in fontNames {
            registerFont(named: fontName, extension: "ttf")
        }
    }
    
    private static func registerFont(named name: String, extension ext: String) {
        guard let fontURL = Bundle.module.url(forResource: name, withExtension: ext),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            return
        }

        // Registration can fail if the font is already registered — that's OK.
        var error: Unmanaged<CFError>?
        _ = CTFontManagerRegisterGraphicsFont(font, &error)
    }
}

// MARK: - Inter Font Extension
public extension Font {
    /// Inter Regular
    static func inter(size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }
    
    /// Inter Medium
    static func interMedium(size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }
    
    /// Inter SemiBold
    static func interSemiBold(size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }
    
    /// Inter Bold
    static func interBold(size: CGFloat) -> Font {
        .custom("Inter-Bold", size: size)
    }
}
