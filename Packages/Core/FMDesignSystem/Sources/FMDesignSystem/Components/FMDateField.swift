import SwiftUI

/// Material Design Date Picker Field
public struct FMDateField: View {
    let label: String
    @Binding var date: Date
    var displayFormat: String = "dd/MM/yyyy"
    var errorMessage: String? = nil
    
    @State private var showDatePicker = false
    
    public init(
        label: String,
        date: Binding<Date>,
        displayFormat: String = "dd/MM/yyyy",
        errorMessage: String? = nil
    ) {
        self.label = label
        self._date = date
        self.displayFormat = displayFormat
        self.errorMessage = errorMessage
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = displayFormat
        return formatter.string(from: date)
    }
    
    private var borderColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return showDatePicker ? FMColors.primary : FMColors.secondary
    }
    
    private var labelColor: Color {
        if errorMessage != nil {
            return FMColors.error
        }
        return showDatePicker ? FMColors.primary : FMColors.secondary
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Field Button
            Button {
                // Hide keyboard first
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDatePicker.toggle()
                }
            } label: {
                ZStack(alignment: .leading) {
                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: showDatePicker ? 2 : 1)
                        .frame(height: 56)
                    
                    // Floating Label
                    Text(label)
                        .font(FMTypography.label)
                        .foregroundColor(labelColor)
                        .background(FMColors.background)
                        .padding(.horizontal, 4)
                        .offset(x: 12, y: -28)
                    
                    // Date Display
                    HStack {
                        Text(formattedDate)
                            .font(FMTypography.inputText)
                            .foregroundColor(FMColors.primary)
                        
                        Spacer()
                        
                        Image(systemName: "calendar")
                            .foregroundColor(FMColors.primary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                }
            }
            .buttonStyle(.plain)
            
            // Date Picker
            if showDatePicker {
                VStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    
                    // Done button to close picker
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDatePicker = false
                        }
                    } label: {
                        Text("Listo")
                            .font(FMTypography.button)
                            .foregroundColor(FMColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FMColors.background)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FMColors.onSurface, lineWidth: 1)
                )
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
        FMDateField(
            label: "Date of Birth",
            date: .constant(Date())
        )
    }
    .padding()
}
