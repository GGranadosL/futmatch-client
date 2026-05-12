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
                    .fill(isEnabled ? FMColors.primary : FMColors.secondary)
            )
            .foregroundColor(isEnabled ? .white : FMColors.onSecondary)
        }
        .disabled(!isEnabled || isLoading)
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
