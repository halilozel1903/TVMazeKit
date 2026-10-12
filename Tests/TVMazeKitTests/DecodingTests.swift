import Foundation
import Testing
@testable import TVMazeKit

@Suite("Decoding TVMaze JSON")
struct DecodingTests {
    @Test func showWithEveryEmbed() throws {
        let show = try Fixture.decode(Show.self, from: "show-embedded")

        #expect(show.id == 1001)
        #expect(show.name == "The Long Static")
        #expect(show.type == .scripted)
        #expect(show.status == .running)
        #expect(show.language == "English")
        let genres = ["Drama", "Science-Fiction", "Mystery"]
        #expect(show.genres == genres)
        #expect(show.runtime == 52)
        #expect(show.premiered == CalendarDate(year: 2025, month: 1, day: 16))
        #expect(show.ended == nil)
        #expect(show.rating?.average == 8.6)
        #expect(show.weight == 97)
        let thursday: [Weekday] = [.thursday]
        #expect(show.schedule?.days == thursday)
        #expect(show.schedule?.airTime == AirTime(hour: 21, minute: 0))
        #expect(show.network?.name == "Northwind")
        #expect(show.network?.country?.code == "US")
        #expect(show.network?.country?.timeZone?.identifier == "America/New_York")
        #expect(show.webChannel == nil)
        #expect(show.isStreaming == false)
        #expect(show.externals?.imdb == "tt9900101")
        #expect(show.externals?.thetvdb == 498101)
        #expect(show.externals?.tvrage == nil)
        #expect(show.image?.medium?.absoluteString.contains("medium_portrait") == true)
        #expect(show.officialSite?.host == "the-long-static.example")
        #expect(show.links?.selfLink?.href.absoluteString == "https://api.tvmaze.com/shows/1001")
        #expect(show.links?.nextEpisode?.id == 100113)
        #expect(show.links?.nextEpisode?.name == "Interference")
        #expect(show.yearsText == "2025–")

        let embedded = try #require(show.embedded)
        #expect(embedded.cast?.count == 6)
        #expect(embedded.crew?.count == 4)
        #expect(embedded.seasons?.count == 2)
        #expect(embedded.episodes?.count == 18)
        #expect(embedded.images?.count == 2)
        #expect(embedded.akas?.count == 4)
        #expect(embedded.nextEpisode?.name == "Interference")
        #expect(embedded.previousEpisode?.name == "The Relay")
        #expect(show.backgroundImageURL != nil)
        #expect(show.cast.first?.character.name == "Maren Holt")
        #expect(embedded.akas?.last?.country == nil)
        #expect(embedded.akas?.first?.country?.code == "FR")
    }

    @Test func showWithoutEmbedsHasEmptyConveniences() throws {
        let show = try Fixture.decode(Show.self, from: "show")
        #expect(show.embedded == nil)
        #expect(show.cast.isEmpty)
        #expect(show.episodes.isEmpty)
        #expect(show.seasons.isEmpty)
        #expect(show.backgroundImageURL == nil)
    }

    @Test func summaryIsPlainText() throws {
        let show = try Fixture.decode(Show.self, from: "show")
        let expected = "The Long Static follows the night shift at Halvard Station, a polar research outpost where radio operator Maren Holt hears a voice on a frequency nobody has used in forty years. As a storm cuts the station off from the mainland, the crew has to decide whether the signal is a warning — or an invitation."
        #expect(show.plainSummary == expected)
    }

    @Test func streamingShow() throws {
        let show = try Fixture.decode(Show.self, from: "show-web")
        #expect(show.network == nil)
        #expect(show.webChannel?.name == "Lumen+")
        #expect(show.webChannel?.country == nil)
        #expect(show.isStreaming)
        #expect(show.channel?.name == "Lumen+")
        #expect(show.schedule?.airTime == nil)
        let expected = """
        A help desk of five misfits keeps a struggling games studio online, one catastrophic patch at a time.

        Ctrl+Alt+Delight is Lumen+'s first original comedy.
        """
        #expect(show.plainSummary == expected)
    }

    @Test func episodesWithSpecialsAndUnannouncedDates() throws {
        let episodes = try Fixture.decode([Episode].self, from: "episodes")
        #expect(episodes.count == 19)

        let tonight = try #require(episodes.first(where: { $0.id == 100113 }))
        #expect(tonight.code == "S02E05")
        #expect(tonight.shortCode == "S2 · E5")
        #expect(tonight.airdate == CalendarDate(year: 2026, month: 10, day: 8))
        #expect(tonight.airTime == AirTime(hour: 21, minute: 0))
        #expect(tonight.airstamp == Date(timeIntervalSince1970: 1_791_507_600))
        #expect(tonight.rating?.average == nil)
        #expect(tonight.links?.show?.name == "The Long Static")
        #expect(tonight.show == nil)

        let special = try #require(episodes.first(where: { $0.number == nil }))
        #expect(special.isSpecial)
        #expect(special.type == .significantSpecial)
        #expect(special.code == "S02 Special")

        let unannounced = try #require(episodes.first(where: { $0.id == 100118 }))
        #expect(unannounced.airdate == nil)
        #expect(unannounced.airtime.isEmpty)
        #expect(unannounced.airstamp == nil)
        #expect(unannounced.summary == nil)
        #expect(unannounced.hasAired(at: Date(timeIntervalSince1970: 2_000_000_000)) == false)
    }

