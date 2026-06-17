import SwiftUI

/// Avatar component that shows user profile image or default avatar
public struct FMAvatar: View {
    let image: Image?
    let url: URL?
    /// Asset name to show when `image` is nil.
    /// Pass `nil` to render a neutral person SF Symbol.
    let defaultImageName: String?
    let size: CGFloat
    let showCameraBadge: Bool
    let badgeColor: Color

    public init(
        image: Image? = nil,
        url: URL? = nil,
        defaultImageName: String? = "defaultAvatar",
        size: CGFloat = 60,
        showCameraBadge: Bool = false,
        badgeColor: Color = FMColors.primary
    ) {
        self.image = image
        self.url = url
        self.defaultImageName = defaultImageName
        self.size = size
        self.showCameraBadge = showCameraBadge
        self.badgeColor = badgeColor
    }

    public var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loaded):
                        loaded
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        defaultAvatarView
                    default:
                        Circle()
                            .fill(FMColors.primaryContainer)
                            .frame(width: size, height: size)
                            .overlay(ProgressView().tint(FMColors.onPrimaryContainer))
                    }
                }
            } else {
                defaultAvatarView
            }

            // Camera badge
            if showCameraBadge {
                Circle()
                    .fill(badgeColor)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: size * 0.14))
                            .foregroundColor(.white)
                    )
                    .offset(x: size * 0.35, y: size * 0.35)
            }
        }
    }

    @ViewBuilder
    private var defaultAvatarView: some View {
        if let name = defaultImageName {
            Image(name, bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(FMColors.primaryContainer)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(FMColors.onPrimaryContainer)
                )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMAvatar(size: 100, showCameraBadge: true)
        FMAvatar(size: 60)
        FMAvatar(size: 40)
    }
    .padding()
}
