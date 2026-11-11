import Foundation

/// Text shared from the match detail: invitation, field, date and time, price,
/// location and the link — the same content Android shares. Empty fields are skipped.
struct MatchShareMessageBuilder {
    func message(for match: MatchItem, url: URL) -> String {
        let when = [match.date, match.timeRange]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        let lines: [String?] = [
            L10n.MatchDetail.shareInvite,
            line(L10n.MatchDetail.shareField, match.venueName),
            line(L10n.MatchDetail.shareWhen, when),
            line(L10n.MatchDetail.sharePrice, match.price),
            line(L10n.MatchDetail.shareLocation, match.location),
            url.absoluteString
        ]
        return lines.compactMap { $0 }.joined(separator: "\n")
    }

    private func line(_ format: (String) -> String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : format(trimmed)
    }
}
