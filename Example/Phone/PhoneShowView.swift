import SwiftUI
import TVMazeKit
import TVMazeUI

/// A show's page on iPhone: artwork, facts, summary, cast, and the episodes of a season.
struct PhoneShowView: View {
    let showID: Int
    let scene: ScreenshotScene?

    @Environment(Guide.self) private var guide
    @State private var show: Show?
    @State private var errorMessage: String?
    @State private var season: Int?
    @State private var summaryExpanded = false

    init(showID: Int, scene: ScreenshotScene?) {
        self.showID = showID
        self.scene = scene
    }

    var body: some View {
        Group {
            if let show {
                content(show)
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load this show", systemImage: "tv.slash", description: Text(errorMessage))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(show?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .tonightNavigationBar()
        .task(id: showID) {
            await load()
        }
        .signalsScreenshotReady(scene, when: show != nil)
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await guide.details(of: showID)
            season = loaded.defaultSeasonNumber
            show = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func content(_ show: Show) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(show)

                if let summary = show.plainSummary {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(summaryExpanded ? nil : 4)
                        Button(summaryExpanded ? "Less" : "More") {
                            withAnimation { summaryExpanded.toggle() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                }

                if !show.cast.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Cast")
                        CastStrip(cast: show.cast)
                            .contentMargins(.horizontal, 16, for: .scrollContent)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Episodes")
                    seasonPicker(show)
                    episodes(show)
                }

                TVMazeAttributionView()
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
    }

    private func header(_ show: Show) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TVMazeImage(url: show.backgroundImageURL ?? show.image?.original, title: show.name)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .overlay {
                    LinearGradient(colors: [.clear, Theme.background], startPoint: .center, endPoint: .bottom)
                }
                .clipped()
            HStack(alignment: .bottom, spacing: 16) {
                TVMazeImage(url: show.image?.preferred, title: show.name)
                    .frame(width: 112, height: 157)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.name)
                        .font(.title2.bold())
                        .lineLimit(2)
                    Text(Theme.showFacts(show))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let airing = Theme.airing(show) {
                        Text(airing)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.moon)
                            .lineLimit(2)
                    }
                    RatingBadge(show.rating?.average)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, -80)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .padding(.horizontal, 16)
    }

    private func seasonPicker(_ show: Show) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(show.episodes.seasonNumbers, id: \.self) { number in
                    Button {
                        season = number
                    } label: {
                        Text("Season \(number)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(season == number ? Color.black : Color.white)
                            .background(Capsule().fill(season == number ? Theme.moon : Theme.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func episodes(_ show: Show) -> some View {
        let list = season.map { show.episodes.inSeason($0) } ?? []
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(list) { episode in
                EpisodeRow(episode: episode)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}
