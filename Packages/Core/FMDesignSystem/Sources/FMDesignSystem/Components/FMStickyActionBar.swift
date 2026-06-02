import SwiftUI

/// A floating bottom action bar with a gradient scrim and a full-width icon+label button.
///
/// Designed to be used with `.safeAreaInset(edge: .bottom, spacing: 0)` so the
/// scroll content scrolls up behind the gradient instead of being hidden beneath it.
///
/// ```swift
/// scrollView
///     .safeAreaInset(edge: .bottom, spacing: 0) {
///         FMStickyActionBar(
///             icon: "person.2.fill",
///             title: "Unirse al partido",
///             action: { joinMatch() }
///         )
///     }
/// ```
public struct FMStickyActionBar: View {
    let icon: String?
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let backgroundColor: Color
    let buttonColor: Color
    let buttonTextColor: Color
    let action: () -> Void

    public init(
        icon: String? = nil,
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        backgroundColor: Color = FMColors.background,
        buttonColor: Color = FMColors.primary,
        buttonTextColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
        self.buttonColor = buttonColor
        self.buttonTextColor = buttonTextColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: buttonTextColor))
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(FMTypography.button)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(isEnabled ? buttonColor : FMColors.onSurface.opacity(0.12))
            )
            .foregroundColor(isEnabled ? buttonTextColor : FMColors.onSurface.opacity(0.38))
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
        .padding(.horizontal, 20)
        .padding(.top, 32)   // gradient fades in above the button
        .padding(.bottom, 12)
        .background {
            // Gradient covers the full bar including the home-indicator safe area
            LinearGradient(
                colors: [backgroundColor.opacity(0), backgroundColor],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { i in
                    Text("Item \(i)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    Divider()
                }
            }
        }

        VStack {
            Spacer()
            FMStickyActionBar(
                icon: "person.2.fill",
                title: "Unirse al partido",
                action: {}
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
