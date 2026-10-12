import SwiftUI
import TVMazeKit
import TVMazeUI

/// Tonight's schedule for a country, on TV or streaming, grouped by start time.
struct ScheduleScreen: View {
    enum Kind: String, CaseIterable, Identifiable {
        case tv = "TV"
        case streaming = "Streaming"

        var id: Self { self }
    }

    let scene: ScreenshotScene?
    @Binding var path: [Int]

    @Environment(Guide.self) private var guide
    @State private var kind: Kind = .tv

    private let countries = ["US", "GB", "CA", "AU", "DE", "FR"]

    init(scene: ScreenshotScene?, path: Binding<[Int]>) {
        self.scene = scene
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch guide.phase {
                case let .failed(message):
                    ContentUnavailableView {
                        Label("No schedule", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task { await guide.loadHome() }
                        }
                    }
                case .loaded:
                    ScheduleList(episodes: kind == .tv ? guide.tonightEvening : guide.streaming, untimedTitle: "Out today") { entry in
                        path.append(entry.show.id)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Theme.longDay(guide.day))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Schedule", selection: $kind) {
                        ForEach(Kind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .background(Theme.background)
            }
            .navigationTitle("Tonight")
            // iOS 26 leaves the large title out with a pinned bar background; keep it inline.
            .navigationBarTitleDisplayMode(.inline)
            .tonightNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(countries, id: \.self) { code in
                            Button {
                                Task { await guide.switchCountry(to: code) }
                            } label: {
                                Text(Locale.current.localizedString(forRegionCode: code) ?? code)
                            }
                        }
                    } label: {
                        Label(guide.country, systemImage: "globe")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .navigationDestination(for: Int.self) { id in
                PhoneShowView(showID: id, scene: nil)
            }
        }
        .task {
            if guide.phase == .idle {
                await guide.loadHome()
            }
        }
        .signalsScreenshotReady(scene, when: guide.phase == .loaded)
    }
}
