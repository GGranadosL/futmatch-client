import XCTest
@testable import PersistenceFramework

final class KeychainManagerTests: XCTestCase {
    var keychainManager: KeychainManager!
    
    override func setUp() {
        super.setUp()
        keychainManager = KeychainManager()
        // Limpiar antes de cada test
        try? keychainManager.delete(forKey: "testKey")
    }
    
    override func tearDown() {
        try? keychainManager.delete(forKey: "testKey")
        keychainManager = nil
        super.tearDown()
    }
    
    func testSaveAndRetrieve() throws {
        let testValue = "test_token_123"
        
        try keychainManager.save(testValue, forKey: "testKey")
        let retrieved = try keychainManager.retrieve(forKey: "testKey")
        
        XCTAssertEqual(retrieved, testValue)
    }
    
    func testDelete() throws {
        try keychainManager.save("test_value", forKey: "testKey")
        try keychainManager.delete(forKey: "testKey")
        
        let retrieved = try keychainManager.retrieve(forKey: "testKey")
        XCTAssertNil(retrieved)
    }
    
    func testRetrieveNonExistent() throws {
        let retrieved = try keychainManager.retrieve(forKey: "nonExistentKey")
        XCTAssertNil(retrieved)
    }
}
