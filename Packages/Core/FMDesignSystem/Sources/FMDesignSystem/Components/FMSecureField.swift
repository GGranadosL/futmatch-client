import SwiftUI

/// Secure Text Field using FMTextField
public struct FMSecureField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var errorMessage: String? = nil
    
    public init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        errorMessage: String? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.errorMessage = errorMessage
    }
    
    public var body: some View {
        FMTextField(
            label: label,
            text: $text,
            placeholder: placeholder,
            isSecure: true,
            errorMessage: errorMessage
        )
    }
}