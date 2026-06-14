import SwiftUI
import FMDesignSystem

/// Multiline outlined text field styled to match `FMTextField`.
///
/// - When empty and unfocused: shows `label` as a native SwiftUI `prompt`
///   (placeholder text) **inside** the field — same as FMTextField's initial
///   state. Uses the `prompt:` parameter on `TextField` which is the correct
///   SwiftUI API for placeholder text.
/// - When focused or filled: the prompt hides automatically (native behavior)
///   and a floating label appears on top of the border, matching FMTextField's
///   outlined-Material style.
///
/// `focusTrigger` — increment from the parent to grab focus programmatically.
/// `onFocusChange` — reports focus changes so `NewFieldView` can update its
///   keyboard-toolbar state.
struct AdminTextArea: View {
    let label: String
    @Binding var text: String
    var lineRange: ClosedRange<Int> = 2...6
    var focusTrigger: Int = 0
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool

    private var isFloating: Bool { isFocused || !text.isEmpty }

    private var borderColor: Color {
        isFocused ? FMColors.primary : FMColors.secondary
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Border — drawn first so the floating label renders on top of it.
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isFocused ? 2 : 1)

            // The actual input.
            // `prompt:` is the SwiftUI-native placeholder: it shows inside the
            // field when the text is empty, styled as secondary text.
            TextField(
                "",
                text: $text,
                prompt: Text(label)
                    .font(FMTypography.inputText)        // 16 pt — matches typed text
                    .foregroundColor(FMColors.secondary), // muted so it reads as hint
                axis: .vertical
            )
            .focused($isFocused)
            .font(FMTypography.inputText)
            .foregroundColor(FMColors.primary)
            .tint(FMColors.primary)
            .lineLimit(lineRange)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)

            // Floating label on the top border — only visible once the field is
            // active or has content (when the native prompt is hidden).
            Text(label)
                .font(FMTypography.label)               // 12 pt medium
                .foregroundColor(borderColor)
                .padding(.horizontal, 4)
                .background(FMColors.background)        // punches through the border line
                .padding(.leading, 12)
                .offset(y: -8)                          // sits on the border
                .opacity(isFloating ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isFloating)
        }
        .padding(.top, 8)                               // headroom for the floating label
        .onChange(of: focusTrigger) { _ in isFocused = true }
        .onChange(of: isFocused)    { onFocusChange?($0) }
    }
}
