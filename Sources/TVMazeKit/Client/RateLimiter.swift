import Foundation

/// A sliding-window rate limiter: at most `maxRequests` calls to ``acquire()`` go through in any
/// `interval`; later callers wait their turn.
///
/// TVMaze allows at least 20 calls every 10 seconds per IP address, which is the default.
public actor RateLimiter {
    public nonisolated let maxRequests: Int
    public nonisolated let interval: TimeInterval

    private let now: @Sendable () -> TimeInterval
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var grants: [TimeInterval] = []

    /// - Parameters:
    ///   - maxRequests: How many requests may start in one window.
    ///   - interval: The window, in seconds.
    public init(maxRequests: Int = 20, per interval: TimeInterval = 10) {
        let clock = ContinuousClock()
        let origin = clock.now
        self.init(
            maxRequests: maxRequests,
            per: interval,
            now: {
                let elapsed = origin.duration(to: clock.now)
                return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            },
            sleep: { seconds in
                try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            }
        )
    }

    /// A limiter with its own clock, for tests.
    public init(
        maxRequests: Int,
        per interval: TimeInterval,
        now: @escaping @Sendable () -> TimeInterval,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void
    ) {
        self.maxRequests = max(1, maxRequests)
        self.interval = interval
        self.now = now
        self.sleep = sleep
    }

    /// Waits until a request may start, then records it.
    public func acquire() async throws {
        while true {
            try Task.checkCancellation()
            let current = self.now()
            grants.removeAll { $0 <= current - interval }
            if grants.count < maxRequests {
                grants.append(current)
                return
            }
            // Wait until the oldest request leaves the window, then check again: other callers
            // may have been let through while this one slept.
            let wait = grants[0] + interval - current
            try await self.sleep(max(wait, 0.001))
        }
    }

    /// How many requests started in the current window.
    public var requestsInWindow: Int {
        let current = self.now()
        return grants.filter { $0 > current - interval }.count
    }
}

/// How ``TVMazeClient`` retries a request answered with HTTP 429 (Too Many Requests).
public struct RetryPolicy: Sendable, Equatable {
    /// Retries after the first attempt. `0` turns retrying off.
    public var maxRetries: Int
    /// The wait before the first retry when the server sends no `Retry-After`; it doubles on every
    /// further retry.
    public var baseDelay: TimeInterval
    /// The longest wait between two attempts.
    public var maxDelay: TimeInterval

    public init(maxRetries: Int = 3, baseDelay: TimeInterval = 2, maxDelay: TimeInterval = 20) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Three retries, waiting 2, 4 and 8 seconds unless the server says otherwise.
    public static let standard = RetryPolicy()

    /// Never retry.
    public static let none = RetryPolicy(maxRetries: 0)

    /// The wait before retry number `retry` (1 for the first retry).
    public func delay(forRetry retry: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter {
            return min(max(retryAfter, 0), maxDelay)
        }
        let exponent = Double(max(retry - 1, 0))
        return min(baseDelay * pow(2, exponent), maxDelay)
    }
}
