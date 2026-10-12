import Foundation
@testable import TVMazeKit

/// Recorded JSON responses in `Fixtures/`. The shows are made up; the shapes are TVMaze's.
enum Fixture {
    struct Missing: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Missing(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(name))
    }
}

/// A canned HTTP response.
struct StubResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    static func json(_ fixture: String) throws -> StubResponse {
        try StubResponse(status: 200, headers: ["Content-Type": "application/json"], body: Fixture.data(fixture))
    }

    static func status(_ status: Int, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: headers, body: Data())
    }
}

typealias StubHandler = @Sendable (URLRequest) throws -> StubResponse

/// Answers requests from a handler registered for the request's host, so every test can run in
/// parallel with its own host. Nothing ever reaches the network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let handler = StubRegistry.shared.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        StubRegistry.shared.record(request, for: host)
        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()

    private let lock = NSLock()
    private var handlers: [String: StubHandler] = [:]
    private var requests: [String: [URLRequest]] = [:]

    func register(_ handler: @escaping StubHandler, for host: String) {
        lock.withLock { handlers[host] = handler }
    }

    func handler(for host: String) -> StubHandler? {
        lock.withLock { handlers[host] }
    }

    func record(_ request: URLRequest, for host: String) {
        lock.withLock { requests[host, default: []].append(request) }
    }

    func requests(for host: String) -> [URLRequest] {
        lock.withLock { requests[host] ?? [] }
    }
}

/// Collects the waits a client or limiter asked for, without waiting.
actor SleepRecorder {
    private(set) var delays: [TimeInterval] = []

    func record(_ delay: TimeInterval) {
        delays.append(delay)
    }
}

/// A client wired to the stub, on a host of its own.
struct StubbedClient {
    let host: String
    let client: TVMazeClient
    let sleeps: SleepRecorder

    init(
        retryPolicy: RetryPolicy = RetryPolicy(maxRetries: 3, baseDelay: 2, maxDelay: 20),
        rateLimiter: RateLimiter? = nil,
        handler: @escaping StubHandler
    ) {
        host = "stub-" + UUID().uuidString.lowercased() + ".tvmaze.test"
        StubRegistry.shared.register(handler, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let recorder = SleepRecorder()
        sleeps = recorder
        client = TVMazeClient(
            configuration: TVMazeConfiguration(
                baseURL: URL(string: "https://" + host)!,
                session: session,
                rateLimit: nil,
                retryPolicy: retryPolicy
            ),
            rateLimiter: rateLimiter,
            sleep: { delay in await recorder.record(delay) }
        )
    }

    /// Every request the client sent, in order.
    var requests: [URLRequest] {
        StubRegistry.shared.requests(for: host)
    }

    /// The last request's path.
    var lastPath: String? {
        requests.last?.url?.path
    }

    /// The last request's query items, decoded.
    var lastQuery: [URLQueryItem] {
        guard let url = requests.last?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return [] }
        return components.queryItems ?? []
    }

    /// The value of a query item of the last request.
    func lastQueryValue(_ name: String) -> String? {
        lastQuery.first(where: { $0.name == name })?.value
    }
}

/// A clock that only moves when told to, or when something sleeps on it.
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 0
    private var sleeps: [TimeInterval] = []

    var now: TimeInterval {
        lock.withLock { time }
    }

    var recordedSleeps: [TimeInterval] {
        lock.withLock { sleeps }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { time += seconds }
    }

    func sleep(_ seconds: TimeInterval) {
        lock.withLock {
            sleeps.append(seconds)
            time += seconds
        }
    }

    func limiter(maxRequests: Int, per interval: TimeInterval) -> RateLimiter {
        RateLimiter(
            maxRequests: maxRequests,
            per: interval,
            now: { [self] in self.now },
            sleep: { [self] seconds in self.sleep(seconds) }
        )
    }
}
