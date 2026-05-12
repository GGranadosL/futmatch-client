import SwiftUI

/// Header for Onboarding Steps
public struct FMOnboardingHeader: View {
    let title: String
    let subtitle: String
    
    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FMTypography.title)
                .foregroundColor(FMColors.primary)
            
            Text(subtitle)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    FMOnboardingHeader(
        title: "Personal Info",
        subtitle: "Tell us a bit about yourself to get started."
    )
    .padding()
}
