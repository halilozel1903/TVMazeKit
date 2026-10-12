import Foundation
import Observation
import TVMazeKit

/// The app's data: tonight's schedule, streaming releases, a featured show and show details,
/// all from one `TVMazeClient`.
@Observable
@MainActor
final class Guide {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let client: TVMazeClient
    /// The schedule's country.
    var country: String
    /// The schedule's day; `nil` for today.
    let date: CalendarDate?

    private(set) var tonight: [Episode] = []
    private(set) var streaming: [Episode] = []
    private(set) var featured: Show?
    private(set) var phase: Phase = .idle

    private var detailCache: [Int: Show] = [:]

    init(client: TVMazeClient, country: String = "US", date: CalendarDate? = nil) {
        self.client = client
        self.country = country
        self.date = date
    }

    /// A guide on the live API, or on the recorded fixtures for a screenshot scene.
    static func make(for scene: ScreenshotScene?) -> Guide {
        if scene != nil {
            return Guide(client: DemoFixtures.makeClient(), date: ScreenshotScene.date)
        }
        return Guide(client: .shared)
    }

    /// The day shown, for headers.
    var day: CalendarDate {
        date ?? CalendarDate.today(in: TimeZone(identifier: "America/New_York") ?? .current)
    }

    // MARK: - Home

    /// Loads tonight's schedule, today's streaming releases and the featured show's artwork.
    func loadHome() async {
        guard phase != .loading else { return }
        phase = .loading
        do {
            // Read the actor's state before the requests run in parallel child tasks.
            let client = self.client
            let country = self.country
            let date = self.date
            async let tv = client.schedule(country: country, date: date)
            async let web = client.webSchedule(date: date)
            let (tvEpisodes, webEpisodes) = try await (tv, web)
            tonight = tvEpisodes
            streaming = webEpisodes
            if let pick = popular.first(where: { $0.image != nil && !$0.isStreaming }) ?? popular.first {
                // The images embed has the background for the hero.
                featured = (try? await client.show(id: pick.id, embedding: [.images])) ?? pick
            }
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Every show on tonight's TV and streaming schedule, most popular first.
    var popular: [Show] {
        var seen = Set<Int>()
        let all = (tonight.uniqueShows + streaming.uniqueShows).filter { seen.insert($0.id).inserted }
        return all.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
    }

    /// Tonight's episode of a show, if it is on the TV schedule.
    func tonightEpisode(of show: Show) -> Episode? {
        tonight.first { $0.show?.id == show.id }
    }

    /// The most common genres among the popular shows, each with its shows.
    func genreRails(limit: Int = 3, minimumShows: Int = 3) -> [GenreRail] {
        let shows = popular
        var counts: [String: Int] = [:]
        for show in shows {
            for genre in show.genres {
                counts[genre, default: 0] += 1
            }
        }
        let genres = counts
            .filter { $0.value >= minimumShows }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map(\.key)
        return genres.map { genre in GenreRail(genre: genre, shows: shows.filter { $0.genres.contains(genre) }) }
    }

    // MARK: - Shows

    /// A show with its cast, seasons, episodes and images, cached after the first load.
    func details(of id: Int) async throws -> Show {
        if let cached = detailCache[id] {
            return cached
        }
        let show = try await client.show(id: id, embedding: [.cast, .seasons, .episodes, .images])
        detailCache[id] = show
        return show
    }

    /// Search results for a query.
    func search(_ query: String) async throws -> [ShowSearchResult] {
        try await client.searchShows(query)
    }

    /// Reloads the schedule for another country.
    func switchCountry(to code: String) async {
        guard code != country else { return }
        country = code
        phase = .idle
        await loadHome()
    }
}

/// A genre and the popular shows in it.
struct GenreRail: Identifiable {
    let genre: String
    let shows: [Show]

    var id: String { genre }
}

extension Show {
    /// The season to open a show on: the next episode's, else the latest one.
    var defaultSeasonNumber: Int? {
        if let nextID = links?.nextEpisode?.id,
           let next = episodes.first(where: { $0.id == nextID }) {
            return next.season
        }
        return episodes.seasonNumbers.last ?? seasons.last?.number
    }
}
