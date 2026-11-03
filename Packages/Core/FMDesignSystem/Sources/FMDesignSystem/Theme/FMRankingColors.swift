import SwiftUI

/// Gold / silver / bronze accents for the monthly ranking, light and dark.
/// Chosen by the server's `position` (shared positions share the medal), not by array index.
public struct FMRankingMedalColors {
    public let accent: Color
    public let container: Color
    public let onContainer: Color

    public static func forPosition(_ position: Int) -> FMRankingMedalColors {
        switch position {
        case 1:
            return FMRankingMedalColors(
                accent: .adaptive(light: "#876215", dark: "#E9C56B"),
                container: .adaptive(light: "#FFF1CF", dark: "#3C321C"),
                onContainer: .adaptive(light: "#4F3907", dark: "#FFE6A6")
            )
        case 2:
            return FMRankingMedalColors(
                accent: .adaptive(light: "#52677C", dark: "#B8C8DA"),
                container: .adaptive(light: "#E8EFF6", dark: "#293440"),
                onContainer: .adaptive(light: "#2E4052", dark: "#DFEAF6")
            )
        case 3:
            return FMRankingMedalColors(
                accent: .adaptive(light: "#885531", dark: "#DBAB88"),
                container: .adaptive(light: "#FFEADB", dark: "#3E2C23"),
                onContainer: .adaptive(light: "#57331D", dark: "#FFDCC3")
            )
        default:
            return FMRankingMedalColors(
                accent: FMColors.primary,
                container: FMColors.surfaceContainerLow,
                onContainer: FMColors.onSurface
            )
        }
    }

    /// Positions 1–3 get a medal; the rest use the regular surface.
    public static func hasMedal(_ position: Int) -> Bool {
        (1...3).contains(position)
    }
}
