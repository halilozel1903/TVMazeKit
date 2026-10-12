import Foundation
import Testing
@testable import TVMazeKit

@Suite("HTML summaries")
struct HTMLTextTests {
    @Test func inlineTagsAndEntities() {
        let text = HTMLText.plainText(from: "<p><b>Bold</b> &amp; <i>italic</i></p>")
        #expect(text == "Bold & italic")
    }

    @Test func paragraphsBecomeBlankLines() {
        let text = HTMLText.plainText(from: "<p>One.</p><p>Two.</p>")
        let expected = """
        One.

        Two.
        """
        #expect(text == expected)
    }

    @Test func lineBreaks() {
        let text = HTMLText.plainText(from: "Line<br />Next<br>Last")
        let expected = """
        Line
        Next
        Last
        """
        #expect(text == expected)
    }

    @Test func numericReferences() {
        let text = "It&#39;s here &#x2014; finally&#8230;".strippingHTML
        #expect(text == "It's here — finally…")
    }

    @Test func unknownReferencesAndStrayAmpersandsStay() {
        let text = HTMLText.plainText(from: "AT&T &foo; and R&D")
        #expect(text == "AT&T &foo; and R&D")
    }

    @Test func whitespaceIsCollapsed() {
        let text = HTMLText.plainText(from: "  <p>  spaced    out&nbsp;&nbsp;text </p>  ")
        #expect(text == "spaced out text")
    }

    @Test func aLoneAngleBracketIsText() {
        let text = HTMLText.plainText(from: "3 < 4")
        #expect(text == "3 < 4")
    }

    @Test func emptyInput() {
        #expect(HTMLText.plainText(from: "").isEmpty)
        #expect(HTMLText.plainText(from: "<p></p>").isEmpty)
    }
}

@Suite("Dates and times")
struct DateTests {
    @Test func parsesCalendarDates() {
        let date = CalendarDate("2026-10-08")
        #expect(date == CalendarDate(year: 2026, month: 10, day: 8))
        #expect(date?.description == "2026-10-08")
        #expect(CalendarDate("") == nil)
        #expect(CalendarDate("2026-13-01") == nil)
        #expect(CalendarDate("08.10.2026") == nil)
        #expect(CalendarDate(year: 2026, month: 1, day: 5).description == "2026-01-05")
    }

    @Test func comparesAndAddsDays() {
        let first = CalendarDate(year: 2026, month: 9, day: 30)
        let next = first.adding(days: 1)
        #expect(next == CalendarDate(year: 2026, month: 10, day: 1))
        #expect(first < next)
        #expect(next.adding(days: -1) == first)
    }

    @Test func dayInATimeZone() throws {
        // 2026-10-09 01:00 UTC is still the 8th in New York.
        let moment = Date(timeIntervalSince1970: 1_791_507_600)
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(CalendarDate(moment, in: newYork) == CalendarDate(year: 2026, month: 10, day: 8))
        #expect(CalendarDate(moment, in: utc) == CalendarDate(year: 2026, month: 10, day: 9))
    }

    @Test func airTimes() {
        let time = AirTime("21:00")
        #expect(time == AirTime(hour: 21, minute: 0))
        #expect(time?.minutesSinceMidnight == 1_260)
        #expect(AirTime("") == nil)
        #expect(AirTime("25:00") == nil)
        #expect(AirTime(hour: 9, minute: 5).description == "09:05")
        #expect(AirTime(hour: 20, minute: 30) < AirTime(hour: 21, minute: 0))
        #expect(AirTime(hour: 21, minute: 0).formatted(locale: Locale(identifier: "de_DE")) == "21:00")
    }
}

@Suite("Schedule and episode helpers")
struct ScheduleTests {
    @Test func networkScheduleIsSlottedByTime() throws {
        let episodes = try Fixture.decode([Episode].self, from: "schedule")
        let slots = episodes.scheduleSlots()

        let times = slots.map { $0.time?.description ?? "" }
        let expectedTimes: [String] = ["17:00", "19:00", "20:00", "20:30", "21:00", "22:00", "23:35"]
        #expect(times == expectedTimes)

        let nine = try #require(slots.first(where: { $0.time == AirTime(hour: 21, minute: 0) }))
        let names = nine.entries.map(\.show.name)
        let expectedNames: [String] = ["The Long Static", "Glasshouse", "Second Chair"]
        #expect(names == expectedNames)
        #expect(nine.entries.first?.episode?.name == "Interference")
    }

    @Test func streamingReleasesAreMergedPerShow() throws {
        let episodes = try Fixture.decode([Episode].self, from: "schedule-web")
        let slots = episodes.scheduleSlots()

        #expect(slots.count == 1)
        let slot = try #require(slots.first)
        #expect(slot.time == nil)
        #expect(slot.episodeCount == 15)
        let counts = slot.entries.map(\.episodes.count)
        let expectedCounts: [Int] = [8, 6, 1]
        #expect(counts == expectedCounts)
        #expect(slot.entries.first?.show.name == "Ctrl+Alt+Delight")
        #expect(slot.entries.first?.episodes.first?.number == 1)
    }

    @Test func episodesWithoutAShowAreLeftOut() throws {
        let episodes = try Fixture.decode([Episode].self, from: "episodes")
        #expect(episodes.scheduleSlots().isEmpty)
    }

    @Test func seasonsOfAShow() throws {
        let episodes = try Fixture.decode([Episode].self, from: "episodes")
        let seasons = episodes.seasonNumbers
        let expectedSeasons: [Int] = [1, 2]
        #expect(seasons == expectedSeasons)

        let second = episodes.inSeason(2)
        #expect(second.count == 11)
        #expect(second.first?.number == 1)
        #expect(second.last?.isSpecial == true)
    }
}
