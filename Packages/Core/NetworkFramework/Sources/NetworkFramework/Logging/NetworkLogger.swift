import Foundation

// MARK: - Network Logger Protocol

public protocol NetworkLogger {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: HTTPURLResponse, data: Data)
    func logError(_ error: Error)
}

// MARK: - Silent Logger for Production

public struct SilentNetworkLogger: NetworkLogger {
    public init() {}

    public func logRequest(_ request: URLRequest) {}
    public func logResponse(_ response: HTTPURLResponse, data: Data) {}
    public func logError(_ error: Error) {}
}
