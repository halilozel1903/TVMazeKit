import Foundation
import SwiftUI
import TVMazeKit

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected and use the live API.
///
/// Every scene loads the recorded fixtures (see `DemoFixtures`) for Thursday, October 8, 2026, so
/// the captures never depend on the network or the day CI runs.
enum ScreenshotScene: String {
    /// Apple TV: the hero show and the rails.
    case home
    /// Apple TV and iPhone: the detail page of The Long Static.
    case show
    /// iPhone: search results for "night".
    case search
    /// iPhone: tonight's US schedule.
    case schedule

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    /// The day the fixtures were recorded for.
    static let date = CalendarDate(year: 2026, month: 10, day: 8)

    /// The show the `show` scene opens.
    static let showID = 1001

    /// The query the `search` scene shows results for.
    static let searchQuery = "night"
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true and images and focus had time to settle.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
