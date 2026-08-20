import SwiftUI

// MARK: - UIKit TextField Wrapper

/// A `UITextField` wrapper that gives full control over `textContentType`,
/// `isSecureTextEntry`, keyboard type and autocapitalization.
/// Using UIKit directly avoids SwiftUI's heuristic autofill inference that
/// causes iOS to fill both fields with the password on login forms.
private struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var externalFocus: Bool
    var isSecure: Bool
    var keyboardType: UIKeyboardType
    var contentType: UITextContentType?
    var autocapitalization: UITextAutocapitalizationType
    var font: UIFont
    var textColor: UIColor
    var onFocusChange: (Bool) -> Void
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    var hasPrevious: Bool = false
    var hasNext: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        // No vertical content-hugging here: the field is meant to fill the full
        // height of FMTextField's 56pt box (see `.frame(maxHeight: .infinity)` in
        // FMTextField's body). Hugging shrank it to ~20pt, leaving the rest of the
        // box untappable and letting taps there fall through to window-level
        // dismiss-keyboard gestures instead.
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        // Static configuration that never changes after creation.
        field.autocorrectionType = .no
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.passwordRules = nil
        field.tintColor = UIColor(FMColors.primary)
        applyDynamicConfiguration(to: field)
        if onPrevious != nil || onNext != nil {
            field.inputAccessoryView = context.coordinator.makeToolbar()
        }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        applyDynamicConfiguration(to: uiView)

        // Programmatic focus — only trigger when state actually changes
        let shouldBeFocused = externalFocus
        let isFocused = uiView.isFirstResponder
        if shouldBeFocused != isFocused {
            if shouldBeFocused {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            } else {
                DispatchQueue.main.async { uiView.resignFirstResponder() }
            }
        }

        // Update toolbar button states
        context.coordinator.updateToolbar(hasPrevious: hasPrevious, hasNext: hasNext)
    }

    /// Config that can change across renders (props are `var`, not `let`). Called on every
    /// `updateUIView` — i.e. on every keystroke — so each property is only written when it
    /// actually changed, to avoid nudging UIKit into reconfiguring the input views of a field
    /// that's already first responder.
    private func applyDynamicConfiguration(to field: UITextField) {
        // An explicit-empty content type tells UIKit "this field has no semantic type",
        // which suppresses the password-autofill heuristic without opting the field into
        // the one-time-code/SMS autofill lookup that `.oneTimeCode` would trigger on focus.
        let resolvedContentType = contentType ?? UITextContentType(rawValue: "")
        if field.textContentType != resolvedContentType {
            field.textContentType = resolvedContentType
        }
        if field.isSecureTextEntry != isSecure {
            field.isSecureTextEntry = isSecure
        }
        if field.keyboardType != keyboardType {
            field.keyboardType = keyboardType
        }
        if field.autocapitalizationType != autocapitalization {
            field.autocapitalizationType = autocapitalization
        }
        if field.font != font {
            field.font = font
        }
        if field.textColor != textColor {
            field.textColor = textColor
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextField
        private weak var prevButton: UIBarButtonItem?
        private weak var nextButton: UIBarButtonItem?

        init(parent: UIKitTextField) {
            self.parent = parent
        }

        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let prev = UIBarButtonItem(image: UIImage(systemName: "chevron.up"),
                                       style: .plain, target: self,
                                       action: #selector(tappedPrev))
            let next = UIBarButtonItem(image: UIImage(systemName: "chevron.down"),
                                       style: .plain, target: self,
                                       action: #selector(tappedNext))
            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let done = UIBarButtonItem(title: "Listo", style: .done, target: self,
                                       action: #selector(tappedDone))
            prev.isEnabled = parent.hasPrevious
            next.isEnabled = parent.hasNext
            toolbar.items = [prev, next, spacer, done]
            self.prevButton = prev
            self.nextButton = next
            return toolbar
        }

        func updateToolbar(hasPrevious: Bool, hasNext: Bool) {
            prevButton?.isEnabled = hasPrevious
            nextButton?.isEnabled = hasNext
        }

        @objc private func tappedPrev() { parent.onPrevious?() }
        @objc private func tappedNext() { parent.onNext?() }
        @objc private func tappedDone() { parent.externalFocus = false }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.externalFocus { parent.externalFocus = true }
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.externalFocus { parent.externalFocus = false }
            parent.onFocusChange(false)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - FMTextField

/// Material Design Outlined TextField
public struct FMTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    /// Overrides the auto-capitalization. When `nil`, falls back to the default
    /// heuristic (`.none` for email keyboards, `.words` otherwise).
    var autocapitalization: UITextAutocapitalizationType? = nil
    var contentType: UITextContentType?
    var isSecure: Bool = false
    var errorMessage: String? = nil
    var trailingIcon: Image? = nil
    var onTrailingIconTap: (() -> Void)? = nil

    @State private var isFocused: Bool = false
    @State private var isSecureTextHidden: Bool = true
    private var externalFocusBinding: Binding<Bool>?
    private var navHasPrevious: Bool = false
    private var navHasNext: Bool = false
    private var navOnPrevious: (() -> Void)? = nil
    private var navOnNext: (() -> Void)? = nil

    public init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        autocapitalization: UITextAutocapitalizationType? = nil,
        contentType: UITextContentType? = nil,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        trailingIcon: Image? = nil,
        onTrailingIconTap: (() -> Void)? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.contentType = contentType
        self.isSecure = isSecure
        self.errorMessage = errorMessage
        self.trailingIcon = trailingIcon
        self.onTrailingIconTap = onTrailingIconTap
        self.externalFocusBinding = nil
    }

    /// Programmatically control focus. Pass a `Binding<Bool>` — set it to `true` to focus, `false` to blur.
    public func focused(_ binding: Binding<Bool>) -> FMTextField {
        var copy = self
        copy.externalFocusBinding = binding
        return copy
    }

    /// Attach a prev/next/done navigation toolbar to the keyboard.
    public func keyboardNavigation(
        hasPrevious: Bool,
        hasNext: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> FMTextField {
        var copy = self
        copy.navHasPrevious = hasPrevious
        copy.navHasNext = hasNext
        copy.navOnPrevious = onPrevious
        copy.navOnNext = onNext
        return copy
    }
    
    private var shouldShowLabel: Bool {
        isFocused || !text.isEmpty
    }
    
    private var borderColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return isFocused ? FMColors.primary : FMColors.secondary
    }
    
    private var labelColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return isFocused ? FMColors.primary : FMColors.secondary
    }
    

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                // Border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                    .frame(height: 56)
                
                // Floating Label
                Text(label)
                    .font(shouldShowLabel ? FMTypography.label : FMTypography.inputText)
                    .foregroundColor(labelColor)
                    .background(FMColors.background)
                    .padding(.horizontal, 4)
                    .offset(x: 12, y: shouldShowLabel ? -28 : 0)
                    .animation(.easeInOut(duration: 0.15), value: shouldShowLabel)
                
                // Text Field
                HStack {
                    ZStack(alignment: .leading) {
                        UIKitTextField(
                            text: $text,
                            externalFocus: externalFocusBinding ?? $isFocused,
                            isSecure: isSecure && isSecureTextHidden,
                            keyboardType: keyboardType,
                            contentType: contentType,
                            autocapitalization: autocapitalization ?? (keyboardType == .emailAddress ? .none : .words),
                            font: .systemFont(ofSize: 16),
                            textColor: UIColor(FMColors.primary),
                            onFocusChange: { focused in
                                // The floating label already animates itself via
                                // `.animation(_:value: shouldShowLabel)` above; wrapping this
                                // write in its own `withAnimation` re-invalidated the whole
                                // enclosing screen at the same moment UIKit was animating the
                                // keyboard in, which is part of what made focus feel laggy.
                                isFocused = focused
                            },
                            onPrevious: navOnPrevious,
                            onNext: navOnNext,
                            hasPrevious: navHasPrevious,
                            hasNext: navHasNext
                        )
                        // Fill the full 56pt box instead of hugging to the text's intrinsic
                        // height, so the whole field is tappable, not just its vertical center.
                        .frame(maxHeight: .infinity)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                    
                    // Trailing Icon
                    if isSecure {
                        Button {
                            isSecureTextHidden.toggle()
                        } label: {
                            Image(systemName: isSecureTextHidden ? "eye" : "eye.slash")
                                .foregroundColor(FMColors.secondary)
                        }
                        .padding(.trailing, 16)
                    } else if let icon = trailingIcon {
                        Button {
                            onTrailingIconTap?()
                        } label: {
                            icon
                                .foregroundColor(FMColors.secondary)
                        }
                        .padding(.trailing, 16)
                    }
                }
                .frame(height: 56)
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.error)
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMTextField(
            label: "First Name",
            text: .constant("Pedro")
        )
        
        FMTextField(
            label: "Email",
            text: .constant(""),
            keyboardType: .emailAddress
        )
        
        FMTextField(
            label: "Password",
            text: .constant("password"),
            isSecure: true
        )
        
        FMTextField(
            label: "Email",
            text: .constant("invalid"),
            errorMessage: "Invalid email format"
        )
    }
    .padding()
}
