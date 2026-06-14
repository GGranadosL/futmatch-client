import XCTest
@testable import AdminFeature

final class FieldRulesFormatterTests: XCTestCase {

    // MARK: - format

    func test_format_numbersRulesAndJoinsWithNewlines() {
        let result = FieldRulesFormatter.format([
            "No se permite fumar.",
            "Uso obligatorio de calzado adecuado.",
            "Llegar 15 minutos antes del partido."
        ])

        XCTAssertEqual(
            result,
            "1. No se permite fumar.\n2. Uso obligatorio de calzado adecuado.\n3. Llegar 15 minutos antes del partido."
        )
    }

    func test_format_dropsBlankRulesAndRenumbers() {
        let result = FieldRulesFormatter.format([
            "Primera regla",
            "   ",
            "",
            "Segunda regla"
        ])

        XCTAssertEqual(result, "1. Primera regla\n2. Segunda regla")
    }

    func test_format_trimsWhitespace() {
        let result = FieldRulesFormatter.format(["  Llegar temprano  "])

        XCTAssertEqual(result, "1. Llegar temprano")
    }

    func test_format_emptyInput_returnsEmptyString() {
        XCTAssertEqual(FieldRulesFormatter.format([]), "")
        XCTAssertEqual(FieldRulesFormatter.format(["", "  "]), "")
    }

    // MARK: - parse

    func test_parse_stripsLeadingNumbering() {
        let result = FieldRulesFormatter.parse(
            "1. No se permite fumar.\n2. Uso obligatorio de calzado adecuado."
        )

        XCTAssertEqual(result, ["No se permite fumar.", "Uso obligatorio de calzado adecuado."])
    }

    func test_parse_handlesVariedNumberingSeparators() {
        let result = FieldRulesFormatter.parse("1) Regla uno\n2.- Regla dos\n3 . Regla tres")

        XCTAssertEqual(result, ["Regla uno", "Regla dos", "Regla tres"])
    }

    func test_parse_dropsBlankLines() {
        let result = FieldRulesFormatter.parse("1. Uno\n\n2. Dos\n   ")

        XCTAssertEqual(result, ["Uno", "Dos"])
    }

    func test_parse_keepsUnnumberedLinesIntact() {
        let result = FieldRulesFormatter.parse("Llegar temprano\nNo fumar")

        XCTAssertEqual(result, ["Llegar temprano", "No fumar"])
    }

    // MARK: - round trip

    func test_parseThenFormat_isStable() {
        let stored = "1. Uno\n2. Dos\n3. Tres"
        let roundTripped = FieldRulesFormatter.format(FieldRulesFormatter.parse(stored))

        XCTAssertEqual(roundTripped, stored)
    }
}
