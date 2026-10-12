import Foundation

/// A TV show, as returned by `/shows/:id`, search, lookup and the schedule.
///
/// Field names follow the API; nested objects such as `rating.average` and `schedule.days` are
/// typed. Related resources requested with `embed` are in ``embedded``.
public struct Show: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    /// The show's page on tvmaze.com.
    public var url: URL?
    public var name: String
    public var type: ShowType?
    public var language: String?
    public var genres: [String]
    public var status: ShowStatus?
    /// Minutes, when every episode has the same length.
    public var runtime: Int?
    /// Average episode length in minutes.
    public var averageRuntime: Int?
    public var premiered: CalendarDate?
    public var ended: CalendarDate?
    public var officialSite: URL?
    public var schedule: Schedule?
    public var rating: Rating?
    /// TVMaze's popularity score, 0...100.
    public var weight: Int?
    public var network: Network?
    public var webChannel: Network?
    public var dvdCountry: Country?
    public var externals: Externals?
    public var image: ImageLinks?
    /// The summary as HTML. Use ``plainSummary`` to show it.
    public var summary: String?
    /// When TVMaze last changed the show, in seconds since 1970.
    public var updated: Int?
    public var links: Links?
    public var embedded: ShowEmbedded?

    public init(
        id: Int,
        name: String,
        url: URL? = nil,
        type: ShowType? = nil,
        language: String? = nil,
        genres: [String] = [],
        status: ShowStatus? = nil,
        runtime: Int? = nil,
        averageRuntime: Int? = nil,
        premiered: CalendarDate? = nil,
        ended: CalendarDate? = nil,
        officialSite: URL? = nil,
        schedule: Schedule? = nil,
        rating: Rating? = nil,
        weight: Int? = nil,
        network: Network? = nil,
        webChannel: Network? = nil,
        dvdCountry: Country? = nil,
        externals: Externals? = nil,
        image: ImageLinks? = nil,
        summary: String? = nil,
        updated: Int? = nil,
        links: Links? = nil,
        embedded: ShowEmbedded? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.type = type
        self.language = language
        self.genres = genres
        self.status = status
        self.runtime = runtime
        self.averageRuntime = averageRuntime
        self.premiered = premiered
        self.ended = ended
        self.officialSite = officialSite
        self.schedule = schedule
        self.rating = rating
        self.weight = weight
        self.network = network
        self.webChannel = webChannel
        self.dvdCountry = dvdCountry
        self.externals = externals
        self.image = image
        self.summary = summary
        self.updated = updated
        self.links = links
        self.embedded = embedded
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, type, language, genres, status, runtime, averageRuntime, premiered, ended
        case officialSite, schedule, rating, weight, network, webChannel, dvdCountry, externals, image
        case summary, updated
        case links = "_links"
        case embedded = "_embedded"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        url = c.lenientURL(forKey: .url)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decodeIfPresent(ShowType.self, forKey: .type)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        status = try c.decodeIfPresent(ShowStatus.self, forKey: .status)
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime)
        averageRuntime = try c.decodeIfPresent(Int.self, forKey: .averageRuntime)
        premiered = c.lenientDate(forKey: .premiered)
        ended = c.lenientDate(forKey: .ended)
        officialSite = c.lenientURL(forKey: .officialSite)
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule)
        rating = try c.decodeIfPresent(Rating.self, forKey: .rating)
        weight = try c.decodeIfPresent(Int.self, forKey: .weight)
        network = try c.decodeIfPresent(Network.self, forKey: .network)
        webChannel = try c.decodeIfPresent(Network.self, forKey: .webChannel)
        dvdCountry = try c.decodeIfPresent(Country.self, forKey: .dvdCountry)
        externals = try c.decodeIfPresent(Externals.self, forKey: .externals)
        image = try c.decodeIfPresent(ImageLinks.self, forKey: .image)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        updated = try c.decodeIfPresent(Int.self, forKey: .updated)
        links = try c.decodeIfPresent(Links.self, forKey: .links)
        embedded = try c.decodeIfPresent(ShowEmbedded.self, forKey: .embedded)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encode(genres, forKey: .genres)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(runtime, forKey: .runtime)
        try c.encodeIfPresent(averageRuntime, forKey: .averageRuntime)
        try c.encodeIfPresent(premiered, forKey: .premiered)
        try c.encodeIfPresent(ended, forKey: .ended)
        try c.encodeIfPresent(officialSite, forKey: .officialSite)
        try c.encodeIfPresent(schedule, forKey: .schedule)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encodeIfPresent(network, forKey: .network)
        try c.encodeIfPresent(webChannel, forKey: .webChannel)
        try c.encodeIfPresent(dvdCountry, forKey: .dvdCountry)
        try c.encodeIfPresent(externals, forKey: .externals)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(updated, forKey: .updated)
        try c.encodeIfPresent(links, forKey: .links)
        try c.encodeIfPresent(embedded, forKey: .embedded)
    }
}

// MARK: - Conveniences

extension Show {
    /// The summary without HTML, or `nil` when there is none.
    public var plainSummary: String? {
        guard let summary else { return nil }
        let text = HTMLText.plainText(from: summary)
        return text.isEmpty ? nil : text
    }

    /// The network or, for streaming shows, the web channel.
    public var channel: Network? { network ?? webChannel }

    /// Whether the show streams on a web channel instead of airing on a network.
    public var isStreaming: Bool { network == nil && webChannel != nil }

    /// The year the show premiered.
    public var premieredYear: Int? { premiered?.year }

