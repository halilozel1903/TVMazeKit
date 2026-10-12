import Foundation

/// Errors thrown by ``TVMazeClient``.
public enum TVMazeError: Error, Equatable, Sendable, LocalizedError {
    /// The resource does not exist (HTTP 404).
    case notFound(URL)
    /// Still rate limited (HTTP 429) after every retry. `retryAfter` is the server's hint in
    /// seconds, when it sent one.
    case rateLimited(retryAfter: TimeInterval?)
    /// Any other unsuccessful HTTP status.
    case http(statusCode: Int, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "TVMaze has nothing at this address."
        case .rateLimited:
            return "TVMaze is receiving too many requests. Try again in a few seconds."
        case let .http(statusCode, _):
            return "TVMaze answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "TVMaze sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "TVMaze sent an invalid response."
        }
    }
}
