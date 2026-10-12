import SwiftUI
import TVMazeKit
import TVMazeUI

/// The home screen: tonight's most popular show as the hero, then rails for what airs tonight,
/// what's popular and the biggest genres.
struct TVHomeView: View {
    let scene: ScreenshotScene?
    @Environment(Guide.self) private var guide

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            switch guide.phase {
            case let .failed(message):
                TVMessage(title: "Couldn't load tonight's schedule", message: message) {
                    Task { await guide.loadHome() }
                }
            default:
                if let featured = guide.featured {
                    content(featured: featured)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            if guide.phase == .idle {
                await guide.loadHome()
            }
        }
        .signalsScreenshotReady(scene, when: guide.phase == .loaded)
    }

    private func content(featured: Show) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 40) {
                TVHero(show: featured, episode: guide.tonightEpisode(of: featured))

                TVRail(title: "Airing tonight", subtitle: Theme.longDay(guide.day)) {
                    ForEach(guide.tonight.scheduleSlots().flatMap(\.entries)) { entry in
                        card(entry.show, caption: caption(for: entry))
                    }
                }

                TVRail(title: "Popular", subtitle: "On TV and streaming today") {
                    ForEach(guide.popular) { show in
                        card(show, caption: nil)
                    }
                }

                ForEach(guide.genreRails()) { rail in
                    TVRail(title: rail.genre) {
                        ForEach(rail.shows) { show in
                            card(show, caption: nil)
                        }
                    }
                }

                TVMazeAttributionView()
                    .padding(.horizontal, 80)
                    .padding(.bottom, 60)
            }
        }
        // The hero runs to the screen's edges; rails keep their own 80-point inset.
        .ignoresSafeArea()
    }

    private func card(_ show: Show, caption: String?) -> some View {
        NavigationLink(value: show.id) {
            ShowCard(show: show, caption: caption)
        }
        .buttonStyle(TVMazeCardButtonStyle())
    }

    /// "9:00 PM · Northwind".
    private func caption(for entry: ScheduleEntry) -> String {
        let time = entry.episode?.airTime?.formatted() ?? "Today"
        guard let channel = entry.show.channel?.name else { return time }
        return time + " · " + channel
    }
}

/// The featured show over its background artwork.
struct TVHero: View {
    let show: Show
    let episode: Episode?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TVMazeImage(url: show.backgroundImageURL ?? show.image?.original, title: show.name)
            LinearGradient(
                colors: [Theme.background.opacity(0.95), Theme.background.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: UnitPoint(x: 0.75, y: 0.5)
            )
            LinearGradient(
                colors: [Theme.background, .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )

            VStack(alignment: .leading, spacing: 16) {
                BrandMark(size: 26)
                    .padding(.bottom, 18)
                if let episode {
                    Label(tonightLine(episode), systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.moon)
                }
                Text(show.name)
                    .font(.system(size: 80, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 18) {
                    RatingBadge(show.rating?.average)
                    Text(Theme.showFacts(show))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                if let summary = show.plainSummary {
                    Text(summary)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: 980, alignment: .leading)
                }
                NavigationLink(value: show.id) {
                    Label("Episodes & Cast", systemImage: "list.bullet.rectangle")
                }
                .padding(.top, 12)
            }
            .padding(.leading, 80)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 640)
        .clipped()
    }

    /// "Tonight 9:00 PM on Northwind · S2 · E5 Interference".
    private func tonightLine(_ episode: Episode) -> String {
        var line = "Tonight"
        if let time = episode.airTime { line += " " + time.formatted() }
        if let channel = show.channel?.name { line += " on " + channel }
        return line + " · " + episode.shortCode + " " + episode.name
    }
}
