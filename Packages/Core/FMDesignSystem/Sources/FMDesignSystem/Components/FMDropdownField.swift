import SwiftUI

/// Dropdown option protocol
public protocol FMDropdownOption: Identifiable, Hashable {
    var displayName: String { get }
}

/// Simple string-based dropdown option
public struct FMSimpleOption: FMDropdownOption {
    public let id: String
    public let displayName: String
    
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
    
    public init(_ value: String) {
        self.id = value
        self.displayName = value
    }
}

/// Material Design Outlined Dropdown Field
public struct FMDropdownField<Option: FMDropdownOption>: View {
    let label: String
    let dropdownId: String
    @Binding var selectedOption: Option?
    @Binding var activeDropdownId: String?
    let options: [Option]
    var placeholder: String = ""
    var errorMessage: String? = nil
    /// When `true` the option list opens above the field instead of below.
    /// Use this for dropdowns near the bottom of the screen.
    var opensUpward: Bool = false

    private var isExpanded: Bool {
        activeDropdownId == dropdownId
    }

    public init(
        label: String,
        dropdownId: String = UUID().uuidString,
        selectedOption: Binding<Option?>,
        activeDropdownId: Binding<String?>,
        options: [Option],
        placeholder: String = "",
        errorMessage: String? = nil,
        opensUpward: Bool = false
    ) {
        self.label = label
        self.dropdownId = dropdownId
        self._selectedOption = selectedOption
        self._activeDropdownId = activeDropdownId
        self.options = options
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.opensUpward = opensUpward
    }
    
    private var hasSelection: Bool {
        selectedOption != nil
    }
    
    private var shouldShowLabel: Bool {
        isExpanded || hasSelection
    }
    
    private var borderColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return isExpanded ? FMColors.primary : FMColors.secondary
    }
    
    private var labelColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return isExpanded ? FMColors.primary : FMColors.secondary
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            mainField
            errorMessageView
        }
        .zIndex(isExpanded ? 999 : 0)
    }
    
    // MARK: - Subviews
    
    private var mainField: some View {
        ZStack(alignment: .leading) {
            fieldBorder
            floatingLabel
            selectionRow
        }
        .overlay(alignment: .top) {
            dropdownList
        }
        .zIndex(isExpanded ? 999 : 0)
    }
    
    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: isExpanded ? 2 : 1)
            .frame(height: 56)
    }
    
    private var floatingLabel: some View {
        Text(label)
            .font(shouldShowLabel ? FMTypography.label : FMTypography.inputText)
            .foregroundColor(labelColor)
            .background(FMColors.background)
            .padding(.horizontal, 4)
            .offset(x: 12, y: shouldShowLabel ? -28 : 0)
            .animation(.easeInOut(duration: 0.15), value: shouldShowLabel)
    }
    
    private var selectionRow: some View {
        HStack {
            if let selected = selectedOption {
                Text(selected.displayName)
                    .font(FMTypography.inputText)
                    .foregroundColor(FMColors.onSurface)
            } else if !placeholder.isEmpty {
                Text(placeholder)
                    .font(FMTypography.inputText)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
            
            Spacer()
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(FMColors.onSurfaceVariant)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    activeDropdownId = nil
                } else {
                    activeDropdownId = dropdownId
                }
            }
        }
    }
    
    @ViewBuilder
    private var dropdownList: some View {
        if isExpanded {
            let itemHeight: CGFloat = 48
            let maxVisibleItems = 5
            let visibleItems = min(options.count, maxVisibleItems)
            let listHeight = CGFloat(visibleItems) * itemHeight
            // Downward: clear the 56-pt field border + 4-pt gap.
            // Upward: position the list bottom flush with the field top, minus a 4-pt gap.
            let yOffset: CGFloat = opensUpward ? -(listHeight + 4) : 60

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(options) { option in
                        optionRow(option, itemHeight: itemHeight)

                        if option.id != options.last?.id {
                            Divider()
                                .background(FMColors.outline)
                        }
                    }
                }
            }
            .frame(height: listHeight)
            .background(FMColors.surfaceContainerLowest)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FMColors.outline, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 12,
                x: 0,
                y: opensUpward ? -4 : 4
            )
            .offset(y: yOffset)
        }
    }
    
    private func optionRow(_ option: Option, itemHeight: CGFloat) -> some View {
        let isSelected = selectedOption?.id == option.id
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOption = option
                activeDropdownId = nil
            }
        } label: {
            HStack {
                Text(option.displayName)
                    .font(FMTypography.inputText)
                    .foregroundColor(FMColors.onSurface)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(FMColors.primary)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .frame(height: itemHeight)
            .padding(.horizontal, 16)
            .background(isSelected ? FMColors.primary.opacity(0.08) : FMColors.surfaceContainerLowest)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            Text(error)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.error)
                .padding(.leading, 12)
        }
    }
}

// MARK: - Convenience initializer for String binding
public extension FMDropdownField where Option == FMSimpleOption {
    init(
        label: String,
        dropdownId: String = UUID().uuidString,
        selectedValue: Binding<String>,
        activeDropdownId: Binding<String?>,
        options: [String],
        placeholder: String = "",
        errorMessage: String? = nil
    ) {
        let simpleOptions = options.map { FMSimpleOption($0) }
        let selectedOption = Binding<FMSimpleOption?>(
            get: {
                if selectedValue.wrappedValue.isEmpty {
                    return nil
                }
                return simpleOptions.first { $0.id == selectedValue.wrappedValue }
            },
            set: { newValue in
                selectedValue.wrappedValue = newValue?.id ?? ""
            }
        )
        
        self.init(
            label: label,
            dropdownId: dropdownId,
            selectedOption: selectedOption,
            activeDropdownId: activeDropdownId,
            options: simpleOptions,
            placeholder: placeholder,
            errorMessage: errorMessage
        )
    }
}

// MARK: - Preview
struct FMDropdownFieldPreview: View {
    @State private var country = "México"
    @State private var code = "+52"
    @State private var activeDropdown: String? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            FMDropdownField(
                label: "País",
                dropdownId: "country",
                selectedValue: $country,
                activeDropdownId: $activeDropdown,
                options: ["México", "USA", "Canadá", "Francia", "Argentina"]
            )
            
            FMDropdownField(
                label: "Código",
                dropdownId: "code",
                selectedValue: $code,
                activeDropdownId: $activeDropdown,
                options: ["+52", "+1", "+54", "+33"]
            )
        }
        .padding()
    }
}

#Preview {
    FMDropdownFieldPreview()
}
