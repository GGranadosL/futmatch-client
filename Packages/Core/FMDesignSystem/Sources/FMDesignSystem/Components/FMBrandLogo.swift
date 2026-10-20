import SwiftUI

/// The FutMatch logotype (icon + wordmark) shown in app headers.
/// When `onTap` is provided the whole logo becomes a tappable button.
///
/// `isRevealed` animates the logo in and out: the icon rotates and scales while the
/// wordmark's letters fade one after another (in reverse order when hiding). It
/// defaults to `true`, which renders the plain static logo. The wordmark is two-tone:
/// "Inter" in `interColor`, "Fut" in the brand blue.
public struct FMBrandLogo: View {
    private let iconSize: CGFloat
    private let fontSize: CGFloat
    private let isRevealed: Bool
    private let interColor: Color
    private let onTap: (() -> Void)?

    private static let wordmark = Array("InterFut")
    private static let interLetterCount = 5
    private static let letterDuration: Double = 0.1
    private static let letterStagger: Double = 0.022
    private static let iconDuration: Double = 0.22

    public init(
        iconSize: CGFloat = 28,
        fontSize: CGFloat = 22,
        isRevealed: Bool = true,
        interColor: Color = FMColors.onBackground,
        onTap: (() -> Void)? = nil
    ) {
        self.iconSize = iconSize
        self.fontSize = fontSize
        self.isRevealed = isRevealed
        self.interColor = interColor
        self.onTap = onTap
    }

    private var logo: some View {
        HStack(spacing: 8) {
            Image("logo_interfut", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .opacity(isRevealed ? 1 : 0)
                .rotationEffect(.degrees(isRevealed ? 0 : -30))
                .scaleEffect(isRevealed ? 1 : 0.8)
                .animation(.easeInOut(duration: Self.iconDuration), value: isRevealed)

            wordmark
        }
        .allowsHitTesting(isRevealed)
    }

    /// "Inter" in the content colour, "Fut" in the brand blue.
    private var wordmark: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.wordmark.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.montserratBold(size: fontSize))
                    .foregroundColor(index < Self.interLetterCount ? interColor : FMColors.primary)
                    .fixedSize()
                    .opacity(isRevealed ? 1 : 0)
                    .animation(
                        .easeInOut(duration: Self.letterDuration)
                            .delay(letterDelay(at: index)),
                        value: isRevealed
                    )
            }
        }
    }

    /// Letters leave in reading order and return in the opposite order.
    private func letterDelay(at index: Int) -> Double {
        let order = isRevealed ? Self.wordmark.count - 1 - index : index
        return Double(order) * Self.letterStagger
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) {
                logo
            }
            .buttonStyle(.plain)
        } else {
            logo
        }
    }
}
