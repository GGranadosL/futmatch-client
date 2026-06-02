import SwiftUI

/// The FutMatch logotype (icon + wordmark) shown in app headers.
/// When `onTap` is provided the whole logo becomes a tappable button.
public struct FMBrandLogo: View {
    private let onTap: (() -> Void)?

    public init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    private var logo: some View {
        HStack(spacing: 8) {
            Image("logo_futmatch", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            Text("FutMatch")
                .font(.interBold(size: 22))
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
