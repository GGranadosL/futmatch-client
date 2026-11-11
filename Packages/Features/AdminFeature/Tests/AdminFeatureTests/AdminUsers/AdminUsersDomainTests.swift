import XCTest
@testable import AdminFeature

final class AdminUsersDomainTests: XCTestCase {

    // MARK: Masking

    func test_maskEmail_keepsFirstLetterAndDomain() {
        XCTAssertEqual(ContactMasking.maskEmail("ana.lopez@example.com"), "a***@example.com")
        XCTAssertEqual(ContactMasking.maskEmail("  j@gmail.com "), "j***@gmail.com")
    }

    func test_maskEmail_returnsNilForInvalidOrMissing() {
        XCTAssertNil(ContactMasking.maskEmail(nil))
        XCTAssertNil(ContactMasking.maskEmail(""))
        XCTAssertNil(ContactMasking.maskEmail("no-at-sign"))
        XCTAssertNil(ContactMasking.maskEmail("@example.com"))
        XCTAssertNil(ContactMasking.maskEmail("a@b@c.com"))
        XCTAssertNil(ContactMasking.maskEmail("a@localhost"))
    }

    func test_maskPhone_keepsLastTwoDigits() {
        XCTAssertEqual(ContactMasking.maskPhone("+52 55 1234 5678"), "***78")
    }

    func test_maskPhone_returnsNilWhenTooShortToHide() {
        XCTAssertNil(ContactMasking.maskPhone("12345"))
        XCTAssertNil(ContactMasking.maskPhone(nil))
        XCTAssertNil(ContactMasking.maskPhone("n/a"))
    }

    func test_userDTO_neverExposesFullContact() {
        let dto = AdminUserDTO(
            id: "1", name: "Ana", lastName: "López", email: "ana@example.com", phone: "+525512345678",
            country: "MX", gender: "FEMALE", profilePic: nil, role: "organizer", status: "BLOCKED",
            isEmailVerified: true, createdAt: 1_715_436_000_000
        )
        let user = dto.toDomain()
        XCTAssertEqual(user.maskedEmail, "a***@example.com")
        XCTAssertEqual(user.fullName, "Ana López")
        XCTAssertEqual(user.role, .organizer)
        XCTAssertEqual(user.status, .blocked)
        XCTAssertFalse(String(describing: user).contains("ana@example.com"))
    }

    // MARK: New badge

