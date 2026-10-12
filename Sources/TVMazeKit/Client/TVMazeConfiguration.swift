import Foundation

/// Settings of a ``TVMazeClient``.
public struct TVMazeConfiguration: Sendable {
    /// `https://api.tvmaze.com`.
    public static let defaultBaseURL = URL(string: "https://api.tvmaze.com")!

    /// Where requests go. Change it to point at a proxy or a local stub server.
    public var baseURL: URL
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// Requests per window; `nil` turns client-side rate limiting off.
    public var rateLimit: RateLimit?
    /// What to do when TVMaze answers 429 Too Many Requests.
    public var retryPolicy: RetryPolicy
    /// Sent as `User-Agent`. TVMaze asks API users to identify their app.
    public var userAgent: String?
    /// The request timeout in seconds.
    public var timeout: TimeInterval

    public init(
        baseURL: URL = TVMazeConfiguration.defaultBaseURL,
        session: URLSession = .shared,
        rateLimit: RateLimit? = .tvMaze,
        retryPolicy: RetryPolicy = .standard,
        userAgent: String? = "TVMazeKit (+https://github.com/halilozel1903/TVMazeKit)",
        timeout: TimeInterval = 20
    ) {
        self.baseURL = baseURL
        self.session = session
        self.rateLimit = rateLimit
        self.retryPolicy = retryPolicy
        self.userAgent = userAgent
        self.timeout = timeout
    }

    /// A number of requests per time window.
    public struct RateLimit: Sendable, Equatable {
        public var maxRequests: Int
        public var interval: TimeInterval

        public init(maxRequests: Int, per interval: TimeInterval) {
            self.maxRequests = maxRequests
            self.interval = interval
        }

        /// TVMaze's documented limit: 20 calls every 10 seconds.
        public static let tvMaze = RateLimit(maxRequests: 20, per: 10)
    }
}
