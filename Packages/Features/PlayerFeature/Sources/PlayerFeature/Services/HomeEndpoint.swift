import Foundation
import NetworkFramework

enum HomeEndpoint: APIEndpoint {
    case home

    var path: String {
        "/user/home"
    }

    var method: HTTPMethod {
        .get
    }
}
