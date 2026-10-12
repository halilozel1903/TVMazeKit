import Foundation

/// A client for the free [TVMaze API](https://www.tvmaze.com/api).
///
/// Every endpoint is an `async throws` method that returns typed models. Requests go through a
/// rate limiter that keeps the client within TVMaze's 20 calls per 10 seconds, and a 429 answer is
/// retried after the server's `Retry-After` (or an exponential backoff).
///
/// ```swift
/// let tvmaze = TVMazeClient()
/// let results = try await tvmaze.searchShows("the long static")
/// let show = try await tvmaze.show(id: 1001, embedding: [.cast, .seasons, .episodes])
/// let tonight = try await tvmaze.schedule(country: "US")
/// ```
///
/// One client can be shared by the whole app; it is `Sendable` and keeps no per-request state.
/// Data from TVMaze is licensed under CC BY-SA: credit TVmaze.com where you show it.
public final class TVMazeClient: Sendable {
    /// A client with the default configuration, shared by everyone who uses it, so they share one
    /// rate limiter.
    public static let shared = TVMazeClient()

    public let configuration: TVMazeConfiguration
    /// The limiter requests wait on, or `nil` when rate limiting is off.
    public let rateLimiter: RateLimiter?
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    /// A client with its own rate limiter, built from `configuration.rateLimit`.
    public convenience init(configuration: TVMazeConfiguration = TVMazeConfiguration()) {
        let limiter = configuration.rateLimit.map { RateLimiter(maxRequests: $0.maxRequests, per: $0.interval) }
        self.init(configuration: configuration, rateLimiter: limiter)
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: TVMazeConfiguration(session: session))
    }

    /// A client with an explicit limiter (pass one limiter to several clients to share it) and,
    /// for tests, a custom way to wait between retries.
    public init(
        configuration: TVMazeConfiguration,
        rateLimiter: RateLimiter?,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.configuration = configuration
        self.rateLimiter = rateLimiter
        self.sleep = sleep
    }

    // MARK: - Search

    /// Shows whose name matches `query`, best match first (`/search/shows`). Fuzzy: typos still
    /// find the show.
    public func searchShows(_ query: String) async throws -> [ShowSearchResult] {
        try await get("search/shows", query: [URLQueryItem(name: "q", value: query)])
    }

    /// The single best match for `query`, or `nil` when nothing matches (`/singlesearch/shows`).
    public func singleSearchShow(_ query: String, embedding embeds: Set<ShowEmbed> = []) async throws -> Show? {
        try await getIfFound("singlesearch/shows", query: [URLQueryItem(name: "q", value: query)] + embedQuery(embeds))
    }

    /// The show with an IMDb, TheTVDB or TVRage id, or `nil` when TVMaze doesn't know it
    /// (`/lookup/shows`).
    public func lookupShow(_ id: ExternalID) async throws -> Show? {
        try await getIfFound("lookup/shows", query: [id.queryItem])
    }

    /// People whose name matches `query`, best match first (`/search/people`).
    public func searchPeople(_ query: String) async throws -> [PersonSearchResult] {
        try await get("search/people", query: [URLQueryItem(name: "q", value: query)])
    }

    // MARK: - Schedule

    /// Episodes airing on TV in a country on a day (`/schedule`), each with its ``Episode/show``.
    ///
    /// - Parameters:
    ///   - country: An ISO 3166-1 code such as `"US"` or `"GB"`; `nil` uses TVMaze's default (US).
    ///   - date: The day in that country; `nil` for today.
    public func schedule(country: String? = "US", date: CalendarDate? = nil) async throws -> [Episode] {
        var query: [URLQueryItem] = []
        if let country { query.append(URLQueryItem(name: "country", value: country)) }
        if let date { query.append(URLQueryItem(name: "date", value: date.description)) }
        return try await get("schedule", query: query)
    }

    /// Episodes released by streaming services on a day (`/schedule/web`), each with its show.
    ///
    /// - Parameters:
    ///   - date: The day; `nil` for today.
    ///   - country: `nil` for every web channel, a country code for that country's channels, or
    ///     `""` for global channels only.
    public func webSchedule(date: CalendarDate? = nil, country: String? = nil) async throws -> [Episode] {
        var query: [URLQueryItem] = []
        if let date { query.append(URLQueryItem(name: "date", value: date.description)) }
        if let country { query.append(URLQueryItem(name: "country", value: country)) }
        return try await get("schedule/web", query: query)
    }

    /// Every future episode TVMaze knows of, on TV and streaming (`/schedule/full`). Large: it is
    /// several megabytes and cached by TVMaze for 24 hours.
    public func fullSchedule() async throws -> [Episode] {
        try await get("schedule/full")
    }

    // MARK: - Shows

    /// A show, with related resources embedded (`/shows/:id`).
    ///
    /// ```swift
    /// let show = try await tvmaze.show(id: 1001, embedding: [.cast, .nextEpisode])
    /// show.cast                       // [CastCredit]
    /// show.embedded?.nextEpisode      // Episode?
    /// ```
    public func show(id: Int, embedding embeds: Set<ShowEmbed> = []) async throws -> Show {
        try await get("shows/\(id)", query: embedQuery(embeds))
    }

    /// The show's episodes in order (`/shows/:id/episodes`), with specials when asked for.
    public func episodes(showID: Int, includeSpecials: Bool = false) async throws -> [Episode] {
        try await get("shows/\(showID)/episodes", query: includeSpecials ? [URLQueryItem(name: "specials", value: "1")] : [])
    }

    /// One episode by its season and number, or `nil` when there is no such episode
    /// (`/shows/:id/episodebynumber`).
    public func episode(showID: Int, season: Int, number: Int) async throws -> Episode? {
        try await getIfFound("shows/\(showID)/episodebynumber", query: [
            URLQueryItem(name: "season", value: String(season)),
            URLQueryItem(name: "number", value: String(number)),
        ])
    }

    /// The episodes that aired on a day, empty when none did (`/shows/:id/episodesbydate`).
    public func episodes(showID: Int, airedOn date: CalendarDate) async throws -> [Episode] {
        let episodes: [Episode]? = try await getIfFound(
            "shows/\(showID)/episodesbydate",
            query: [URLQueryItem(name: "date", value: date.description)]
        )
        return episodes ?? []
    }

    /// The show's seasons (`/shows/:id/seasons`).
    public func seasons(showID: Int) async throws -> [Season] {
        try await get("shows/\(showID)/seasons")
    }

    /// The episodes of a season, by the season's id (`/seasons/:id/episodes`).
    public func seasonEpisodes(seasonID: Int) async throws -> [Episode] {
        try await get("seasons/\(seasonID)/episodes")
    }

    /// The main cast (`/shows/:id/cast`).
    public func cast(showID: Int) async throws -> [CastCredit] {
        try await get("shows/\(showID)/cast")
    }

    /// The crew (`/shows/:id/crew`).
    public func crew(showID: Int) async throws -> [CrewCredit] {
        try await get("shows/\(showID)/crew")
    }

    /// The show's other titles (`/shows/:id/akas`).
    public func akas(showID: Int) async throws -> [AKA] {
        try await get("shows/\(showID)/akas")
    }

    /// Posters, backgrounds, banners and typography (`/shows/:id/images`).
    public func images(showID: Int) async throws -> [ShowImage] {
        try await get("shows/\(showID)/images")
    }

    /// One page of every show in the database, 250 ids per page, ordered by id (`/shows?page=`).
    /// Returns an empty array past the last page.
    public func shows(page: Int) async throws -> [Show] {
        let shows: [Show]? = try await getIfFound("shows", query: [URLQueryItem(name: "page", value: String(page))])
        return shows ?? []
    }

    /// When each show last changed, by show id (`/updates/shows`). Use it to refresh a cache.
    public func showUpdates(since period: UpdatePeriod? = nil) async throws -> [Int: Date] {
        let query = period.map { [URLQueryItem(name: "since", value: $0.rawValue)] } ?? []
        let raw: [String: Int] = try await get("updates/shows", query: query)
        var updates: [Int: Date] = [:]
        for (key, timestamp) in raw {
            guard let id = Int(key) else { continue }
            updates[id] = Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        return updates
    }

    // MARK: - Episodes

    /// An episode by its id (`/episodes/:id`), optionally with its show embedded.
    public func episode(id: Int, embeddingShow: Bool = false) async throws -> Episode {
        try await get("episodes/\(id)", query: embeddingShow ? [URLQueryItem(name: "embed", value: "show")] : [])
    }

    /// Guest stars of an episode (`/episodes/:id/guestcast`).
    public func guestCast(episodeID: Int) async throws -> [CastCredit] {
        try await get("episodes/\(episodeID)/guestcast")
    }

    // MARK: - People

    /// A person (`/people/:id`).
    public func person(id: Int) async throws -> Person {
        try await get("people/\(id)")
    }

    /// Everything a person played in (`/people/:id/castcredits`), with the shows embedded unless
    /// `embeddingShows` is `false`.
    public func castCredits(personID: Int, embeddingShows: Bool = true) async throws -> [PersonCastCredit] {
        try await get("people/\(personID)/castcredits", query: embeddingShows ? [URLQueryItem(name: "embed", value: "show")] : [])
    }

    /// Every show a person worked on behind the camera (`/people/:id/crewcredits`).
    public func crewCredits(personID: Int, embeddingShows: Bool = true) async throws -> [PersonCrewCredit] {
        try await get("people/\(personID)/crewcredits", query: embeddingShows ? [URLQueryItem(name: "embed", value: "show")] : [])
    }

    // MARK: - Requests

    /// Builds the request for a path below the base URL. Exposed for tests and debugging.
    public func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TVMazeError.transport(URLError(.badURL))
        }
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" as is, but TVMaze reads it as a space ("Ctrl+Alt+Delight").
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let finalURL = components.url else {
            throw TVMazeError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: finalURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    /// Fetches and decodes a path. Use it for endpoints this client has no method for.
    public func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type = T.self) async throws -> T {
        let body = try await self.data(for: request(path: path, query: query))
        do {
            return try JSONDecoder().decode(T.self, from: body)
        } catch {
            throw TVMazeError.decoding(type: String(describing: T.self), description: String(describing: error))
        }
    }

    /// Like ``get(_:query:as:)``, but returns `nil` for HTTP 404.
    func getIfFound<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T? {
        do {
            let value: T = try await get(path, query: query)
            return value
        } catch TVMazeError.notFound {
            return nil
        }
    }

    /// Performs a request: waits for the rate limiter, retries 429s, maps errors.
    func data(for request: URLRequest) async throws -> Data {
        var retry = 0
        while true {
            if let rateLimiter {
                try await rateLimiter.acquire()
            }
            let result: (Data, URLResponse)
            do {
                result = try await configuration.session.data(for: request)
            } catch let error as URLError {
                throw TVMazeError.transport(error)
            }
            let (data, response) = result
            guard let http = response as? HTTPURLResponse else {
                throw TVMazeError.invalidResponse
            }
            let url = request.url ?? configuration.baseURL
            switch http.statusCode {
            case 200..<300:
                return data
            case 404:
                throw TVMazeError.notFound(url)
            case 429:
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap {
                    TimeInterval($0.trimmingCharacters(in: .whitespaces))
                }
                guard retry < configuration.retryPolicy.maxRetries else {
                    throw TVMazeError.rateLimited(retryAfter: retryAfter)
                }
                retry += 1
                try await self.sleep(configuration.retryPolicy.delay(forRetry: retry, retryAfter: retryAfter))
            default:
                throw TVMazeError.http(statusCode: http.statusCode, url: url)
            }
        }
    }

    /// `embed=x` for one resource, `embed[]=x&embed[]=y` for several, in a stable order.
    func embedQuery(_ embeds: Set<ShowEmbed>) -> [URLQueryItem] {
        let ordered = ShowEmbed.allCases.filter { embeds.contains($0) }
        switch ordered.count {
        case 0: return []
        case 1: return [URLQueryItem(name: "embed", value: ordered[0].rawValue)]
        default: return ordered.map { URLQueryItem(name: "embed[]", value: $0.rawValue) }
        }
    }
}

/// An id of a show on another site, for ``TVMazeClient/lookupShow(_:)``.
public enum ExternalID: Hashable, Sendable {
    /// An IMDb id such as `"tt0944947"`.
    case imdb(String)
    /// A TheTVDB id.
    case thetvdb(Int)
    /// A TVRage id.
    case tvrage(Int)

    var queryItem: URLQueryItem {
        switch self {
        case let .imdb(id): return URLQueryItem(name: "imdb", value: id)
        case let .thetvdb(id): return URLQueryItem(name: "thetvdb", value: String(id))
        case let .tvrage(id): return URLQueryItem(name: "tvrage", value: String(id))
        }
    }
}
