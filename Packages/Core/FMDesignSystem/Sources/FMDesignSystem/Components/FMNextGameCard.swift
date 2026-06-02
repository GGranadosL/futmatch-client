import SwiftUI
import UIKit

/// Card showing the user's next upcoming game
/// Displays date, time, location, and a field image
/// Also supports an empty state when no game is scheduled
public struct FMNextGameCard: View {
    let title: String
    let dateLabel: String
    let time: String
    let location: String
    let detailLabel: String
    var fieldImageUrl: String?
    var fieldImage: Image?
    var onDetailTap: (() -> Void)?

    /// Cached downloaded image — survives re-renders caused by parent state changes.
    @State private var cachedFieldImage: UIImage? = nil
    
    public init(
        title: String,
        dateLabel: String,
        time: String,
        location: String,
        detailLabel: String,
        fieldImageUrl: String? = nil,
        fieldImage: Image? = nil,
        onDetailTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.time = time
        self.location = location
        self.detailLabel = detailLabel
        self.fieldImageUrl = fieldImageUrl
        self.fieldImage = fieldImage
        self.onDetailTap = onDetailTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header label
            Text(title)
                .font(FMTypography.labelMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
                .padding(.bottom, 8)
            
            HStack(alignment: .top, spacing: 12) {
                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(dateLabel) - \(time)")
                        .font(FMTypography.titleMedium)
                        .foregroundColor(FMColors.onSurface)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(FMColors.primary)
                        
                        Text(location)
                            .font(FMTypography.bodyMedium)
                            .foregroundColor(FMColors.onSurfaceVariant)
                    }
                    
                    Button {
                        onDetailTap?()
                    } label: {
                        Text(detailLabel)
                            .font(FMTypography.labelLarge)
                            .foregroundColor(FMColors.primary)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // Field image
                fieldImageView
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
        .task(id: fieldImageUrl) {
            await loadFieldImage()
        }
    }

    // MARK: - Private

    @ViewBuilder
    private var fieldImageView: some View {
        Group {
            if let cached = cachedFieldImage {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else if let image = fieldImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image("defaultField1x1", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 100, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadFieldImage() async {
        guard
            let urlString = fieldImageUrl,
            let url = URL(string: urlString)
        else { return }

        // Return immediately if already in the shared cache
        if let cached = FMImageCache.shared.image(for: urlString) {
            cachedFieldImage = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return }
            guard let downloaded = UIImage(data: data) else { return }
            FMImageCache.shared.store(downloaded, for: urlString)
            cachedFieldImage = downloaded
        } catch {
            // Silently fail — default image stays visible
        }
    }
}

// MARK: - Previews
#Preview("With Game") {
    FMNextGameCard(
        title: "Tu Próximo Partido",
        dateLabel: "Hoy",
        time: "19:50 PM",
        location: "CDXM Roma Norte",
        detailLabel: "Ver detalle"
    )
    .padding()
}
