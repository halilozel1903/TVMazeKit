import Foundation
import SwiftUI
import TVMazeKit
import TVMazeUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene loads real data from the live TVMaze API, with the real posters, stills and
/// headshots. The schedule scenes use a fixed day and the show scenes fixed shows, so the
/// captures stay comparable between runs.
enum ScreenshotScene: String {
    /// Apple TV: the hero show and the rails.
    case home
    /// Apple TV and iPhone: a show's page.
    case show
    /// iPhone: search results for "breaking".
    case search
    /// iPhone: the US schedule.
    case schedule

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    /// The day the schedule scenes show.
    static let date = CalendarDate(year: 2026, month: 10, day: 8)

    /// The show the `show` scene opens: Game of Thrones on Apple TV, Breaking Bad on iPhone.
    #if os(tvOS)
    static let showID = 82
    #else
    static let showID = 169
    #endif

    /// The query the `search` scene shows results for.
    static let searchQuery = "breaking"

    /// The image loader for the screenshot scenes: the network, retried a few times, and counted
    /// so the scene is only reported ready once every image on screen has loaded.
    static let imageLoader = TVMazeImageLoader { url in
        await ScreenshotImageTracker.shared.begin()
        var lastError: any Error = URLError(.unknown)
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if Task.isCancelled { break }
            do {
                let data = try await TVMazeImageLoader.urlSession.data(for: url)
                await ScreenshotImageTracker.shared.end(failed: false)
                return data
            } catch {
                lastError = error
                print("Screenshot image \(url) failed (attempt \(attempt + 1)): \(error)")
            }
        }
        // A view that went away cancels its load; that is not a failure.
        await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
        throw lastError
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed { state.failed += 1 }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until images have loaded and none started or finished for `quiet` seconds.
    /// Returns false, and the scene is never reported ready, when an image failed to load.
    static func waitUntilSettled(quiet: TimeInterval = 2.5) async -> Bool {
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                print("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started > 0, state.inFlight == 0, Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true (the data has loaded) and every image the
    /// scene shows has loaded too. Nothing is written when loading fails, so CI fails instead of
    /// committing a broken capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1))
            guard await ScreenshotImageTracker.waitUntilSettled(), !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