    @Test func seasonsAndSeasonEpisodes() throws {
        let seasons = try Fixture.decode([Season].self, from: "seasons")
        #expect(seasons.count == 2)
        #expect(seasons[0].title == "Season 1")
        #expect(seasons[0].episodeOrder == 8)
        #expect(seasons[0].premiereDate == CalendarDate(year: 2025, month: 1, day: 16))
        #expect(seasons[1].endDate == nil)
        #expect(seasons[1].network?.name == "Northwind")

        let episodes = try Fixture.decode([Episode].self, from: "season-episodes")
        #expect(episodes.count == 8)
        #expect(episodes.allSatisfy { $0.season == 1 })
    }

    @Test func scheduleCarriesTheShowInline() throws {
        let episodes = try Fixture.decode([Episode].self, from: "schedule")
        #expect(episodes.count == 13)
        #expect(episodes.allSatisfy { $0.show != nil })
        #expect(episodes.first?.show?.name == "Orbit Academy")
        #expect(episodes.uniqueShows.count == 13)
    }

    @Test func webScheduleCarriesTheShowEmbedded() throws {
        let episodes = try Fixture.decode([Episode].self, from: "schedule-web")
        #expect(episodes.count == 15)
        #expect(episodes.allSatisfy { $0.show?.isStreaming == true })
        #expect(episodes.uniqueShows.count == 3)
    }

    @Test func episodeWithEmbeddedShow() throws {
        let episode = try Fixture.decode(Episode.self, from: "episode-embed-show")
        #expect(episode.name == "Interference")
        #expect(episode.show?.name == "The Long Static")
    }

    @Test func castAndCrew() throws {
        let cast = try Fixture.decode([CastCredit].self, from: "cast")
        let lead = try #require(cast.first)
        #expect(lead.person.name == "Ingrid Solberg")
        #expect(lead.person.initials == "IS")
        #expect(lead.person.birthday == CalendarDate(year: 1988, month: 3, day: 14))
        #expect(lead.person.deathday == nil)
        #expect(lead.person.gender == "Female")
        #expect(lead.person.country?.code == "NO")
        #expect(lead.character.name == "Maren Holt")
        #expect(lead.isSelf == false)
        #expect(lead.isVoice == false)
        #expect(lead.id == "2001-3001")

        let crew = try Fixture.decode([CrewCredit].self, from: "crew")
        #expect(crew.first?.type == "Creator")
        #expect(crew.first?.person.name == "Nadia Ferreira")
    }

    @Test func personCredits() throws {
        let credits = try Fixture.decode([PersonCastCredit].self, from: "person-castcredits")
        #expect(credits.count == 2)
        #expect(credits[0].characterName == "Maren Holt")
        #expect(credits[0].show?.name == "The Long Static")
        #expect(credits[1].isVoice)
        #expect(credits[1].characterName == "Commander Lyra")
        #expect(credits[1].showName == "Orbit Academy")

        let crew = try Fixture.decode([PersonCrewCredit].self, from: "person-crewcredits")
        let jobs: [String] = ["Creator", "Executive Producer"]
        let crewJobs = crew.map(\.type)
        #expect(crewJobs == jobs)
        #expect(crew.first?.showName == "The Long Static")
    }

    @Test func searchResults() throws {
        let shows = try Fixture.decode([ShowSearchResult].self, from: "search-shows")
        #expect(shows.count == 5)
        #expect(shows.first?.show.name == "Nightjar")
        #expect(shows.first?.score == 0.9124)

        let people = try Fixture.decode([PersonSearchResult].self, from: "people-search")
        #expect(people.first?.person.name == "Ingrid Solberg")
    }

    @Test func images() throws {
        let images = try Fixture.decode([ShowImage].self, from: "images")
        let poster = try #require(images.first(ofKind: .poster))
        #expect(poster.main)
        #expect(poster.resolutions.medium?.width == 210)
        let background = try #require(images.first(ofKind: .background))
        #expect(background.resolutions.original.width == 1920)
        #expect(background.resolutions.medium == nil)
        #expect(images.first(ofKind: .banner) == nil)
    }

    @Test func unknownValuesStillDecode() throws {
        let json = """
        {
          "id": 7,
          "name": "Panel Night",
          "type": "Quiz Format",
          "status": "On Hiatus",
          "genres": [],
          "premiered": "",
          "officialSite": "",
          "schedule": { "time": "", "days": ["Thursday", "Someday"] },
          "rating": { "average": null },
          "image": null,
          "summary": null
        }
        """
        let show = try JSONDecoder().decode(Show.self, from: Data(json.utf8))
        #expect(show.type == ShowType(rawValue: "Quiz Format"))
        #expect(show.status?.rawValue == "On Hiatus")
        #expect(show.premiered == nil)
        #expect(show.officialSite == nil)
        let thursday: [Weekday] = [.thursday]
        #expect(show.schedule?.days == thursday)
        #expect(show.rating?.average == nil)
        #expect(show.image == nil)
        #expect(show.plainSummary == nil)
    }

    @Test func encodingRoundTrips() throws {
        let show = try Fixture.decode(Show.self, from: "show-embedded")
        let data = try JSONEncoder().encode(show)
        let decoded = try JSONDecoder().decode(Show.self, from: data)
        #expect(decoded == show)

        let schedule = try Fixture.decode([Episode].self, from: "schedule-web")
        let again = try JSONDecoder().decode([Episode].self, from: JSONEncoder().encode(schedule))
        #expect(again == schedule)
        #expect(again.first?.show?.name == schedule.first?.show?.name)
    }
}
