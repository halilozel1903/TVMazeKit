import Foundation
import Testing
@testable import TVMazeKit

@Suite("TVMazeClient requests")
struct ClientTests {
    @Test func searchShows() async throws {
        let stub = StubbedClient { _ in try .json("search-shows") }
        let results = try await stub.client.searchShows("night")

        #expect(results.count == 5)
        #expect(results.first?.show.name == "Nightjar")
        #expect(stub.lastPath == "/search/shows")
        #expect(stub.lastQueryValue("q") == "night")
    }

    @Test func plusSignsAreSentEncoded() async throws {
        let stub = StubbedClient { _ in try .json("search-shows") }
        _ = try await stub.client.searchShows("Ctrl+Alt+Delight")

        let url = try #require(stub.requests.last?.url)
        let query = url.query ?? ""
        #expect(query.contains("Ctrl%2BAlt%2BDelight"))
        #expect(stub.lastQueryValue("q") == "Ctrl+Alt+Delight")
    }

    @Test func headers() async throws {
        let stub = StubbedClient { _ in try .json("show") }
        _ = try await stub.client.show(id: 1001)

        let request = try #require(stub.requests.last)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let agent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        #expect(agent.hasPrefix("TVMazeKit"))
    }

    @Test func singleEmbed() async throws {
        let stub = StubbedClient { _ in try .json("show-embedded") }
        let show = try await stub.client.show(id: 1001, embedding: [.cast])

        #expect(show.name == "The Long Static")
        #expect(stub.lastPath == "/shows/1001")
        #expect(stub.lastQueryValue("embed") == "cast")
    }

    @Test func severalEmbedsInAStableOrder() async throws {
        let stub = StubbedClient { _ in try .json("show-embedded") }
        _ = try await stub.client.show(id: 1001, embedding: [.nextEpisode, .cast, .episodes])

        let names = stub.lastQuery.map(\.name)
        let values = stub.lastQuery.compactMap(\.value)
        let expectedNames: [String] = ["embed[]", "embed[]", "embed[]"]
        let expectedValues: [String] = ["episodes", "cast", "nextepisode"]
        #expect(names == expectedNames)
        #expect(values == expectedValues)
    }

    @Test func singleSearchReturnsNilWhenNothingMatches() async throws {
        let stub = StubbedClient { _ in .status(404) }
        let show = try await stub.client.singleSearchShow("zzzz")

        #expect(show == nil)
        #expect(stub.lastPath == "/singlesearch/shows")
    }

    @Test func singleSearchWithEpisodes() async throws {
        let stub = StubbedClient { _ in try .json("singlesearch") }
        let show = try await stub.client.singleSearchShow("the long static", embedding: [.episodes])

        #expect(show?.episodes.count == 18)
        #expect(stub.lastQueryValue("embed") == "episodes")
    }

    @Test func lookupByIMDbAndTheTVDB() async throws {
        let stub = StubbedClient { _ in try .json("show") }

        let byIMDb = try await stub.client.lookupShow(.imdb("tt9900101"))
        #expect(byIMDb?.id == 1001)
        #expect(stub.lastPath == "/lookup/shows")
        #expect(stub.lastQueryValue("imdb") == "tt9900101")

        _ = try await stub.client.lookupShow(.thetvdb(498101))
        #expect(stub.lastQueryValue("thetvdb") == "498101")
    }

    @Test func lookupOfAnUnknownShowIsNil() async throws {
        let stub = StubbedClient { _ in .status(404) }
        let show = try await stub.client.lookupShow(.tvrage(1))
        #expect(show == nil)
    }

    @Test func episodeByNumber() async throws {
        let stub = StubbedClient { request in
            let query = request.url?.query ?? ""
            return try query.contains("number=5") ? .json("episode") : .status(404)
        }

        let episode = try await stub.client.episode(showID: 1001, season: 2, number: 5)
        #expect(episode?.name == "Interference")
        #expect(stub.lastPath == "/shows/1001/episodebynumber")
        #expect(stub.lastQueryValue("season") == "2")

        let missing = try await stub.client.episode(showID: 1001, season: 2, number: 50)
        #expect(missing == nil)
    }

    @Test func episodesWithSpecials() async throws {
        let stub = StubbedClient { _ in try .json("episodes") }

        _ = try await stub.client.episodes(showID: 1001)
        #expect(stub.lastQuery.isEmpty)

        let episodes = try await stub.client.episodes(showID: 1001, includeSpecials: true)
        #expect(stub.lastQueryValue("specials") == "1")
        let hasSpecials = episodes.contains(where: \.isSpecial)
        #expect(hasSpecials)
    }

    @Test func episodesByDateIsEmptyWhenNothingAired() async throws {
        let stub = StubbedClient { _ in .status(404) }
        let episodes = try await stub.client.episodes(showID: 1001, airedOn: CalendarDate(year: 2026, month: 10, day: 7))

        #expect(episodes.isEmpty)
        #expect(stub.lastPath == "/shows/1001/episodesbydate")
        #expect(stub.lastQueryValue("date") == "2026-10-07")
    }

