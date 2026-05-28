import SwiftUI

// MARK: - Shimmer Animation

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                               location: 0),
                            .init(color: .white.opacity(0.45),                 location: 0.4),
                            .init(color: .clear,                               location: 0.8),
                        ],
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint:   .init(x: phase + 1, y: 0.5)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Base Shape

/// A rounded rectangle filled with the skeleton color, with built-in shimmer animation.
/// Combine multiples to build any skeleton layout.
public struct FMSkeleton: View {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FMColors.surfaceContainerLow)
            .modifier(ShimmerModifier())
    }
}

// MARK: - Pre-built Skeletons

/// Skeleton that matches `FMGameCard` dimensions (horizontal scroll item).
public struct FMGameCardSkeleton: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image placeholder
            FMSkeleton(cornerRadius: 12)
                .frame(width: 160, height: 100)
            // Title line
            FMSkeleton(cornerRadius: 4)
                .frame(width: 120, height: 14)
            // Price line
            FMSkeleton(cornerRadius: 4)
                .frame(width: 80, height: 12)
            // Time line
            FMSkeleton(cornerRadius: 4)
                .frame(width: 100, height: 12)
        }
        .padding(12)
        .frame(width: 184)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

/// Skeleton that matches the Last Match row card.
public struct FMLastMatchSkeleton: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            FMSkeleton(cornerRadius: 22)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                FMSkeleton(cornerRadius: 4).frame(width: 100, height: 14)
                FMSkeleton(cornerRadius: 4).frame(width: 140, height: 12)
            }

            Spacer()

            // Score
            FMSkeleton(cornerRadius: 4).frame(width: 52, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

/// Skeleton that matches `FMMatchCard` dimensions (full-width list card).
public struct FMMatchCardSkeleton: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: image + title + price
            HStack(alignment: .top, spacing: 12) {
                FMSkeleton(cornerRadius: 10)
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 8) {
                    FMSkeleton(cornerRadius: 4).frame(width: 140, height: 16)
                    FMSkeleton(cornerRadius: 4).frame(width: 110, height: 13)
                    FMSkeleton(cornerRadius: 20).frame(width: 100, height: 26)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 80, height: 14)
                    FMSkeleton(cornerRadius: 4).frame(width: 60, height: 12)
                }
            }

            // Teams row
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 60, height: 12)
                    HStack(spacing: -8) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeleton(cornerRadius: 12).frame(width: 24, height: 24)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    FMSkeleton(cornerRadius: 4).frame(width: 60, height: 12)
                    HStack(spacing: -8) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeleton(cornerRadius: 12).frame(width: 24, height: 24)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMColors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMColors.outlineVariant, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Skeletons") {
    VStack(alignment: .leading, spacing: 24) {
        // Suggested games row
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in FMGameCardSkeleton() }
            }
            .padding(.horizontal, 24)
        }

        // Last match
        FMLastMatchSkeleton()
            .padding(.horizontal, 24)
    }
    .padding(.top, 24)
}
