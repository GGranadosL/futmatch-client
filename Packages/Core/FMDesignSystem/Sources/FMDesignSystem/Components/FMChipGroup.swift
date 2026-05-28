import SwiftUI

/// Material Design Chip/Segment Control with Flow Layout
public struct FMChipGroup<T: Hashable & CustomStringConvertible>: View {
    let title: String?
    let options: [T]
    @Binding var selected: T
    var displayText: ((T) -> String)? = nil

    public init(
        title: String? = nil,
        options: [T],
        selected: Binding<T>,
        displayText: ((T) -> String)? = nil
    ) {
        self.title = title
        self.options = options
        self._selected = selected
        self.displayText = displayText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.secondary)
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    FMChip(
                        text: displayText?(option) ?? option.description,
                        isSelected: selected == option
                    ) {
                        selected = option
                    }
                }
            }
        }
    }
}

// MARK: - Optional Selection Variant

/// `FMChipGroup` overload that accepts an optional binding — no chip is highlighted
/// when the value is `nil`. Tapping an already-selected chip deselects it (sets to `nil`).
public struct FMChipGroupOptional<T: Hashable & CustomStringConvertible>: View {
    let title: String?
    let options: [T]
    @Binding var selected: T?
    var displayText: ((T) -> String)? = nil

    public init(
        title: String? = nil,
        options: [T],
        selected: Binding<T?>,
        displayText: ((T) -> String)? = nil
    ) {
        self.title = title
        self.options = options
        self._selected = selected
        self.displayText = displayText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.secondary)
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    FMChip(
                        text: displayText?(option) ?? option.description,
                        isSelected: selected == option
                    ) {
                        selected = (selected == option) ? nil : option
                    }
                }
            }
        }
    }
}

/// Flow Layout using iOS 16 Layout protocol
public struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }
        
        return LayoutResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }
    
    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}

/// Single Chip Component
public struct FMChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(text: String, isSelected: Bool, action: @escaping () -> Void) {
        self.text = text
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(text)
                    .font(FMTypography.captionMedium)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? FMColors.secondaryContainer : FMColors.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? FMColors.primary : FMColors.outline, lineWidth: 1)
            )
            .foregroundColor(isSelected ? FMColors.onSecondaryContainer : FMColors.onSurfaceVariant)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        FMChipGroup(
            title: "Género",
            options: ["Masculino", "Femenino", "Otro"],
            selected: .constant("Masculino")
        )
        
        FMChipGroup(
            title: "Posición",
            options: ["Portero", "Defensa", "Mediocampista", "Delantero"],
            selected: .constant("Delantero")
        )
    }
    .padding()
}