    @Test func showResources() async throws {
        let stub = StubbedClient { request in
            switch request.url?.path ?? "" {
            case "/shows/1001/seasons": return try .json("seasons")
            case "/seasons/60012/episodes": return try .json("season-episodes")
            case "/shows/1001/cast": return try .json("cast")
            case "/shows/1001/crew": return try .json("crew")
            case "/shows/1001/akas": return try .json("akas")
            case "/shows/1001/images": return try .json("images")
            case "/episodes/100113": return try .json("episode-embed-show")
            case "/episodes/100113/guestcast": return try .json("guestcast")
            default: return .status(404)
            }
        }
        let client = stub.client

        let seasons = try await client.seasons(showID: 1001)
        #expect(seasons.count == 2)
        let seasonEpisodes = try await client.seasonEpisodes(seasonID: 60012)
        #expect(seasonEpisodes.count == 8)
        let cast = try await client.cast(showID: 1001)
        #expect(cast.count == 6)
        let crew = try await client.crew(showID: 1001)
        #expect(crew.count == 4)
        let akas = try await client.akas(showID: 1001)
        #expect(akas.first?.name == "La Longue Statique")
        let images = try await client.images(showID: 1001)
        #expect(images.count == 2)
        let episode = try await client.episode(id: 100113, embeddingShow: true)
        #expect(episode.show?.id == 1001)
        #expect(stub.lastQueryValue("embed") == "show")
        let guests = try await client.guestCast(episodeID: 100113)
        #expect(guests.first?.character.name == "Captain Edvard Lund")
    }

    @Test func schedule() async throws {
        let stub = StubbedClient { _ in try .json("schedule") }
        let episodes = try await stub.client.schedule(country: "US", date: CalendarDate(year: 2026, month: 10, day: 8))

        #expect(episodes.count == 13)
        #expect(stub.lastPath == "/schedule")
        #expect(stub.lastQueryValue("country") == "US")
        #expect(stub.lastQueryValue("date") == "2026-10-08")
    }

    @Test func webScheduleForEveryCountry() async throws {
        let stub = StubbedClient { _ in try .json("schedule-web") }
        let episodes = try await stub.client.webSchedule(date: CalendarDate(year: 2026, month: 10, day: 8))

        #expect(episodes.count == 15)
        #expect(stub.lastPath == "/schedule/web")
        #expect(stub.lastQueryValue("country") == nil)

        _ = try await stub.client.webSchedule(country: "")
        #expect(stub.lastQueryValue("country") == "")
        #expect(stub.lastQueryValue("date") == nil)
    }

    @Test func peopleEndpoints() async throws {
        let stub = StubbedClient { request in
            switch request.url?.path ?? "" {
            case "/search/people": return try .json("people-search")
            case "/people/2001": return try .json("person")
            case "/people/2001/castcredits": return try .json("person-castcredits")
            case "/people/2004/crewcredits": return try .json("person-crewcredits")
            default: return .status(404)
            }
        }

        let found = try await stub.client.searchPeople("solberg")
        #expect(found.count == 2)
        let person = try await stub.client.person(id: 2001)
        #expect(person.name == "Ingrid Solberg")
        let credits = try await stub.client.castCredits(personID: 2001)
        #expect(credits.count == 2)
        #expect(stub.lastQueryValue("embed") == "show")
        let crew = try await stub.client.crewCredits(personID: 2004, embeddingShows: false)
        #expect(crew.count == 2)
        #expect(stub.lastQuery.isEmpty)
    }

    @Test func showIndexEndsWithAnEmptyPage() async throws {
        let stub = StubbedClient { request in
            let page = request.url?.query ?? ""
            return try page == "page=0" ? .json("shows-page") : .status(404)
        }

        let first = try await stub.client.shows(page: 0)
        #expect(first.count == 16)
        let past = try await stub.client.shows(page: 1)
        #expect(past.isEmpty)
    }

    @Test func updates() async throws {
        let stub = StubbedClient { _ in try .json("updates") }
        let updates = try await stub.client.showUpdates(since: .day)

        #expect(updates.count == 16)
        #expect(updates[1001] == Date(timeIntervalSince1970: 1_791_201_001))
        #expect(stub.lastPath == "/updates/shows")
        #expect(stub.lastQueryValue("since") == "day")
    }

    @Test func notFoundThrowsForResources() async throws {
        let stub = StubbedClient { _ in .status(404) }
        await #expect(throws: TVMazeError.self) {
            _ = try await stub.client.show(id: 999_999)
        }
    }

    @Test func serverErrorsThrow() async throws {
        let stub = StubbedClient { _ in .status(503) }
        do {
            _ = try await stub.client.show(id: 1001)
            Issue.record("Expected an error")
        } catch let error as TVMazeError {
            guard case let .http(statusCode, _) = error else {
                Issue.record("Unexpected error")
                return
            }
            #expect(statusCode == 503)
        }
    }

    @Test func malformedJSONIsADecodingError() async throws {
        let stub = StubbedClient { _ in StubResponse(status: 200, headers: [:], body: Data(#"{"id": "one"}"#.utf8)) }
        do {
            _ = try await stub.client.show(id: 1001)
            Issue.record("Expected an error")
        } catch let error as TVMazeError {
            guard case let .decoding(type, _) = error else {
                Issue.record("Unexpected error")
                return
            }
            #expect(type == "Show")
        }
    }
}
