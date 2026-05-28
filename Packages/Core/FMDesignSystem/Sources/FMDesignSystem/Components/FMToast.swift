import SwiftUI

// MARK: - FMToast Style

public enum FMToastStyle {
    case neutral
    case success
    case error

    var iconName: String? {
        switch self {
        case .neutral: return nil
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .neutral: return FMColors.inverseOnSurface
        case .success: return Color(red: 0.30, green: 0.78, blue: 0.45)
        case .error:   return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }
}

// MARK: - FMToast

/// A transient message anchored near the bottom of the screen.
///
/// Uses the adaptive `inverseSurface` / `inverseOnSurface` tokens, so it renders
/// as a dark pill with light text in light mode (and inverts in dark mode)
/// automatically — no manual variant switching required.
public struct FMToast: View {
    private let message: String
    private let style: FMToastStyle

    public init(_ message: String, style: FMToastStyle = .neutral) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 10) {
            if let icon = style.iconName {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(style.iconColor)
            }
            Text(message)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.inverseOnSurface)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FMColors.inverseSurface)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 24)
    }
}

// MARK: - Toast Modifier

private struct FMToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let style: FMToastStyle
    let duration: TimeInterval

    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    FMToast(message, style: style)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            dismissTask?.cancel()
                            dismissTask = Task {
                                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                                guard !Task.isCancelled else { return }
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isPresented = false
                                }
                            }
                        }
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}

public extension View {
    /// Presents a transient toast near the bottom of the screen.
    /// Auto-dismisses after `duration` seconds.
    func fmToast(
        _ message: String,
        isPresented: Binding<Bool>,
        style: FMToastStyle = .neutral,
        duration: TimeInterval = 2.5
    ) -> some View {
        modifier(FMToastModifier(
            isPresented: isPresented,
            message: message,
            style: style,
            duration: duration
        ))
    }
}

// MARK: - Preview

#Preview("Light") {
    ZStack {
        FMColors.background.ignoresSafeArea()
        VStack(spacing: 16) {
            FMToast("Imagen subida con éxito", style: .success)
            FMToast("No se pudo subir la imagen", style: .error)
            FMToast("Cambios guardados")
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        FMColors.background.ignoresSafeArea()
        VStack(spacing: 16) {
            FMToast("Imagen subida con éxito", style: .success)
            FMToast("No se pudo subir la imagen", style: .error)
            FMToast("Cambios guardados")
        }
    }
    .preferredColorScheme(.dark)
}
