import SwiftUI
import TVMazeKit
import TVMazeUI

@main
struct TonightTVApp: App {
    @State private var guide: Guide

    init() {
        _guide = State(initialValue: Guide.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            TVRootView(scene: ScreenshotScene.current)
                .environment(guide)
                // Bundled artwork for the fixtures, the network for everything else.
                .tvMazeImageLoader(DemoFixtures.imageLoader)
                .preferredColorScheme(.dark)
        }
    }
}

struct TVRootView: View {
    let scene: ScreenshotScene?
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if scene == .show {
                    TVShowView(showID: ScreenshotScene.showID, scene: scene)
                } else {
                    TVHomeView(scene: scene)
                }
            }
            .navigationDestination(for: Int.self) { id in
                TVShowView(showID: id, scene: nil)
            }
        }
    }
}

/// A row title and a horizontal, focusable rail of cards.
struct TVRail<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 80)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 44) {
                    content
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 34)
            }
            .scrollIndicators(.hidden)
            // Focused cards grow; let them draw outside the rail.
            .scrollClipDisabled()
            .focusSection()
        }
    }
}

/// A full-screen message with a retry button.
struct TVMessage: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
            Button("Try Again", action: retry)
        }
    }
}
