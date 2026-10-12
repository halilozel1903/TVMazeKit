import SwiftUI
import TVMazeKit
import TVMazeUI

/// The look of "Tonight", the demo TV guide.
@MainActor
enum Theme {
    static let brand = "TONIGHT"
    static let background = Color(red: 0.035, green: 0.035, blue: 0.07)
    static let surface = Color(red: 0.08, green: 0.08, blue: 0.13)
    static let moon = Color(red: 1.0, green: 0.84, blue: 0.4)
    static let indigo = Color(red: 0.42, green: 0.36, blue: 1.0)

    /// "Thursday, October 8".
    static func longDay(_ date: CalendarDate) -> String {
        let utc = TimeZone(identifier: "UTC") ?? .current
        guard let day = date.date(in: utc) else { return date.description }
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        style.timeZone = utc
        return day.formatted(style)
    }

    /// "Thursdays at 9:00 PM on Northwind", or "Streaming on Lumen+".
    static func airing(_ show: Show) -> String? {
        let channel = show.channel?.name
        if show.isStreaming {
            return channel.map { "Streaming on " + $0 }
        }
        guard let schedule = show.schedule, let time = schedule.airTime else {
            return channel.map { "On " + $0 }
        }
        let days: String
        switch schedule.days.count {
        case 0: days = "Daily"
        case 1: days = schedule.days[0].rawValue + "s"
        case 5 where !schedule.days.contains(.saturday) && !schedule.days.contains(.sunday): days = "Weeknights"
        default: days = schedule.days.map { String($0.rawValue.prefix(3)) }.joined(separator: ", ")
        }
        let when = days + " at " + time.formatted()
        return channel.map { when + " on " + $0 } ?? when
    }

    /// "2025– · 52 min · Drama, Science-Fiction".
    static func showFacts(_ show: Show) -> String {
        var parts: [String] = []
        if let years = show.yearsText { parts.append(years) }
        if let runtime = show.runtime ?? show.averageRuntime { parts.append(TVMazeFormat.runtime(runtime)) }
        if !show.genres.isEmpty { parts.append(show.genres.prefix(3).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

/// The brand mark: a crescent moon and the name.
struct BrandMark: View {
    var size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.4) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(Theme.moon)
            Text(Theme.brand)
                .tracking(size * 0.25)
                .foregroundStyle(Color.white)
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tonight")
    }
}
