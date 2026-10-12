import Foundation
import Observation
import TVMazeKit

/// The app's data: tonight's schedule, streaming releases, popular shows, a featured show and
/// show details, all from one `TVMazeClient` on the live API.
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

    /// The most popular shows of TVMaze's show index.
    private(set) var popular: [Show] = []

    private var detailCache: [Int: Show] = [:]
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    init(client: TVMazeClient, country: String = "US", date: CalendarDate? = nil, attempts: Int = 1) {
        self.client = client
        self.country = country
        self.date = date
        self.attempts = max(1, attempts)
    }

    /// A guide on the live API. Screenshot scenes show a fixed day and retry failed requests a few
    /// times, since a capture must not show an error.
    static func make(for scene: ScreenshotScene?) -> Guide {
        if scene != nil {
            return Guide(client: .shared, date: ScreenshotScene.date, attempts: 4)
        }
        return Guide(client: .shared)
    }

    /// The day shown, for headers.
    var day: CalendarDate {
        date ?? CalendarDate.today(in: TimeZone(identifier: "America/New_York") ?? .current)
    }

    // MARK: - Home

    /// Loads tonight's schedule, today's streaming releases, the most popular shows of the show
    /// index and the featured show's artwork.
    func loadHome() async {
        guard phase != .loading else { return }
        phase = .loading
        do {
            // Read the actor's state before the requests run in parallel child tasks.
            let client = self.client
            let country = self.country
            let date = self.date
            let (tvEpisodes, webEpisodes, index) = try await Self.retrying(attempts: attempts) {
                async let tv = client.schedule(country: country, date: date)
                async let web = client.webSchedule(date: date)
                async let shows = client.shows(page: 0)
                return try await (tv, web, shows)
            }
            tonight = tvEpisodes
            streaming = webEpisodes
            popular = Array(index.filter { $0.image != nil }.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }.prefix(30))
            let onTonight = tonightPopular
            if let pick = onTonight.first(where: { $0.image != nil && !$0.isStreaming }) ?? onTonight.first {
                // The images embed has the background for the hero.
                let pickID = pick.id
                featured = (try? await Self.retrying(attempts: attempts) {
                    try await client.show(id: pickID, embedding: [.images])
                }) ?? pick
            }
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Every show on tonight's TV and streaming schedule, most popular first.
    var tonightPopular: [Show] {
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
        let client = self.client
        let show = try await Self.retrying(attempts: attempts) {
            try await client.show(id: id, embedding: [.cast, .seasons, .episodes, .images])
        }
        detailCache[id] = show
        return show
    }

    /// Search results for a query.
    func search(_ query: String) async throws -> [ShowSearchResult] {
        let client = self.client
        return try await Self.retrying(attempts: attempts) {
            try await client.searchShows(query)
        }
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    private nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < attempts, !Task.isCancelled else { throw error }
                print("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 2))
                attempt += 1
            }
        }
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
