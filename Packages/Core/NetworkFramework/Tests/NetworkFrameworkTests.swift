import XCTest
@testable import NetworkFramework

final class NetworkFrameworkTests: XCTestCase {
    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }
    
    func testAPIErrorDescriptions() {
        let invalidURLError = APIError.invalidURL
        XCTAssertNotNil(invalidURLError.errorDescription)
        
        let unauthorizedError = APIError.unauthorized
        XCTAssertEqual(unauthorizedError.errorDescription, "No autorizado")
    }
}
