import Foundation
import Testing
@testable import TVMazeKit

@Suite("Rate limiting and retries")
struct RateLimitTests {
    @Test func limiterLetsAFullWindowThrough() async throws {
        let clock = FakeClock()
        let limiter = clock.limiter(maxRequests: 3, per: 10)

        try await limiter.acquire()
        try await limiter.acquire()
        try await limiter.acquire()

        #expect(clock.recordedSleeps.isEmpty)
        let inWindow = await limiter.requestsInWindow
        #expect(inWindow == 3)
    }

    @Test func limiterWaitsForTheOldestRequestToLeaveTheWindow() async throws {
        let clock = FakeClock()
        let limiter = clock.limiter(maxRequests: 3, per: 10)

        try await limiter.acquire()      // t = 0
        clock.advance(by: 4)
        try await limiter.acquire()      // t = 4
        clock.advance(by: 4)
        try await limiter.acquire()      // t = 8
        try await limiter.acquire()      // waits until t = 10

        let expected: [TimeInterval] = [2]
        #expect(clock.recordedSleeps == expected)
        #expect(clock.now == 10)
        let inWindow = await limiter.requestsInWindow
        #expect(inWindow == 3)
    }

    @Test func limiterDefaultsToTVMazesLimit() {
        let limiter = RateLimiter()
        #expect(limiter.maxRequests == 20)
        #expect(limiter.interval == 10)
        #expect(TVMazeConfiguration().rateLimit == .tvMaze)
    }

    @Test func clientWaitsOnItsLimiter() async throws {
        let clock = FakeClock()
        let stub = StubbedClient(rateLimiter: clock.limiter(maxRequests: 2, per: 10)) { _ in try .json("show") }

        for _ in 0..<5 {
            _ = try await stub.client.show(id: 1001)
        }

        #expect(stub.requests.count == 5)
        let expected: [TimeInterval] = [10, 10]
        #expect(clock.recordedSleeps == expected)
    }

    @Test func retriesAfterTooManyRequests() async throws {
        let counter = Counter()
        let stub = StubbedClient { _ in
            try counter.increment() <= 2 ? .status(429, headers: ["Retry-After": "1"]) : .json("show")
        }

        let show = try await stub.client.show(id: 1001)

        #expect(show.id == 1001)
        #expect(stub.requests.count == 3)
        let delays = await stub.sleeps.delays
        let expected: [TimeInterval] = [1, 1]
        #expect(delays == expected)
    }

    @Test func backsOffWithoutRetryAfter() async throws {
        let stub = StubbedClient(retryPolicy: RetryPolicy(maxRetries: 3, baseDelay: 2, maxDelay: 5)) { _ in
            .status(429)
        }

        do {
            _ = try await stub.client.show(id: 1001)
            Issue.record("Expected an error")
        } catch let error as TVMazeError {
            #expect(error == .rateLimited(retryAfter: nil))
        }

        #expect(stub.requests.count == 4)
        let delays = await stub.sleeps.delays
        let expected: [TimeInterval] = [2, 4, 5]
        #expect(delays == expected)
    }

    @Test func retryingCanBeTurnedOff() async throws {
        let stub = StubbedClient(retryPolicy: .none) { _ in .status(429, headers: ["Retry-After": "7"]) }

        do {
            _ = try await stub.client.show(id: 1001)
            Issue.record("Expected an error")
        } catch let error as TVMazeError {
            #expect(error == .rateLimited(retryAfter: 7))
        }
        #expect(stub.requests.count == 1)
    }

    @Test func retryDelays() {
        let policy = RetryPolicy(maxRetries: 5, baseDelay: 1, maxDelay: 6)
        #expect(policy.delay(forRetry: 1, retryAfter: nil) == 1)
        #expect(policy.delay(forRetry: 2, retryAfter: nil) == 2)
        #expect(policy.delay(forRetry: 3, retryAfter: nil) == 4)
        #expect(policy.delay(forRetry: 4, retryAfter: nil) == 6)
        #expect(policy.delay(forRetry: 1, retryAfter: 3) == 3)
        #expect(policy.delay(forRetry: 1, retryAfter: 60) == 6)
    }
}

/// A thread-safe counter for stub handlers.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    /// Adds one and returns the new value.
    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
