import Foundation

/// Localized strings for the Design System.
///
/// Deliberately named `FML10n` rather than `L10n`: every feature package declares its own
/// `public enum L10n` and imports `FMDesignSystem`, so an `L10n` here would make the name
/// ambiguous at those call sites.
public enum FML10n {

    // MARK: - Date Field
    public enum DateField {
        public static var done: String {
            NSLocalizedString("fm.dateField.done", bundle: .module, comment: "")
        }
    }

    // MARK: - Pagination
    public enum Pagination {
        public static var previous: String {
            NSLocalizedString("fm.pagination.previous", bundle: .module, comment: "")
        }
        public static var next: String {
            NSLocalizedString("fm.pagination.next", bundle: .module, comment: "")
        }
        public static func pageOf(_ page: Int, _ total: Int) -> String {
            String(format: NSLocalizedString("fm.pagination.pageOf", bundle: .module, comment: ""), page, total)
        }
    }
}
