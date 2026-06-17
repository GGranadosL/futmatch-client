import SwiftUI

/// Loader alert component with rotating icon.
/// Used for operations in progress (joining, confirming, processing).
public struct FMLoaderAlert: View {
    let message: String
    let icon: String
    @State private var rotation: Double = 0

    public init(
        message: String,
        icon: String = "soccerball"
    ) {
        self.message = message
        self.icon = icon
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                Text(message)
                    .font(FMTypography.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

#Preview {
    FMLoaderAlert(message: "Procesando...")
}
