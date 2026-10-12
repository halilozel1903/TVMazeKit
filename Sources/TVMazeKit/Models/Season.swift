import Foundation

/// A season of a show, from `/shows/:id/seasons` or `embed=seasons`.
public struct Season: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var url: URL?
    public var number: Int
    /// Usually empty; some shows name their seasons.
    public var name: String
    /// How many episodes were ordered, when known.
    public var episodeOrder: Int?
    public var premiereDate: CalendarDate?
    public var endDate: CalendarDate?
    public var network: Network?
    public var webChannel: Network?
    public var image: ImageLinks?
    public var summary: String?
    public var links: Links?

    public init(
        id: Int,
        number: Int,
        name: String = "",
        url: URL? = nil,
        episodeOrder: Int? = nil,
        premiereDate: CalendarDate? = nil,
        endDate: CalendarDate? = nil,
        network: Network? = nil,
        webChannel: Network? = nil,
        image: ImageLinks? = nil,
        summary: String? = nil,
        links: Links? = nil
    ) {
        self.id = id
        self.url = url
        self.number = number
        self.name = name
        self.episodeOrder = episodeOrder
        self.premiereDate = premiereDate
        self.endDate = endDate
        self.network = network
        self.webChannel = webChannel
        self.image = image
        self.summary = summary
        self.links = links
    }

    enum CodingKeys: String, CodingKey {
        case id, url, number, name, episodeOrder, premiereDate, endDate, network, webChannel, image, summary
        case links = "_links"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        url = c.lenientURL(forKey: .url)
        number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        episodeOrder = try c.decodeIfPresent(Int.self, forKey: .episodeOrder)
        premiereDate = c.lenientDate(forKey: .premiereDate)
        endDate = c.lenientDate(forKey: .endDate)
        network = try c.decodeIfPresent(Network.self, forKey: .network)
        webChannel = try c.decodeIfPresent(Network.self, forKey: .webChannel)
        image = try c.decodeIfPresent(ImageLinks.self, forKey: .image)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        links = try c.decodeIfPresent(Links.self, forKey: .links)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(number, forKey: .number)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(episodeOrder, forKey: .episodeOrder)
        try c.encodeIfPresent(premiereDate, forKey: .premiereDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(network, forKey: .network)
        try c.encodeIfPresent(webChannel, forKey: .webChannel)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(links, forKey: .links)
    }

    /// "Season 2", or the season's own name when it has one.
    public var title: String {
        name.isEmpty ? "Season \(number)" : name
    }

    /// The summary without HTML, or `nil` when there is none.
    public var plainSummary: String? {
        guard let summary else { return nil }
        let text = HTMLText.plainText(from: summary)
        return text.isEmpty ? nil : text
    }
}