    func test_isNew_withinSevenRollingDays() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertTrue(AdminUserSummary.stub(createdAt: now.addingTimeInterval(-6.9 * 86_400)).isNew(now: now))
        XCTAssertFalse(AdminUserSummary.stub(createdAt: now.addingTimeInterval(-7 * 86_400)).isNew(now: now))
    }

    func test_isNew_falseForFutureOrMissingDates() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertFalse(AdminUserSummary.stub(createdAt: now.addingTimeInterval(60)).isNew(now: now))
        XCTAssertFalse(AdminUserSummary.stub(createdAt: nil).isNew(now: now))
        XCTAssertNil(Date(epochMillis: 0))
    }

    // MARK: Paging

    func test_totalPages_isAtLeastOne() {
        XCTAssertEqual(AdminPage<AdminUserSummary>(items: [], page: 1, pageSize: 20, total: 0).totalPages, 1)
        XCTAssertEqual(AdminPage<AdminUserSummary>(items: [], page: 1, pageSize: 5, total: 16).totalPages, 4)
        XCTAssertEqual(AdminPage<AdminUserSummary>(items: [], page: 1, pageSize: 20, total: 20).totalPages, 1)
    }

    // MARK: Devices

    func test_devices_sortedByLastUseDescending_neverUsedLast() {
        let old = AdminUserDevice(id: "old", platform: .ios, name: nil, appVersion: nil, osVersion: nil,
                                  isTrusted: false, isActive: true, lastUsedAt: Date(timeIntervalSince1970: 10))
        let recent = AdminUserDevice(id: "recent", platform: .android, name: nil, appVersion: nil, osVersion: nil,
                                     isTrusted: true, isActive: true, lastUsedAt: Date(timeIntervalSince1970: 20))
        let never = AdminUserDevice(id: "never", platform: .unknown, name: nil, appVersion: nil, osVersion: nil,
                                    isTrusted: false, isActive: false, lastUsedAt: nil)
        XCTAssertEqual(AdminUserDevice.sortedByLastUse([never, old, recent]).map(\.id), ["recent", "old", "never"])
    }

    // MARK: Payments

    func test_paymentDTO_keepsMatchAndPaidDatesApart_andNullMethod() {
        let dto = AdminUserPaymentDTO(
            id: "p", fieldName: "Xoco", matchStartsAt: 2_000, amountInCents: 16_000, currency: "usd",
            status: "CANCELED", paidAt: nil, refundedAt: nil, method: nil
        )
        let payment = dto.toDomain()
        XCTAssertEqual(payment.matchStartsAt, Date(timeIntervalSince1970: 2))
        XCTAssertNil(payment.paidAt)
        XCTAssertNil(payment.card)
        XCTAssertEqual(payment.currency, "USD")
        XCTAssertEqual(payment.status, .canceled)
    }

    func test_paymentDTO_unknownBrandIsKept_emptyMethodIsNil() {
        let unknown = AdminUserPaymentDTO(
            id: "p", fieldName: nil, matchStartsAt: nil, amountInCents: 100, currency: "MXN", status: "succeeded",
            paidAt: nil, refundedAt: nil, method: .init(brand: "unionpay", last4: "1234")
        ).toDomain()
        XCTAssertEqual(unknown.card, AdminUserPayment.Card(brand: "unionpay", last4: "1234"))

        let empty = AdminUserPaymentDTO(
            id: "p", fieldName: nil, matchStartsAt: nil, amountInCents: 100, currency: "MXN", status: nil,
            paidAt: nil, refundedAt: nil, method: .init(brand: " ", last4: nil)
        ).toDomain()
        XCTAssertNil(empty.card)
        XCTAssertEqual(empty.status, .unknown)
    }

    func test_money_usesCurrencyMinorUnits_andAlwaysNamesTheCode() {
        let formatting = AdminUsersFormatting(locale: Locale(identifier: "es_MX"))
        XCTAssertTrue(formatting.money(amountInCents: 18_000, currency: "MXN").hasPrefix("$180.00"))
        XCTAssertTrue(formatting.money(amountInCents: 18_000, currency: "MXN").hasSuffix("MXN"))
        XCTAssertTrue(formatting.money(amountInCents: 1_250, currency: "USD").contains("12.50"))
        XCTAssertTrue(formatting.money(amountInCents: 1_250, currency: "USD").hasSuffix("USD"))
        XCTAssertTrue(formatting.money(amountInCents: 500, currency: "JPY").contains("500"))
    }

    func test_nameMatches_ignoresCaseAndAccents() {
        XCTAssertTrue(AdminUsersFormatting.nameMatches("José López", query: "jose lo"))
        XCTAssertTrue(AdminUsersFormatting.nameMatches("Ana", query: "  "))
        XCTAssertFalse(AdminUsersFormatting.nameMatches("Ana", query: "Pablo"))
    }

    // MARK: Access change

    func test_accessDiff_sendsOnlyWhatChanged() {
        XCTAssertEqual(
            AdminUserAccessChange.diff(currentRole: .player, currentStatus: .active, newRole: .organizer, newStatus: .active),
            AdminUserAccessChange(role: .organizer, status: nil)
        )
        XCTAssertEqual(
            AdminUserAccessChange.diff(currentRole: .player, currentStatus: .active, newRole: .player, newStatus: .blocked),
            AdminUserAccessChange(role: nil, status: .blocked)
        )
        XCTAssertNil(AdminUserAccessChange.diff(currentRole: .player, currentStatus: .active, newRole: .player, newStatus: .active))
    }

    func test_accessRequestBody_omitsUnchangedFields() throws {
        let body = UpdateAdminUserAccessRequestDTO(change: AdminUserAccessChange(role: nil, status: .suspended))
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(body), encoding: .utf8))
        XCTAssertEqual(json, #"{"status":"SUSPENDED"}"#)
    }

    func test_listEndpoint_sendsRoleAndPaging() {
        let items = AdminUsersEndpoint.list(roles: [.player], page: 2, pageSize: 20).queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "roles" }?.value, "PLAYER")
        XCTAssertEqual(items.first { $0.name == "page" }?.value, "2")
        XCTAssertEqual(items.first { $0.name == "pageSize" }?.value, "20")
    }

    // MARK: Use case

    func test_updateAccessUseCase_throwsWithoutChanges_andSendsNothing() async {
        let repo = MockAdminUsersRepository()
        let sut = UpdateAdminUserAccessUseCase(repository: repo)
        do {
            try await sut.execute(userId: "u", currentRole: .player, currentStatus: .active, newRole: .player, newStatus: .active)
            XCTFail("Expected noAccessChanges")
        } catch {
            XCTAssertEqual(error as? AdminUsersError, .noAccessChanges)
        }
        XCTAssertTrue(repo.updateCalls.isEmpty)
    }
}
