import XCTest
@testable import AdminFeature

final class AdminDependencyFactoryTests: XCTestCase {
    func test_init_doesNotCrash() {
        _ = AdminDependencyFactory()
    }
}
