import SwiftUI
import FMDesignSystem
import AdminFeature

// MARK: - FieldRulesEditor

/// Editable list of field rules. Each rule is its own text field ("Regla 1",
/// "Regla 2", …) with a remove button, plus an "Agregar regla" button to append
/// more. Bound to `[FieldRuleDraft]`; the owning ViewModel joins them into the
/// backend `"1. …\n2. …"` format on save via `FieldRulesFormatter`.
struct FieldRulesEditor: View {
    @Binding var rules: [FieldRuleDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($rules) { $rule in
                HStack(alignment: .top, spacing: 8) {
                    FMTextField(
                        label: L10n.EditField.rule(number(of: rule)),
                        text: $rule.text,
                        autocapitalization: .sentences
                    )

                    Button {
                        remove(rule)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(FMColors.error)
                            .frame(width: 44, height: 56)
                            .contentShape(Rectangle())
                    }
                    .disabled(rules.count <= 1)
                    .opacity(rules.count <= 1 ? 0.3 : 1)
                }
            }

            Button {
                rules.append(FieldRuleDraft())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.EditField.addRule)
                }
                .font(FMTypography.labelLarge)
                .foregroundColor(FMColors.primary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    /// 1-based position of a rule, used for its "Regla N" label.
    private func number(of rule: FieldRuleDraft) -> Int {
        (rules.firstIndex(where: { $0.id == rule.id }) ?? 0) + 1
    }

    /// Removes a rule, keeping at least one empty field so the editor never
    /// collapses to nothing.
    private func remove(_ rule: FieldRuleDraft) {
        rules.removeAll { $0.id == rule.id }
        if rules.isEmpty { rules.append(FieldRuleDraft()) }
    }
}

// MARK: - Preview

#Preview {
    StatefulPreviewWrapper([
        FieldRuleDraft(text: "No se permite fumar."),
        FieldRuleDraft(text: "Uso obligatorio de calzado adecuado.")
    ]) { binding in
        ScrollView {
            FieldRulesEditor(rules: binding)
                .padding(20)
        }
        .background(FMColors.background)
    }
}

/// Tiny helper so the preview can hold mutable state.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
