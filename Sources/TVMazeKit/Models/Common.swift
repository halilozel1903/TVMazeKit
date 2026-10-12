import Foundation

/// The two sizes TVMaze serves for every poster, still and headshot (`image` in the JSON).
///
/// `medium` is about 210×295 for portraits and 250×140 for episode stills; `original` is the
/// uploaded file.
public struct ImageLinks: Codable, Hashable, Sendable {
    public var medium: URL?
    public var original: URL?

    public init(medium: URL?, original: URL?) {
        self.medium = medium
        self.original = original
    }

    /// The medium image, or the original when there is no medium one.
    public var preferred: URL? { medium ?? original }

    /// The original image, or the medium one when there is no original.
    public var largest: URL? { original ?? medium }
}

/// A rating out of 10 (`rating` in the JSON). `average` is `nil` until enough people voted.
public struct Rating: Codable, Hashable, Sendable {
    public var average: Double?

    public init(average: Double?) {
        self.average = average
    }
}

/// A country as TVMaze describes it, with the time zone its schedule times are in.
public struct Country: Codable, Hashable, Sendable {
    public var name: String
    /// ISO 3166-1 alpha-2 code, for example `US`.
    public var code: String
    /// An IANA time zone, for example `America/New_York`.
    public var timezone: String

    public init(name: String, code: String, timezone: String) {
        self.name = name
        self.code = code
        self.timezone = timezone
    }

    /// The country's time zone, when Foundation knows it.
    public var timeZone: TimeZone? { TimeZone(identifier: timezone) }
}

/// A TV network (`network`) or a streaming service (`webChannel`). Both have the same shape.
///
/// A web channel without a country, such as a global streaming service, has `country == nil`.
public struct Network: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var country: Country?
    public var officialSite: URL?

    public init(id: Int, name: String, country: Country? = nil, officialSite: URL? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.officialSite = officialSite
    }
}

/// A link in `_links`. Links to episodes and characters carry the name, so a list can show it
/// without another request.
public struct ResourceLink: Codable, Hashable, Sendable {
    public var href: URL
    public var name: String?

    public init(href: URL, name: String? = nil) {
        self.href = href
        self.name = name
    }

    /// The numeric id at the end of `href`, for example `1` for `https://api.tvmaze.com/shows/1`.
    public var id: Int? { Int(href.lastPathComponent) }
}

/// The `_links` object. Which links are present depends on the resource.
public struct Links: Codable, Hashable, Sendable {
    public var selfLink: ResourceLink?
    public var previousEpisode: ResourceLink?
    public var nextEpisode: ResourceLink?
    public var show: ResourceLink?
    public var character: ResourceLink?

    public init(
        selfLink: ResourceLink? = nil,
        previousEpisode: ResourceLink? = nil,
        nextEpisode: ResourceLink? = nil,
        show: ResourceLink? = nil,
        character: ResourceLink? = nil
    ) {
        self.selfLink = selfLink
        self.previousEpisode = previousEpisode
        self.nextEpisode = nextEpisode
        self.show = show
        self.character = character
    }

    enum CodingKeys: String, CodingKey {
        case selfLink = "self"
        case previousEpisode = "previousepisode"
        case nextEpisode = "nextepisode"
        case show
        case character
    }
}

/// An alternative title of a show, from `/shows/:id/akas`. `country` is `nil` for a title used
/// everywhere.
public struct AKA: Codable, Hashable, Sendable {
    public var name: String
    public var country: Country?

    public init(name: String, country: Country? = nil) {
        self.name = name
        self.country = country
    }
}

/// An image of a show from `/shows/:id/images`: a poster, a background, a banner or typography.
public struct ShowImage: Codable, Hashable, Sendable, Identifiable {
    public struct Kind: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
        public var rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }

        public static let poster: Kind = "poster"
        public static let background: Kind = "background"
        public static let banner: Kind = "banner"
        public static let typography: Kind = "typography"
    }

    public struct Resolution: Codable, Hashable, Sendable {
        public var url: URL
        public var width: Int?
        public var height: Int?

        public init(url: URL, width: Int? = nil, height: Int? = nil) {
            self.url = url
            self.width = width
            self.height = height
        }
    }

    public struct Resolutions: Codable, Hashable, Sendable {
        public var original: Resolution
        public var medium: Resolution?

        public init(original: Resolution, medium: Resolution? = nil) {
            self.original = original
            self.medium = medium
        }
    }

    public var id: Int
    public var type: Kind?
    /// Whether this is the show's main image of its kind.
    public var main: Bool
    public var resolutions: Resolutions

    public init(id: Int, type: Kind?, main: Bool, resolutions: Resolutions) {
        self.id = id
        self.type = type
        self.main = main
        self.resolutions = resolutions
    }
}

extension Array where Element == ShowImage {
    /// The main image of a kind, or the first one of that kind.
    public func first(ofKind kind: ShowImage.Kind) -> ShowImage? {
        let matching = filter { $0.type == kind }
        return matching.first(where: \.main) ?? matching.first
    }
}

/// One result of `/search/shows`, with TVMaze's relevance score.
public struct ShowSearchResult: Codable, Hashable, Sendable, Identifiable {
    public var score: Double
    public var show: Show

    public init(score: Double, show: Show) {
        self.score = score
        self.show = show
    }

    public var id: Int { show.id }
}

/// One result of `/search/people`, with TVMaze's relevance score.
public struct PersonSearchResult: Codable, Hashable, Sendable, Identifiable {
    public var score: Double
    public var person: Person

    public init(score: Double, person: Person) {
        self.score = score
        self.person = person
    }

    public var id: Int { person.id }
}

/// How far back `/updates/shows` looks.
public enum UpdatePeriod: String, Sendable, CaseIterable {
    case day
    case week
    case month
}
