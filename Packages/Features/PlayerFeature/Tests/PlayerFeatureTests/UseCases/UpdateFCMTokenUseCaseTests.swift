import XCTest
import PersistenceFramework
@testable import PlayerFeature

final class UpdateFCMTokenUseCaseTests: XCTestCase {

    func test_execute_missingDeviceId_throws_andSkipsService() async {
        let keychain = MockKeychain() // no deviceId stored
        let device = MockDeviceService()
        let sut = UpdateFCMTokenUseCase(deviceService: device, keychainManager: keychain)

        do {
            try await sut.execute(fcmToken: "fcm-1")
            XCTFail("Expected missingDeviceId error")
        } catch {
            guard case DeviceError.missingDeviceId = error else {
                return XCTFail("Expected .missingDeviceId, got \(error)")
            }
        }
        XCTAssertEqual(device.updateFCMTokenCallCount, 0)
    }

    func test_execute_withDeviceId_sendsRequest_andCachesToken() async throws {
        let keychain = MockKeychain()
        keychain.storage[.deviceId] = "dev-1"
        let device = MockDeviceService()
        let sut = UpdateFCMTokenUseCase(deviceService: device, keychainManager: keychain)

        try await sut.execute(fcmToken: "fcm-xyz")

        XCTAssertEqual(device.updateFCMTokenCallCount, 1)
        XCTAssertEqual(device.lastRequest?.deviceId, "dev-1")
        XCTAssertEqual(device.lastRequest?.fcmToken, "fcm-xyz")
        XCTAssertEqual(keychain.storage[.fcmToken], "fcm-xyz")
    }

    func test_execute_serviceError_propagates_andDoesNotCacheToken() async {
        let keychain = MockKeychain()
        keychain.storage[.deviceId] = "dev-1"
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
