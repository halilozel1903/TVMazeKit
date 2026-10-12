import Foundation

/// A person: an actor, a host or someone on the crew.
public struct Person: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var url: URL?
    public var name: String
    public var country: Country?
    public var birthday: CalendarDate?
    public var deathday: CalendarDate?
    /// `"Female"`, `"Male"` or another value, when known.
    public var gender: String?
    public var image: ImageLinks?
    public var updated: Int?
    public var links: Links?

    public init(
        id: Int,
        name: String,
        url: URL? = nil,
        country: Country? = nil,
        birthday: CalendarDate? = nil,
        deathday: CalendarDate? = nil,
        gender: String? = nil,
        image: ImageLinks? = nil,
        updated: Int? = nil,
        links: Links? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.country = country
        self.birthday = birthday
        self.deathday = deathday
        self.gender = gender
        self.image = image
        self.updated = updated
        self.links = links
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, country, birthday, deathday, gender, image, updated
        case links = "_links"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        url = c.lenientURL(forKey: .url)
        name = try c.decode(String.self, forKey: .name)
        country = try c.decodeIfPresent(Country.self, forKey: .country)
        birthday = c.lenientDate(forKey: .birthday)
        deathday = c.lenientDate(forKey: .deathday)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        image = try c.decodeIfPresent(ImageLinks.self, forKey: .image)
        updated = try c.decodeIfPresent(Int.self, forKey: .updated)
        links = try c.decodeIfPresent(Links.self, forKey: .links)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(birthday, forKey: .birthday)
        try c.encodeIfPresent(deathday, forKey: .deathday)
        try c.encodeIfPresent(gender, forKey: .gender)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(updated, forKey: .updated)
        try c.encodeIfPresent(links, forKey: .links)
    }

    /// The initials of the name, for a placeholder avatar ("Ingrid Solberg" → "IS").
    public var initials: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return String(letters).uppercased()
    }
}

/// A character in a show. (Named `ShowCharacter` so it doesn't shadow Swift's `Character`.)
public struct ShowCharacter: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var url: URL?
    public var name: String
    public var image: ImageLinks?
    public var links: Links?

    public init(id: Int, name: String, url: URL? = nil, image: ImageLinks? = nil, links: Links? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.image = image
        self.links = links
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, image
        case links = "_links"
    }
}

/// A role in a show's cast: who plays whom, from `/shows/:id/cast` or `embed=cast`.
public struct CastCredit: Codable, Hashable, Sendable, Identifiable {
    public var person: Person
    public var character: ShowCharacter
    /// The person appears as themselves (a host or a guest).
    public var isSelf: Bool
    /// A voice role.
    public var isVoice: Bool

    public init(person: Person, character: ShowCharacter, isSelf: Bool = false, isVoice: Bool = false) {
        self.person = person
        self.character = character
        self.isSelf = isSelf
        self.isVoice = isVoice
    }

    /// A person can play more than one character, so the id combines both.
    public var id: String { "\(person.id)-\(character.id)" }

    enum CodingKeys: String, CodingKey {
        case person, character
        case isSelf = "self"
        case isVoice = "voice"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        person = try c.decode(Person.self, forKey: .person)
        character = try c.decode(ShowCharacter.self, forKey: .character)
        isSelf = try c.decodeIfPresent(Bool.self, forKey: .isSelf) ?? false
        isVoice = try c.decodeIfPresent(Bool.self, forKey: .isVoice) ?? false
    }
}

/// A crew member of a show and their job, from `/shows/:id/crew`.
public struct CrewCredit: Codable, Hashable, Sendable, Identifiable {
    /// The job, for example `"Creator"` or `"Executive Producer"`.
    public var type: String
    public var person: Person

    public init(type: String, person: Person) {
        self.type = type
        self.person = person
    }

    public var id: String { "\(person.id)-\(type)" }
}

/// A role of a person, from `/people/:id/castcredits`. With `embed=show` it carries the show.
public struct PersonCastCredit: Codable, Hashable, Sendable {
    public var isSelf: Bool
    public var isVoice: Bool
    /// Links to the show and the character, with their names.
    public var links: Links?
    public var show: Show?

    public init(isSelf: Bool = false, isVoice: Bool = false, links: Links? = nil, show: Show? = nil) {
        self.isSelf = isSelf
        self.isVoice = isVoice
        self.links = links
        self.show = show
    }

    /// The character's name, from the link.
    public var characterName: String? { links?.character?.name }

    /// The show's name: the embedded show's, else the link's.
    public var showName: String? { show?.name ?? links?.show?.name }

    enum CodingKeys: String, CodingKey {
        case isSelf = "self"
        case isVoice = "voice"
        case links = "_links"
        case embedded = "_embedded"
    }

    enum EmbeddedKeys: String, CodingKey {
        case show
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isSelf = try c.decodeIfPresent(Bool.self, forKey: .isSelf) ?? false
        isVoice = try c.decodeIfPresent(Bool.self, forKey: .isVoice) ?? false
        links = try c.decodeIfPresent(Links.self, forKey: .links)
        if c.contains(.embedded) {
            let embedded = try c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            show = try embedded.decodeIfPresent(Show.self, forKey: .show)
        } else {
            show = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isSelf, forKey: .isSelf)
        try c.encode(isVoice, forKey: .isVoice)
        try c.encodeIfPresent(links, forKey: .links)
        if let show {
            var embedded = c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            try embedded.encode(show, forKey: .show)
        }
    }
}

/// A job of a person on a show's crew, from `/people/:id/crewcredits`.
public struct PersonCrewCredit: Codable, Hashable, Sendable {
    public var type: String
    public var links: Links?
    public var show: Show?

    public init(type: String, links: Links? = nil, show: Show? = nil) {
        self.type = type
        self.links = links
        self.show = show
    }

    /// The show's name: the embedded show's, else the link's.
    public var showName: String? { show?.name ?? links?.show?.name }

    enum CodingKeys: String, CodingKey {
        case type
        case links = "_links"
        case embedded = "_embedded"
    }

    enum EmbeddedKeys: String, CodingKey {
        case show
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        links = try c.decodeIfPresent(Links.self, forKey: .links)
        if c.contains(.embedded) {
            let embedded = try c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            show = try embedded.decodeIfPresent(Show.self, forKey: .show)
        } else {
            show = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(links, forKey: .links)
        if let show {
            var embedded = c.nestedContainer(keyedBy: EmbeddedKeys.self, forKey: .embedded)
            try embedded.encode(show, forKey: .show)
        }
    }
}
