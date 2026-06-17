import Foundation

// MARK: - FieldRulesFormatter

/// Converts between the per-rule UI representation and the single newline-joined,
/// numbered string the backend stores in `rules` (e.g. `"1. ...\n2. ..."`).
///
/// Pure value transformations — no dependencies — so the rule numbering/parsing
/// logic can be unit tested in isolation.
public enum FieldRulesFormatter {

    /// Joins individually entered rules into the backend format
    /// (`"1. rule\n2. rule"`). Blank/whitespace-only rules are dropped and the
    /// remaining ones are renumbered so the sequence is always contiguous.
    public static func format(_ rules: [String]) -> String {
        rules
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }

    /// Splits a stored rules string back into individual rule texts, stripping any
    /// leading numbering (`"1. "`, `"2) "`, `"3.- "`) so the editor shows clean text.
    public static func parse(_ rules: String) -> [String] {
        rules
            .components(separatedBy: "\n")
            .map { stripLeadingNumber(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Private

    /// Removes a leading enumeration marker such as `"1. "`, `"2) "` or `"3.- "`.
    private static func stripLeadingNumber(from line: String) -> String {
        guard let range = line.range(
            of: #"^\s*\d+\s*[.)\-]+\s*"#,
            options: .regularExpression
        ) else { return line }
        return String(line[range.upperBound...])
    }
}
