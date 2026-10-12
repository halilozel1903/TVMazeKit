import Foundation
import TVMazeKit
import TVMazeUI

/// Recorded responses for the screenshot scenes, so CI never depends on the network. The shows are
/// made up, in TVMaze's exact JSON shapes, and their posters are bundled artwork generated for the
/// demo (`bundle://artwork/poster-1001.jpg`).
enum DemoFixtures {
    /// A client whose requests are answered from `Fixtures/*.json` in the app bundle.
    static func makeClient() -> TVMazeClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return TVMazeClient(
            configuration: TVMazeConfiguration(session: URLSession(configuration: configuration), rateLimit: nil),
            rateLimiter: nil
        )
    }

    /// Loads `bundle://artwork/<file>` from the app bundle and everything else from the network.
    static let imageLoader = TVMazeImageLoader { url in
        if url.scheme == "bundle" {
            let name = url.deletingPathExtension().lastPathComponent
            guard let file = Bundle.main.url(forResource: name, withExtension: url.pathExtension) else {
                throw URLError(.fileDoesNotExist)
            }
            return try Data(contentsOf: file)
        }
        return try await TVMazeImageLoader.urlSession.data(for: url)
    }
}

/// Serves the bundled fixture for a TVMaze path, or a 404 when there is none.
final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        var status = 404
        var body = Data()
        if let name = Self.fixtureName(for: url),
           let file = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: file) {
            status = 200
            body = data
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func fixtureName(for url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        switch parts.count {
        case 1 where parts[0] == "schedule":
            return "schedule-us"
        case 2 where parts == ["schedule", "web"]:
            return "schedule-web"
        case 2 where parts == ["search", "shows"]:
            return "search-shows"
        case 2 where parts[0] == "shows":
            guard let id = Int(parts[1]) else { return nil }
            return "show-" + String(id)
        default:
            return nil
        }
    }
}
