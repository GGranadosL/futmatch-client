import SwiftUI

/// Overlapping stacked avatars with optional "+N" counter
/// Used to display team members in match cards
public struct FMStackedAvatars: View {
    let avatarURLs: [String?]
    let totalCount: Int
    let size: CGFloat
    let maxVisible: Int
    
    /// - Parameters:
    ///   - avatarURLs: Array of optional URL strings (nil shows default avatar)
    ///   - totalCount: Total number of players (used for "+N" counter)
    ///   - size: Diameter of each avatar circle
    ///   - maxVisible: Max avatars to show before "+N"
    public init(
        avatarURLs: [String?] = [],
        totalCount: Int,
        size: CGFloat = 28,
        maxVisible: Int = 3
    ) {
        self.avatarURLs = avatarURLs
        self.totalCount = totalCount
        self.size = size
        self.maxVisible = maxVisible
    }
    
    private var visibleCount: Int {
        min(avatarURLs.count, maxVisible)
    }
    
    private var remainingCount: Int {
        max(0, totalCount - visibleCount)
    }
    
    /// Empty slot count to fill up to maxVisible when fewer avatars than maxVisible
    private var emptySlots: Int {
        let filled = avatarURLs.count
        guard filled < maxVisible else { return 0 }
        return maxVisible - filled
    }
    
    public var body: some View {
        HStack(spacing: -(size * 0.3)) {
            // Visible avatars
            ForEach(0..<visibleCount, id: \.self) { index in
                avatarView(avatarURLs[index])
                    .zIndex(Double(index))
            }
            
            // Empty placeholder slots (+ icons)
            ForEach(0..<emptySlots, id: \.self) { index in
                emptySlotView
                    .zIndex(Double(visibleCount + index))
            }
            
            // "+N" counter
            if remainingCount > 0 {
                counterView
                    .zIndex(Double(visibleCount + emptySlots))
            }
        }
    }
    
    // MARK: - Private Views
    
    private func avatarView(_ urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(FMColors.surfaceContainerLowest, lineWidth: 2)
        )
    }
    
    private var defaultAvatar: some View {
        Image("defaultAvatar", bundle: .main)
            .resizable()
            .scaledToFill()
    }
    
    private var emptySlotView: some View {
        Circle()
            .fill(FMColors.surfaceContainerHigh)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundColor(FMColors.onSurfaceVariant)
            )
            .overlay(
                Circle()
                    .stroke(FMColors.surfaceContainerLowest, lineWidth: 2)
            )
    }
    
    private var counterView: some View {
        Circle()
            .fill(FMColors.surfaceContainerHigh)
            .frame(width: size, height: size)
            .overlay(
                Text("+\(remainingCount)")
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(FMColors.onSurfaceVariant)
            )
            .overlay(
                Circle()
                    .stroke(FMColors.surfaceContainerLowest, lineWidth: 2)
            )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        // Team with 3 avatars + 3 more
        HStack {
            Text("Equipo A")
            Spacer()
            FMStackedAvatars(avatarURLs: [nil, nil, nil], totalCount: 6)
        }
        
        // Team with 1 avatar + empty slots
        HStack {
            Text("Equipo B")
            Spacer()
            FMStackedAvatars(avatarURLs: [nil], totalCount: 1)
        }
        
        // Team with 2 avatars + 4 more
        HStack {
            Text("Full Team")
            Spacer()
            FMStackedAvatars(avatarURLs: [nil, nil], totalCount: 6)
        }
    }
    .padding()
}
