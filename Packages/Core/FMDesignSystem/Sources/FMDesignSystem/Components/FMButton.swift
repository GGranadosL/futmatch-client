import SwiftUI

/// Primary Button - FutMatch Style
public struct FMPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    public init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(FMTypography.button)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    // Material Design 3 disabled state: onSurface @ 12 % opacity.
                    // This produces a clearly inert grey instead of the very-similar
                    // secondary blue, so the user can tell at a glance that the
                    // button is unavailable.
                    .fill(isEnabled ? FMColors.primary : FMColors.onSurface.opacity(0.12))
            )
            // Disabled text: onSurface @ 38 % opacity (also per MD3).
            .foregroundColor(isEnabled ? .white : FMColors.onSurface.opacity(0.38))
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}

/// Secondary Button - Outlined Style
public struct FMSecondaryButton: View {
    let title: String
    let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(FMTypography.button)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(FMColors.primary, lineWidth: 1.5)
                )
                .foregroundColor(FMColors.primary)
        }
    }
}

/// Text Button - Link Style
public struct FMTextButton: View {
    let title: String
    let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(FMTypography.captionMedium)
                .foregroundColor(FMColors.primary)
                .underline()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMPrimaryButton(title: "Siguiente paso") {}
        
        FMPrimaryButton(title: "Loading...", isLoading: true) {}
        
        FMPrimaryButton(title: "Disabled", isEnabled: false) {}
        
        FMSecondaryButton(title: "Cancelar") {}
        
        FMTextButton(title: "Términos de servicio") {}
    }
    .padding()
}
