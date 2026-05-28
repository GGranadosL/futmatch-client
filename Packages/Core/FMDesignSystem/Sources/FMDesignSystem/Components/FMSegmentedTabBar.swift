import SwiftUI

/// Horizontal tab bar with an animated underline indicator.
/// Generic over any `Hashable` tab type so it can be reused across features.
///
/// Usage:
/// ```swift
/// FMSegmentedTabBar(tabs: ["Próximos", "Finalizados", "Cancelados"], selected: $tab)
/// ```
public struct FMSegmentedTabBar<Tab: Hashable>: View {
    private let tabs: [Tab]
    private let labelFor: (Tab) -> String
    @Binding private var selected: Tab
    @Namespace private var underline

    public init(
        tabs: [Tab],
        selected: Binding<Tab>,
        labelFor: @escaping (Tab) -> String
    ) {
        self.tabs = tabs
        self._selected = selected
        self.labelFor = labelFor
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            Divider()
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = tab == selected
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 0) {
                Text(labelFor(tab))
                    .font(isSelected ? FMTypography.labelLarge : FMTypography.bodyMedium)
                    .foregroundColor(isSelected ? FMColors.primary : FMColors.onSurfaceVariant)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)

                // Animated underline
                if isSelected {
                    Rectangle()
                        .fill(FMColors.primary)
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "underline", in: underline)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Convenience init for String tabs

public extension FMSegmentedTabBar where Tab == String {
    init(tabs: [String], selected: Binding<String>) {
        self.init(tabs: tabs, selected: selected, labelFor: { $0 })
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var tab = "Próximos"
        var body: some View {
            VStack(spacing: 0) {
                FMSegmentedTabBar(tabs: ["Próximos", "Finalizados", "Cancelados"], selected: $tab)
                Text("Tab activo: \(tab)")
                    .padding()
            }
        }
    }
    return PreviewWrapper()
}
