import XCTest
@testable import AdminFeature

final class DesktopEnrollmentTicketTests: XCTestCase {

    private let enrollmentId = "550e8400-e29b-41d4-a716-446655440000"
    private let nonce = "1fd7ee6b-6f69-4fc5-873e-79ff0a10c5d6"

    func test_init_parsesValidPayload() throws {
        let ticket = try XCTUnwrap(DesktopEnrollmentTicket(qrPayload: DesktopEnrollmentTicket.stubQRPayload()))

        XCTAssertEqual(ticket.enrollmentId, enrollmentId)
        XCTAssertEqual(ticket.nonce, nonce)
    }

    func test_init_ignoresSurroundingWhitespace() {
        let payload = "\n  \(DesktopEnrollmentTicket.stubQRPayload())  \n"

        XCTAssertNotNil(DesktopEnrollmentTicket(qrPayload: payload))
    }

    func test_init_ignoresUnknownExtraFields() {
        // Forward-compatibility: a newer desktop build adding fields must not
        // break older iOS clients.
        let payload = #"{"enrollmentId":"\#(enrollmentId)","nonce":"\#(nonce)","extra":"ignored"}"#

        XCTAssertNotNil(DesktopEnrollmentTicket(qrPayload: payload))
    }

    func test_init_returnsNil_whenNonceIsMissing() {
        let payload = #"{"enrollmentId":"\#(enrollmentId)"}"#

        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: payload))
    }

    func test_init_returnsNil_whenEnrollmentIdIsNotAUUID() {
        let payload = #"{"enrollmentId":"not-a-uuid","nonce":"\#(nonce)"}"#

        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: payload))
    }

    func test_init_returnsNil_whenNonceIsNotAUUID() {
        let payload = #"{"enrollmentId":"\#(enrollmentId)","nonce":"12345"}"#

        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: payload))
    }

    func test_init_returnsNil_forMalformedJSON() {
        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: #"{"enrollmentId":"#))
    }

    func test_init_returnsNil_forUnrelatedQRCode() {
        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: "https://example.com"))
        XCTAssertNil(DesktopEnrollmentTicket(qrPayload: ""))
    }
}
