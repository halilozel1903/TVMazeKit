import SwiftUI
import TVMazeKit
import TVMazeUI

@main
struct TonightPhoneApp: App {
    @State private var guide: Guide

    init() {
        _guide = State(initialValue: Guide.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(scene: ScreenshotScene.current)
                .environment(guide)
                // Bundled artwork for the fixtures, the network for everything else.
                .tvMazeImageLoader(DemoFixtures.imageLoader)
                .preferredColorScheme(.dark)
                .tint(Theme.moon)
        }
    }
}

/// Two tabs: tonight's schedule and search. Each has its own navigation stack to show pages.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case schedule
        case search
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab
    @State private var schedulePath: [Int] = []
    @State private var searchPath: [Int]

    init(scene: ScreenshotScene?) {
        self.scene = scene
        let opensSearch = scene == .search || scene == .show
        _tab = State(initialValue: opensSearch ? .search : .schedule)
        // The show scene starts on the show's page, pushed without an animation.
        _searchPath = State(initialValue: scene == .show ? [ScreenshotScene.showID] : [])
    }

    var body: some View {
        TabView(selection: $tab) {
            ScheduleScreen(scene: scene == .schedule ? scene : nil, path: $schedulePath)
                .tabItem { Label("Tonight", systemImage: "moon.stars") }
                .tag(Tab.schedule)
            SearchScreen(scene: scene, path: $searchPath)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
        }
    }
}

extension View {
    /// The app's dark, opaque navigation bar. iOS 26 bars are transparent by default; an inline
    /// title over scrolled content would be unreadable.
    @MainActor
    func tonightNavigationBar() -> some View {
        toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
