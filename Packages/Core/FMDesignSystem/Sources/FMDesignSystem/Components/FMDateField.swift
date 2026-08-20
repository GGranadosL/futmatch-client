import SwiftUI

/// Presentation style for `FMDateField`'s inline picker.
public enum FMDateFieldStyle {
    /// Calendar grid. Best for dates near the current month (e.g. a match date).
    case calendar
    /// Day/month/year spinners, all visible at once. Best for distant dates (e.g. a birth date).
    case wheel
}

/// Material Design Date Picker Field.
///
/// Two initializers:
/// - `date: Binding<Date>` — always has a value. Use where a sensible default exists (e.g. a
///   match date defaulting to today).
/// - `date: Binding<Date?>` — no default. The field shows `placeholder` until the user actually
///   moves the picker; nothing is written back before that, so opening the field and dismissing
///   it without touching the wheel/calendar leaves `date` untouched. Use where any default would
///   be wrong to submit unnoticed (e.g. a birth date).
public struct FMDateField: View {
    let label: String
    let placeholder: String?
    @Binding var date: Date?
    var displayFormat: String = "dd/MM/yyyy"
    var style: FMDateFieldStyle = .calendar
    var range: ClosedRange<Date>? = nil
    var errorMessage: String? = nil
    var onPickerVisibilityChanged: ((Bool) -> Void)? = nil

    @State private var showDatePicker = false
    /// Drives the underlying `DatePicker`, which needs a concrete `Date` even when nothing has
    /// been chosen yet. Only committed to `date` once it actually changes (`onChange`) — i.e.
    /// once the user moves the wheel/calendar — never on initial appearance or on "Done".
    @State private var pickerSelection: Date

    public init(
        label: String,
        date: Binding<Date>,
        displayFormat: String = "dd/MM/yyyy",
        style: FMDateFieldStyle = .calendar,
        range: ClosedRange<Date>? = nil,
        errorMessage: String? = nil,
        onPickerVisibilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = nil
        self._date = Binding(
            get: { date.wrappedValue },
            set: { date.wrappedValue = $0 ?? date.wrappedValue }
        )
        self.displayFormat = displayFormat
        self.style = style
        self.range = range
        self.errorMessage = errorMessage
        self.onPickerVisibilityChanged = onPickerVisibilityChanged
        self._pickerSelection = State(initialValue: date.wrappedValue)
    }

    // A distinct external label (`optionalDate:` instead of `date:`) rather than a second
    // overload of `date:` — with two initializers differing only in `Binding<Date>` vs.
    // `Binding<Date?>`, Swift's overload resolution can't always propagate the expected
    // parameter type into the `$viewModel.property` dynamic-member-lookup subscript that
    // builds the binding, and picks the wrong initializer before checking argument types.
    public init(
        label: String,
        optionalDate date: Binding<Date?>,
        placeholder: String,
        displayFormat: String = "dd/MM/yyyy",
        style: FMDateFieldStyle = .calendar,
        range: ClosedRange<Date>? = nil,
        errorMessage: String? = nil,
        onPickerVisibilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._date = date
        self.displayFormat = displayFormat
        self.style = style
        self.range = range
        self.errorMessage = errorMessage
        self.onPickerVisibilityChanged = onPickerVisibilityChanged
        self._pickerSelection = State(initialValue: date.wrappedValue ?? range?.upperBound ?? Date())
    }

    private var formattedDate: String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
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

    @ViewBuilder
    private var basePicker: some View {
        if let range {
            DatePicker("", selection: $pickerSelection, in: range, displayedComponents: .date)
        } else {
            DatePicker("", selection: $pickerSelection, displayedComponents: .date)
        }
    }

    // `.datePickerStyle` returns a distinct concrete type per style, so the branch
    // has to happen here rather than in the modifier argument.
    @ViewBuilder
    private var picker: some View {
        switch style {
        case .calendar:
            basePicker
                .datePickerStyle(.graphical)
                .labelsHidden()
        case .wheel:
            basePicker
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private func setPicker(visible: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDatePicker = visible
        }
        onPickerVisibilityChanged?(visible)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Field Button
            Button {
                // Hide keyboard first
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                setPicker(visible: !showDatePicker)
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
                        Text(formattedDate ?? placeholder ?? "")
                            .font(FMTypography.inputText)
                            .fontWeight(.regular)
                            .foregroundColor(formattedDate == nil ? FMColors.secondary : FMColors.primary)

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
                    picker
                        .onChange(of: pickerSelection) { newValue in
                            date = newValue
                        }

                    // Done button to close picker
                    Button {
                        setPicker(visible: false)
                    } label: {
                        Text(FML10n.DateField.done)
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
        // Keeps the wheel in sync when `date` changes from outside (e.g. a restored draft
        // arriving asynchronously after this view already exists).
        .onChange(of: date) { newValue in
            if let newValue, newValue != pickerSelection {
                pickerSelection = newValue
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FMDateField(
            label: "Date of Birth",
            optionalDate: .constant(nil),
            placeholder: "Select your date of birth",
            style: .wheel
        )
    }
    .padding()
}
