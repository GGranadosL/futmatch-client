import SwiftUI
import FMDesignSystem

// MARK: - CancelMatchReason

enum CancelMatchReason: CaseIterable, Identifiable {
    case minPlayers
    case weather
    case fieldUnavailable
    case other

    var id: Self { self }

    var label: String {
        switch self {
        case .minPlayers: return L10n.CancelMatch.reasonMinPlayers
        case .weather: return L10n.CancelMatch.reasonWeather
        case .fieldUnavailable: return L10n.CancelMatch.reasonFieldUnavailable
        case .other: return L10n.CancelMatch.reasonOther
        }
    }
}

// MARK: - CancelMatchReasonBottomSheet

struct CancelMatchReasonBottomSheet: View {
    let isLoading: Bool
    let errorMessage: String?
    let onConfirm: (String) -> Void
    let onBack: () -> Void

    @State private var selectedReason: CancelMatchReason?
    @State private var otherText: String = ""
    /// Measured natural height of the sheet content; drives a self-sizing detent.
    @State private var contentHeight: CGFloat = 0
    @State private var showErrorToast = false

    private static let maxReasonLength = 300

    private var finalReason: String {
        guard let selectedReason else { return "" }
        switch selectedReason {
        case .other: return otherText.trimmingCharacters(in: .whitespacesAndNewlines)
        default: return selectedReason.label
        }
    }

    private var isConfirmDisabled: Bool {
        finalReason.isEmpty || isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FMColors.outlineVariant)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.CancelMatch.reasonTitle)
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onSurface)
                    .bold()
                Text(L10n.CancelMatch.reasonSubtitle)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 12) {
                ForEach(CancelMatchReason.allCases) { reason in
                    reasonRow(reason)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            confirmButton
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Button(action: onBack) {
                Text(L10n.CancelMatch.backButton)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurface)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 16)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SheetContentHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(SheetContentHeightKey.self) { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(FMColors.surfaceContainerLowest.ignoresSafeArea())
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.hidden)
        .onChange(of: errorMessage) { message in
            guard message != nil else { return }
            showErrorToast = true
        }
        .fmToast(errorMessage ?? "", isPresented: $showErrorToast, style: .error)
    }

    // MARK: - Reason Row

    private func reasonRow(_ reason: CancelMatchReason) -> some View {
        let isSelected = selectedReason == reason
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedReason = reason
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? FMColors.primary : FMColors.outline, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Circle()
                                .fill(FMColors.primary)
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text(reason.label)
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurface)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if reason == .other, isSelected {
                FMTextField(
                    label: L10n.CancelMatch.reasonOtherLabel,
                    text: otherTextBinding,
                    autocapitalization: .sentences
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? FMColors.primary : FMColors.outlineVariant, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    /// Caps the free-typed reason at the backend's 300-char limit.
    private var otherTextBinding: Binding<String> {
        Binding(
            get: { otherText },
            set: { otherText = String($0.prefix(Self.maxReasonLength)) }
        )
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            onConfirm(finalReason)
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(isConfirmDisabled ? FMColors.onSurface : .white)
                } else {
                    Text(L10n.CancelMatch.confirmButton)
                        .font(FMTypography.labelLarge)
                        .foregroundColor(isConfirmDisabled ? FMColors.onSurface.opacity(0.38) : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule().fill(isConfirmDisabled ? FMColors.onSurface.opacity(0.12) : FMColors.error)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isConfirmDisabled)
    }
}

// MARK: - SheetContentHeightKey

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#Preview {
    CancelMatchReasonBottomSheet(
        isLoading: false,
        errorMessage: nil,
        onConfirm: { _ in },
        onBack: {}
    )
}
