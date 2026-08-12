import XCTest
import PersistenceFramework
@testable import PlayerFeature

final class UpdateFCMTokenUseCaseTests: XCTestCase {

    // Note: `UpdateFCMTokenUseCase` no longer reads a `deviceId` from the
    // Keychain — the request is built from `UIDevice`/`Bundle` — so the former
    // `missingDeviceId` test covered behavior that no longer exists.

    func test_execute_sendsRequest_andCachesToken() async throws {
        let keychain = MockKeychain()
        let device = MockDeviceService()
        let sut = UpdateFCMTokenUseCase(deviceService: device, keychainManager: keychain)

        try await sut.execute(fcmToken: "fcm-xyz")

        XCTAssertEqual(device.updateFCMTokenCallCount, 1)
        XCTAssertEqual(device.lastRequest?.fcmToken, "fcm-xyz")
        XCTAssertEqual(device.lastRequest?.platform, .ios)
        XCTAssertEqual(keychain.storage[.fcmToken], "fcm-xyz")
    }

    func test_execute_serviceError_propagates_andDoesNotCacheToken() async {
        let keychain = MockKeychain()
        let device = MockDeviceService()
        device.updateFCMTokenResult = .failure(TestError.boom)
        let sut = UpdateFCMTokenUseCase(deviceService: device, keychainManager: keychain)

        do {
            try await sut.execute(fcmToken: "fcm-xyz")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
        XCTAssertNil(keychain.storage[.fcmToken])
    }
}
