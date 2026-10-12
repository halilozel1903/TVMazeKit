import SwiftUI
import TVMazeKit
import TVMazeUI

/// Searches TVMaze as you type (debounced). With an empty field it suggests popular shows.
struct SearchScreen: View {
    let scene: ScreenshotScene?
    @Binding var path: [Int]

    @Environment(Guide.self) private var guide
    @State private var query: String
    @State private var results: [ShowSearchResult] = []
    @State private var resultsQuery: String?
    @State private var errorMessage: String?

    init(scene: ScreenshotScene?, path: Binding<[Int]>) {
        self.scene = scene
        _path = path
        _query = State(initialValue: scene == .search ? ScreenshotScene.searchQuery : "")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmedQuery.isEmpty {
                    Section("Popular on TVMaze") {
                        ForEach(guide.popular.prefix(8)) { show in
                            row(show)
                        }
                    }
                } else if let errorMessage {
                    ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .listRowBackground(Theme.background)
                } else if resultsQuery == trimmedQuery, results.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                        .listRowBackground(Theme.background)
                } else {
                    ForEach(results) { result in
                        row(result.show)
                    }
                }
                Section {
                    TVMazeAttributionView()
                        .listRowBackground(Theme.background)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Search")
            // iOS 26 leaves the large title out with a pinned bar background; keep it inline.
            .navigationBarTitleDisplayMode(.inline)
            .tonightNavigationBar()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Shows on TVMaze")
            .autocorrectionDisabled()
            .task(id: trimmedQuery) {
                await search(trimmedQuery)
            }
            .task {
                if guide.phase == .idle {
                    await guide.loadHome()
                }
            }
            .navigationDestination(for: Int.self) { id in
                PhoneShowView(showID: id, scene: scene == .show ? scene : nil)
            }
        }
        .signalsScreenshotReady(scene == .search ? scene : nil, when: resultsQuery == trimmedQuery && !results.isEmpty)
    }

    private func row(_ show: Show) -> some View {
        NavigationLink(value: show.id) {
            ShowCard(show: show, style: .row)
                .padding(.vertical, 4)
        }
        .listRowBackground(Theme.background)
    }

    private func search(_ text: String) async {
        guard !text.isEmpty else {
            results = []
            resultsQuery = nil
            errorMessage = nil
            return
        }
        if scene == nil {
            // Wait for a pause in typing; a new keystroke cancels this task.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
        }
        do {
            let found = try await guide.search(text)
            guard !Task.isCancelled else { return }
            results = found
            resultsQuery = text
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
