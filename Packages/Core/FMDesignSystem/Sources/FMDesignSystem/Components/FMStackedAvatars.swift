import SwiftUI
import UIKit

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
        CachedAvatarView(urlString: urlString, size: size)
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

// MARK: - CachedAvatarView

/// Single avatar that loads from FMImageCache — survives navigation and parent re-renders.
private struct CachedAvatarView: View {
    let urlString: String?
    let size: CGFloat

    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("defaultAvatar", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(FMColors.surfaceContainerLowest, lineWidth: 2)
        )
        .task(id: urlString) {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let urlString, let url = URL(string: urlString) else {
            image = nil
            return
        }

        // Instant return if already cached
        if let cached = FMImageCache.shared.image(for: urlString) {
            image = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return }
            guard let downloaded = UIImage(data: data) else { return }
            FMImageCache.shared.store(downloaded, for: urlString)
            image = downloaded
        } catch {
            // Silently fail — default avatar stays visible
        }
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
