import SwiftUI

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
                        Image(systemName: "mappin.circle.fill")
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
    }
    
    // MARK: - Private
    
    @ViewBuilder
    private var fieldImageView: some View {
        if let urlString = fieldImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image("defaultField1x1", bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 100, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let image = fieldImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image("defaultField1x1", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Empty State

/// Empty state variant for when there's no upcoming game
public struct FMNextGameEmptyCard: View {
    let emptyMessage: String
    let actionLabel: String
    var onActionTap: (() -> Void)?
    
    public init(
        emptyMessage: String,
        actionLabel: String,
        onActionTap: (() -> Void)? = nil
    ) {
        self.emptyMessage = emptyMessage
        self.actionLabel = actionLabel
        self.onActionTap = onActionTap
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text(emptyMessage)
                .font(FMTypography.bodyMedium)
                .foregroundColor(FMColors.onSurfaceVariant)
            
            Button {
                onActionTap?()
            } label: {
                Text(actionLabel)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
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

#Preview("Empty State") {
    FMNextGameEmptyCard(
        emptyMessage: "Sin próximo partido",
        actionLabel: "Unirme a un partido"
    )
    .padding()
}
