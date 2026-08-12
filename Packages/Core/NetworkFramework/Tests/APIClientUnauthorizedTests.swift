import XCTest
@testable import NetworkFramework

// MARK: - Test Doubles

/// Stub transport that decides each response from the request's `Authorization`
/// header instead of a call counter, so a burst of concurrent requests stays
/// deterministic no matter what order they reach the loader in.
private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var validTokens: Set<String> = []
    private static var seenAuthHeaders: [String] = []

    /// - Parameter accepting: Authorization header values answered with 200.
    ///   Everything else gets the backend's real 401 body shape.
    static func reset(accepting: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        validTokens = accepting
        seenAuthHeaders = []
    }

    static func accept(_ header: String) {
        lock.lock()
        defer { lock.unlock() }
        validTokens.insert(header)
    }

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return seenAuthHeaders.count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
        Self.lock.lock()
        Self.seenAuthHeaders.append(auth)
        let isValid = Self.validTokens.contains(auth)
        Self.lock.unlock()

        let body = isValid
            ? Data(#"{"ok":true}"#.utf8)
            : Data(#"""
            {"error":{"title":"Token inválido","message":"Tu sesión no es válida o ha expirado.","errorCode":"GENERAL_ERROR"}}
            """#.utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: isValid ? 200 : 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

/// Counts `.apiUnauthorized` posts. Observes with `queue: nil` so the block runs
/// synchronously on the posting thread — no run-loop draining in the assertions.
private final class SessionEndSpy {
    private(set) var count = 0
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .apiUnauthorized,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.count += 1
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

/// Mutable token holder shared by the auth interceptor and the refresh handler.
private final class TokenBox: @unchecked Sendable {
    var current: String
    init(_ current: String) { self.current = current }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

private struct TestEndpoint: APIEndpoint {
    var baseURL: String { "https://stub.futmatch.test" }
    var path: String
    var method: HTTPMethod { .get }
}

private struct OKResponse: Decodable {
    let ok: Bool
}

// MARK: - Tests

/// Covers the launch-time burst: Home, reserved matches, notifications, profile and
/// the FCM sync all fire at once carrying the same expired access token, so the
/// server answers 401 to every one of them.
@MainActor
final class APIClientUnauthorizedTests: XCTestCase {

    private let burstSize = 8

    private func makeClient(token: TokenBox) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: configuration))
        client.addInterceptor(AuthTokenInterceptor { token.current })
        return client
    }

    private func runBurst(
        on client: APIClient,
        count: Int
    ) async -> [Result<OKResponse, Error>] {
        await withTaskGroup(of: Result<OKResponse, Error>.self) { group in
            for index in 0..<count {
                group.addTask { @MainActor in
                    do {
                        let response: OKResponse = try await client.request(
                            endpoint: TestEndpoint(path: "/resource/\(index)")
                        )
                        return .success(response)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var results: [Result<OKResponse, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: Recovery

    /// The headline behaviour: an expired access token must be invisible to the user.
    /// One 401, one refresh, one retry, no logout.
    func test_expiredToken_recoversWithoutEndingSession() async throws {
        StubURLProtocol.reset(accepting: ["Bearer fresh"])
        let token = TokenBox("expired")
        let spy = SessionEndSpy()
        let client = makeClient(token: token)
        client.unauthorizedHandler = {
            token.current = "fresh"
            return "fresh"
        }

        let response: OKResponse = try await client.request(endpoint: TestEndpoint(path: "/user/home"))

        XCTAssertTrue(response.ok)
        XCTAssertEqual(spy.count, 0, "A recoverable 401 must never log the user out")
    }

    /// A 401 on a client with no refresh handler configured must surface as an error,
    /// not as a logout — nothing has been retried yet, so the session is not proven dead.
    func test_unauthorizedWithoutRefreshHandler_doesNotEndSession() async {
        StubURLProtocol.reset(accepting: [])
        let token = TokenBox("expired")
        let spy = SessionEndSpy()
        let client = makeClient(token: token)

        do {
            let _: OKResponse = try await client.request(endpoint: TestEndpoint(path: "/user/home"))
            XCTFail("Expected the 401 to surface as an error")
        } catch {
            XCTAssertEqual(spy.count, 0)
        }
    }

    // MARK: Concurrent burst

    /// Every request in the burst must come back — success or failure — and they must
    /// share a single refresh. The previous implementation parked latecomers on a
    /// continuation that was never resumed, so their `.task` never finished and the
    /// screen sat on skeletons forever.
    func test_concurrentUnauthorized_shareOneRefresh_andAllComplete() async {
        StubURLProtocol.reset(accepting: ["Bearer fresh"])
        let token = TokenBox("expired")
        let refreshCalls = CallCounter()
        let spy = SessionEndSpy()
        let client = makeClient(token: token)
        client.unauthorizedHandler = {
            refreshCalls.increment()
            // Held open long enough that the whole burst is waiting on this one
            // refresh; without it the first request could finish before the rest
            // even reach their 401 and the coalescing would go untested.
            try await Task.sleep(nanoseconds: 100_000_000)
            token.current = "fresh"
            return "fresh"
        }

        let results = await runBurst(on: client, count: burstSize)

        XCTAssertEqual(results.count, burstSize, "Every request must complete, none may hang")
        XCTAssertEqual(refreshCalls.count, 1, "Concurrent 401s must coalesce onto one refresh")
        XCTAssertEqual(spy.count, 0, "A successful refresh must not log the user out")
        for result in results {
            switch result {
            case .success(let response): XCTAssertTrue(response.ok)
            case .failure(let error): XCTFail("Request failed after a successful refresh: \(error)")
            }
        }
    }

    /// When the refresh genuinely fails the user *should* be logged out — but once,
    /// not once per request in the burst.
    func test_failedRefresh_endsSessionExactlyOnce() async {
        StubURLProtocol.reset(accepting: [])
        let token = TokenBox("expired")
        let refreshCalls = CallCounter()
        let spy = SessionEndSpy()
        let client = makeClient(token: token)
        client.unauthorizedHandler = {
            refreshCalls.increment()
            try await Task.sleep(nanoseconds: 100_000_000)
            throw APIError.unauthorized
        }

        let results = await runBurst(on: client, count: burstSize)

        XCTAssertEqual(results.count, burstSize, "Every request must complete, none may hang")
        XCTAssertEqual(refreshCalls.count, 1)
        XCTAssertEqual(spy.count, 1, "A burst of 401s must produce a single logout")
        for result in results {
            if case .success = result {
                XCTFail("Requests must fail when the refresh failed")
            }
        }
    }

    // MARK: Unrecoverable retry

    /// The refresh succeeds but the server still rejects the token it just issued —
    /// the retry budget is spent, so this one does end the session.
    func test_retryStillUnauthorized_endsSession() async {
        StubURLProtocol.reset(accepting: [])
        let token = TokenBox("expired")
        let spy = SessionEndSpy()
        let client = makeClient(token: token)
        client.unauthorizedHandler = {
            token.current = "stillRejected"
            return "stillRejected"
        }

        do {
            let _: OKResponse = try await client.request(endpoint: TestEndpoint(path: "/user/home"))
            XCTFail("Expected the retried 401 to surface as an error")
        } catch {
            XCTAssertEqual(spy.count, 1)
            XCTAssertEqual(StubURLProtocol.requestCount, 2, "Exactly one retry, no retry loop")
        }
    }
}
