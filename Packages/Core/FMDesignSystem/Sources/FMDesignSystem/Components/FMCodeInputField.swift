import SwiftUI

/// A 6-digit code input field with individual boxes
public struct FMCodeInputField: View {
    @Binding var code: String
    let codeLength: Int
    var onComplete: ((String) -> Void)?
    
    @FocusState private var isFocused: Bool
    
    public init(
        code: Binding<String>,
        codeLength: Int = 6,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._code = code
        self.codeLength = codeLength
        self.onComplete = onComplete
    }
    
    public var body: some View {
        ZStack {
            // Hidden TextField for keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { newValue in
                    // Limit to codeLength digits
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > codeLength {
                        code = String(filtered.prefix(codeLength))
                    } else {
                        code = filtered
                    }
                    
                    // Call onComplete when code is full
                    if code.count == codeLength {
                        onComplete?(code)
                    }
                }
            
            // Visual boxes
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { index in
                    CodeBox(
                        character: getCharacter(at: index),
                        isCurrent: index == code.count && isFocused,
                        isFilled: index < code.count
                    )
                }
            }
            .onTapGesture {
                isFocused = true
            }
        }
        .onAppear {
            // Auto-focus on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
    
    private func getCharacter(at index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }
}

// MARK: - Individual Code Box
private struct CodeBox: View {
    let character: String
    let isCurrent: Bool
    let isFilled: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
                .frame(width: 48, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FMColors.background)
                )
            
            if !character.isEmpty {
                Text(character)
                    .font(FMTypography.title)
                    .foregroundColor(FMColors.primary)
            }
            
            // Cursor animation
            if isCurrent && character.isEmpty {
                Rectangle()
                    .fill(FMColors.primary)
                    .frame(width: 2, height: 24)
                    .opacity(isCurrent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isCurrent)
            }
        }
    }
    
    private var borderColor: Color {
        if isCurrent {
            return FMColors.primary
        } else if isFilled {
            return FMColors.primary.opacity(0.6)
        } else {
            return FMColors.outline
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        FMCodeInputField(code: .constant("123"))
        FMCodeInputField(code: .constant("123456"))
        FMCodeInputField(code: .constant(""))
    }
    .padding()
}
