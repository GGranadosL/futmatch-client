import SwiftUI
import CoreText

// MARK: - Font Registration
public enum FMFonts {
    /// Registers custom fonts from the bundle. Call this once at app launch.
    public static func registerFonts() {
        let fontNames = [
            "Montserrat-Regular",
            "Montserrat-Medium",
            "Montserrat-SemiBold",
            "Montserrat-Bold"
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

// MARK: - Montserrat Font Extension
public extension Font {
    /// Montserrat Regular
    static func montserrat(size: CGFloat) -> Font {
        .custom("Montserrat-Regular", size: size)
    }
    
    /// Montserrat Medium
    static func montserratMedium(size: CGFloat) -> Font {
        .custom("Montserrat-Medium", size: size)
    }
    
    /// Montserrat SemiBold
    static func montserratSemiBold(size: CGFloat) -> Font {
        .custom("Montserrat-SemiBold", size: size)
    }
    
    /// Montserrat Bold
    static func montserratBold(size: CGFloat) -> Font {
        .custom("Montserrat-Bold", size: size)
    }
}
