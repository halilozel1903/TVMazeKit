import Foundation

/// An episode, from `/shows/:id/episodes`, `/episodes/:id`, a season or the schedule.
///
/// Schedule results carry the show the episode belongs to: `/schedule` puts it in `show`,
/// `/schedule/web` and `embed=show` in `_embedded.show`. Both end up in ``show``.
public struct Episode: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var url: URL?
    public var name: String
    public var season: Int
    /// The episode number in its season, `nil` for specials.
    public var number: Int?
    public var type: EpisodeType?
    /// The day it airs in the network's country, `nil` when not announced yet.
    public var airdate: CalendarDate?
    /// `HH:mm` in the network's time zone, or an empty string.
    public var airtime: String
    /// The exact moment it airs.
    public var airstamp: Date?
    public var runtime: Int?
    public var rating: Rating?
    public var image: ImageLinks?
    /// The summary as HTML. Use ``plainSummary`` to show it.
    public var summary: String?
    public var links: Links?

    /// Stored in a box: a show embeds episodes and an episode embeds its show, and a value type
    /// can't contain itself.
    private var showBox: ShowBox?

    /// The show, when the response included it (schedule results, `embed=show`).
    public var show: Show? {
        get { showBox?.value }
        set { showBox = newValue.map(ShowBox.init) }
    }

    public init(
        id: Int,
        name: String,
        season: Int,
        number: Int?,
        url: URL? = nil,
        type: EpisodeType? = .regular,
        airdate: CalendarDate? = nil,
        airtime: String = "",
        airstamp: Date? = nil,
        runtime: Int? = nil,
        rating: Rating? = nil,
        image: ImageLinks? = nil,
        summary: String? = nil,
        links: Links? = nil,
        show: Show? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.season = season
        self.number = number
        self.type = type
        self.airdate = airdate
        self.airtime = airtime
        self.airstamp = airstamp
        self.runtime = runtime
        self.rating = rating
        self.image = image
        self.summary = summary
        self.links = links
        self.showBox = show.map(ShowBox.init)
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, season, number, type, airdate, airtime, airstamp, runtime, rating, image, summary
        case links = "_links"
        case embedded = "_embedded"
        case show
    }

    enum EmbeddedKeys: String, CodingKey {
        case show
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        url = c.lenientURL(forKey: .url)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        season = try c.decodeIfPresent(Int.self, forKey: .season) ?? 0
        number = try c.decodeIfPresent(Int.self, forKey: .number)
        type = try c.decodeIfPresent(EpisodeType.self, forKey: .type)
        airdate = c.lenientDate(forKey: .airdate)
        airtime = (try? c.decodeIfPresent(String.self, forKey: .airtime)) ?? ""
        if let stamp = (try? c.decodeIfPresent(String.self, forKey: .airstamp)) ?? nil {
            airstamp = TVMazeDateParsing.date(fromISO8601: stamp)
        } else {
            airstamp = nil
        }
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime)
        rating = try c.decodeIfPresent(Rating.self, forKey: .rating)
        image = try c.decodeIfPresent(ImageLinks.self, forKey: .image)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        links = try c.decodeIfPresent(Links.self, forKey: .links)

        var show = try c.decodeIfPresent(Show.self, forKey: .show)
        if show == nil, c.contains(.embedded) {
            let embedded = try c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            show = try embedded.decodeIfPresent(Show.self, forKey: .show)
        }
        showBox = show.map(ShowBox.init)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(name, forKey: .name)
        try c.encode(season, forKey: .season)
        try c.encodeIfPresent(number, forKey: .number)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encode(airdate?.description ?? "", forKey: .airdate)
        try c.encode(airtime, forKey: .airtime)
        try c.encodeIfPresent(airstamp.map(TVMazeDateParsing.iso8601String(from:)), forKey: .airstamp)
        try c.encodeIfPresent(runtime, forKey: .runtime)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(links, forKey: .links)
        if let show {
            var embedded = c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            try embedded.encode(show, forKey: .show)
        }
    }
}

/// Holds an episode's show by reference so `Episode` and `Show` can contain each other.
private final class ShowBox: Hashable, Sendable {
    let value: Show

    init(_ value: Show) {
        self.value = value
    }

    static func == (lhs: ShowBox, rhs: ShowBox) -> Bool {
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

/// An episode's type. Known values are constants; anything else TVMaze adds still decodes.
public struct EpisodeType: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let regular: EpisodeType = "regular"
    public static let significantSpecial: EpisodeType = "significant_special"
    public static let insignificantSpecial: EpisodeType = "insignificant_special"
}

// MARK: - Conveniences

extension Episode {
    /// The summary without HTML, or `nil` when there is none.
    public var plainSummary: String? {
        guard let summary else { return nil }
        let text = HTMLText.plainText(from: summary)
        return text.isEmpty ? nil : text
    }

    /// Whether this is a special (it has no number, or its type says so).
    public var isSpecial: Bool {
        number == nil || type == .significantSpecial || type == .insignificantSpecial
    }

    /// "S02E05", or "S02 Special" for a special.
    public var code: String {
        let seasonPart = season < 10 ? "S0\(season)" : "S\(season)"
        guard let number else { return "\(seasonPart) Special" }
        return seasonPart + (number < 10 ? "E0\(number)" : "E\(number)")
    }

    /// "S2 · E5", or "S2 · Special", for compact labels.
    public var shortCode: String {
        guard let number else { return "S\(season) · Special" }
        return "S\(season) · E\(number)"
    }

    /// The airtime, or `nil` when it has none.
    public var airTime: AirTime? { AirTime(airtime) }

    /// Whether the episode has aired at `date` (by its airstamp, else its airdate).
    public func hasAired(at date: Date = Date()) -> Bool {
        if let airstamp { return airstamp <= date }
        guard let airdate, let day = airdate.date(in: TimeZone(identifier: "UTC") ?? .current) else { return false }
        return day <= date
    }
}

extension Array where Element == Episode {
    /// The episodes of one season, in order, specials after the numbered episodes.
    public func inSeason(_ season: Int) -> [Episode] {
        filter { $0.season == season }.sorted { lhs, rhs in
            switch (lhs.number, rhs.number) {
            case let (l?, r?): return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.id < rhs.id
            }
        }
    }

    /// The season numbers that have episodes, ascending.
    public var seasonNumbers: [Int] {
        Array<Int>(Set(map(\.season))).sorted()
    }
}

/// Parses and writes TVMaze's ISO 8601 timestamps (`2026-10-09T01:00:00+00:00`).
enum TVMazeDateParsing {
    // ISO8601DateFormatter is thread-safe; it is created once because it is expensive.
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func date(fromISO8601 string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return formatter.date(from: string) ?? fractionalFormatter.date(from: string)
    }

    static func iso8601String(from date: Date) -> String {
        formatter.string(from: date)
    }
}
