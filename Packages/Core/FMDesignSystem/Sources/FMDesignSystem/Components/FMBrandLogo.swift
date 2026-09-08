import SwiftUI

/// The FutMatch logotype (icon + wordmark) shown in app headers.
/// When `onTap` is provided the whole logo becomes a tappable button.
public struct FMBrandLogo: View {
    private let iconSize: CGFloat
    private let fontSize: CGFloat
    private let onTap: (() -> Void)?

    public init(iconSize: CGFloat = 28, fontSize: CGFloat = 22, onTap: (() -> Void)? = nil) {
        self.iconSize = iconSize
        self.fontSize = fontSize
        self.onTap = onTap
    }

    private var logo: some View {
        HStack(spacing: 8) {
            Image("logo_futmatch", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            Text("FutMatch")
                .font(.interBold(size: fontSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FMColors.primary, FMColors.inversePrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
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
