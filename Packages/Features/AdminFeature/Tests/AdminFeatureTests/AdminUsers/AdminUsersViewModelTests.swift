import XCTest
@testable import AdminFeature

@MainActor
final class AdminUsersViewModelTests: XCTestCase {

    private func page(_ names: [String], page: Int = 1, total: Int? = nil) -> AdminPage<AdminUserSummary> {
        AdminPage(
            items: names.enumerated().map { .stub(id: "\(page)-\($0.offset)", fullName: $0.element) },
            page: page, pageSize: 20, total: total ?? names.count
        )
    }

    func test_initialLoad_requestsAdminsPageOne() async {
        let repo = MockAdminUsersRepository()
        repo.defaultUsersResult = .success(page(["Ana"]))
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))

        await sut.loadIfNeeded()

        XCTAssertEqual(repo.fetchUsersCalls.first?.role, .administrator)
        XCTAssertEqual(repo.fetchUsersCalls.first?.page, 1)
        XCTAssertEqual(sut.content, .loaded(sut.page!.items))
    }

    func test_changingRole_goesBackToPageOne() async {
        let repo = MockAdminUsersRepository()
        repo.usersResults[1] = .success(page(["Ana"], total: 45))
        repo.usersResults[2] = .success(page(["Beto"], page: 2, total: 45))
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))
        await sut.loadIfNeeded()
        await sut.nextPage()
        XCTAssertEqual(sut.pageNumber, 2)

        await sut.selectRole(.player)

        XCTAssertEqual(repo.fetchUsersCalls.last?.role, .player)
        XCTAssertEqual(repo.fetchUsersCalls.last?.page, 1)
    }

    func test_search_filtersOnlyTheLoadedPage() async {
        let repo = MockAdminUsersRepository()
        repo.defaultUsersResult = .success(page(["Pablo Suárez", "David Velázquez"], total: 40))
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))
        await sut.loadIfNeeded()

        sut.searchQuery = "pablo"
        XCTAssertEqual(sut.visibleUsers.map(\.fullName), ["Pablo Suárez"])

        sut.searchQuery = "zzz"
        XCTAssertEqual(sut.content, .noMatches)
        XCTAssertEqual(repo.fetchUsersCalls.count, 1, "Searching never hits the server")
    }

    func test_emptyRole_isEmpty_notNoMatches() async {
        let repo = MockAdminUsersRepository()
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))
        await sut.loadIfNeeded()
        sut.searchQuery = "x"
        XCTAssertEqual(sut.content, .empty)
    }

    func test_firstLoadFailure_showsFailed_refreshFailureKeepsPage() async {
        let repo = MockAdminUsersRepository()
        repo.defaultUsersResult = .failure(TestError.boom)
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))
        await sut.loadIfNeeded()
        guard case .failed = sut.content else { return XCTFail("Expected failed, got \(sut.content)") }

        repo.defaultUsersResult = .success(page(["Ana"]))
        await sut.refresh()
        repo.defaultUsersResult = .failure(TestError.boom)
        await sut.refresh()

        XCTAssertEqual(sut.visibleUsers.map(\.fullName), ["Ana"])
        XCTAssertNotNil(sut.errorMessage)
    }

    func test_nextPage_doesNothingOnLastPage() async {
        let repo = MockAdminUsersRepository()
        repo.defaultUsersResult = .success(page(["Ana"], total: 1))
        let sut = AdminUsersViewModel(fetchUsersUseCase: FetchAdminUsersUseCase(repository: repo))
        await sut.loadIfNeeded()

        await sut.nextPage()

        XCTAssertEqual(repo.fetchUsersCalls.count, 1)
    }
}

@MainActor
final class AdminUserProfileViewModelTests: XCTestCase {

    private func makeSUT(
        repo: MockAdminUsersRepository,
        userId: String = "u-1",
        currentUserId: String? = "me"
    ) -> AdminUserProfileViewModel {
        AdminUserProfileViewModel(
            userId: userId,
            currentUserId: currentUserId,
            fetchDetailUseCase: FetchAdminUserDetailUseCase(repository: repo),
            updateAccessUseCase: UpdateAdminUserAccessUseCase(repository: repo)
        )
    }

    func test_ownAccount_cannotBeManaged() async {
        let repo = MockAdminUsersRepository()
        repo.detailResult = .success(.stub(id: "me"))
        let sut = makeSUT(repo: repo, userId: "me", currentUserId: "me")
        await sut.load()
        XCTAssertFalse(sut.canManageAccess)
    }

    func test_saveDisabled_withoutChanges() async {
        let repo = MockAdminUsersRepository()
        let sut = makeSUT(repo: repo)
        await sut.load()
        sut.beginEditingAccess()

        XCTAssertFalse(sut.canSaveAccess)
        sut.draftStatus = .blocked
        XCTAssertTrue(sut.canSaveAccess)
    }

    func test_save_sendsOnlyChange_andReloads() async {
        let repo = MockAdminUsersRepository()
        let sut = makeSUT(repo: repo)
        await sut.load()
        sut.beginEditingAccess()
        sut.draftRole = .organizer
        repo.detailResult = .success(.stub(role: .organizer))

        await sut.saveAccess()

        XCTAssertEqual(repo.updateCalls.first?.change, AdminUserAccessChange(role: .organizer, status: nil))
        XCTAssertTrue(sut.accessSaved)
        XCTAssertEqual(sut.detail?.summary.role, .organizer)
        XCTAssertEqual(repo.fetchDetailCallCount, 2)
    }

    func test_saveFailure_keepsDraftAndShowsError() async {
        let repo = MockAdminUsersRepository()
        repo.updateResult = .failure(TestError.boom)
        let sut = makeSUT(repo: repo)
        await sut.load()
        sut.beginEditingAccess()
        sut.draftStatus = .suspended

        await sut.saveAccess()

        XCTAssertFalse(sut.accessSaved)
        XCTAssertNotNil(sut.accessError)
        XCTAssertEqual(sut.draftStatus, .suspended)
        XCTAssertEqual(sut.detail?.summary.status, .active)
    }
}

@MainActor
final class AdminUserPaymentsViewModelTests: XCTestCase {

    func test_paging_movesThroughPages() async {
        let repo = MockAdminUsersRepository()
        repo.paymentsResult = .success(AdminPage(items: [], page: 1, pageSize: 5, total: 16))
        let sut = AdminUserPaymentsViewModel(userId: "u", fetchPaymentsUseCase: FetchAdminUserPaymentsUseCase(repository: repo))
        await sut.loadIfNeeded()
        XCTAssertEqual(sut.totalPages, 4)

        repo.paymentsResult = .success(AdminPage(items: [], page: 2, pageSize: 5, total: 16))
        await sut.nextPage()

        XCTAssertEqual(repo.fetchPaymentsPages, [1, 2])
        XCTAssertEqual(sut.pageNumber, 2)
    }

    func test_emptyHistory_isEmpty() async {
        let repo = MockAdminUsersRepository()
        let sut = AdminUserPaymentsViewModel(userId: "u", fetchPaymentsUseCase: FetchAdminUserPaymentsUseCase(repository: repo))
        await sut.loadIfNeeded()
        XCTAssertEqual(sut.content, .empty)
    }
}