    /// "2025–" for a running show, "2019–2023" for an ended one.
    public var yearsText: String? {
        guard let start = premiered?.year else { return nil }
        if let end = ended?.year {
            return end == start ? "\(start)" : "\(start)–\(end)"
        }
        return status == .ended ? "\(start)" : "\(start)–"
    }

    /// The time zone the schedule is in: the network's country, else the web channel's.
    public var scheduleTimeZone: TimeZone? {
        network?.country?.timeZone ?? webChannel?.country?.timeZone
    }

    /// Embedded cast, or an empty array when it was not requested.
    public var cast: [CastCredit] { embedded?.cast ?? [] }

    /// Embedded episodes, or an empty array when they were not requested.
    public var episodes: [Episode] { embedded?.episodes ?? [] }

    /// Embedded seasons, or an empty array when they were not requested.
    public var seasons: [Season] { embedded?.seasons ?? [] }

    /// The main background image from embedded images, for a hero banner.
    public var backgroundImageURL: URL? {
        embedded?.images?.first(ofKind: .background)?.resolutions.original.url
    }
}

/// Resources embedded in a show with `embed`, in `_embedded`.
public struct ShowEmbedded: Codable, Hashable, Sendable {
    public var episodes: [Episode]?
    public var cast: [CastCredit]?
    public var crew: [CrewCredit]?
    public var seasons: [Season]?
    public var images: [ShowImage]?
    public var akas: [AKA]?
    public var nextEpisode: Episode?
    public var previousEpisode: Episode?

    public init(
        episodes: [Episode]? = nil,
        cast: [CastCredit]? = nil,
        crew: [CrewCredit]? = nil,
        seasons: [Season]? = nil,
        images: [ShowImage]? = nil,
        akas: [AKA]? = nil,
        nextEpisode: Episode? = nil,
        previousEpisode: Episode? = nil
    ) {
        self.episodes = episodes
        self.cast = cast
        self.crew = crew
        self.seasons = seasons
        self.images = images
        self.akas = akas
        self.nextEpisode = nextEpisode
        self.previousEpisode = previousEpisode
    }

    enum CodingKeys: String, CodingKey {
        case episodes, cast, crew, seasons, images, akas
        case nextEpisode = "nextepisode"
        case previousEpisode = "previousepisode"
    }
}

/// What can be embedded in a show with `embed[]`.
public enum ShowEmbed: String, Sendable, CaseIterable, Hashable {
    case episodes
    case cast
    case crew
    case seasons
    case images
    case akas
    case nextEpisode = "nextepisode"
    case previousEpisode = "previousepisode"
}

/// When a show airs: a network-local time and the days of the week.
public struct Schedule: Codable, Hashable, Sendable {
    /// `HH:mm` in the network's time zone, or an empty string.
    public var time: String
    public var days: [Weekday]

    public init(time: String, days: [Weekday]) {
        self.time = time
        self.days = days
    }

    /// The time, or `nil` when the show has no fixed time.
    public var airTime: AirTime? { AirTime(time) }

    enum CodingKeys: String, CodingKey { case time, days }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        // Unknown day names are skipped instead of failing the whole show.
        let names = try c.decodeIfPresent([String].self, forKey: .days) ?? []
        days = names.compactMap(Weekday.init(rawValue:))
    }
}

/// A day of the week, as spelled in `schedule.days`.
public enum Weekday: String, Codable, Hashable, Sendable, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
}

/// IDs of the show on other sites. Use them with ``TVMazeClient/lookupShow(_:)``.
public struct Externals: Codable, Hashable, Sendable {
    public var tvrage: Int?
    public var thetvdb: Int?
    public var imdb: String?

    public init(tvrage: Int? = nil, thetvdb: Int? = nil, imdb: String? = nil) {
        self.tvrage = tvrage
        self.thetvdb = thetvdb
        self.imdb = imdb
    }
}

/// A show's status. Known values are constants; anything else TVMaze adds still decodes.
public struct ShowStatus: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let running: ShowStatus = "Running"
    public static let ended: ShowStatus = "Ended"
    public static let toBeDetermined: ShowStatus = "To Be Determined"
    public static let inDevelopment: ShowStatus = "In Development"
}

/// A show's type. Known values are constants; anything else TVMaze adds still decodes.
public struct ShowType: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let scripted: ShowType = "Scripted"
    public static let animation: ShowType = "Animation"
    public static let reality: ShowType = "Reality"
    public static let talkShow: ShowType = "Talk Show"
    public static let documentary: ShowType = "Documentary"
    public static let gameShow: ShowType = "Game Show"
    public static let news: ShowType = "News"
    public static let sports: ShowType = "Sports"
    public static let variety: ShowType = "Variety"
    public static let awardShow: ShowType = "Award Show"
    public static let panelShow: ShowType = "Panel Show"
}

// MARK: - Lenient decoding

extension KeyedDecodingContainer {
    /// A `yyyy-MM-dd` date, or `nil` for a missing key, `null`, `""` or a malformed value.
    func lenientDate(forKey key: Key) -> CalendarDate? {
        guard let string = (try? decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return CalendarDate(string)
    }

    /// A URL, or `nil` for a missing key, `null`, `""` or a value that is not a URL.
    func lenientURL(forKey key: Key) -> URL? {
        guard let string = (try? decodeIfPresent(String.self, forKey: key)) ?? nil, !string.isEmpty else { return nil }
        return URL(string: string)
    }
}
