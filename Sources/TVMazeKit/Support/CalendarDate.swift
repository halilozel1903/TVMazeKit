import Foundation

/// A day without a time or a time zone, like TVMaze's `airdate`, `premiered` and `birthday`
/// (`"2026-10-08"`).
///
/// TVMaze dates are local to the network's country, so they are kept as plain year, month and day
/// instead of a `Date` at midnight in some time zone.
public struct CalendarDate: Hashable, Comparable, Sendable, Codable, LosslessStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd`. Returns `nil` for an empty string or anything else.
    public init?(_ description: String) {
        let parts = description.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Today in `timeZone`. Pass a country's time zone to ask for that country's schedule.
    public static func today(in timeZone: TimeZone = .current) -> CalendarDate {
        CalendarDate(Date(), in: timeZone)
    }

    /// `yyyy-MM-dd`, the format the API expects.
    public var description: String {
        let y = String(year)
        let m = month < 10 ? "0\(month)" : String(month)
        let d = day < 10 ? "0\(day)" : String(day)
        return "\(String(repeating: "0", count: max(0, 4 - y.count)))\(y)-\(m)-\(d)"
    }

    /// Midnight at the start of the day in `timeZone`.
    public func date(in timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The day `days` later (or earlier, for a negative number).
    public func adding(days: Int) -> CalendarDate {
        let utc = TimeZone(identifier: "UTC") ?? .current
        guard let start = date(in: utc) else { return self }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        guard let moved = calendar.date(byAdding: .day, value: days, to: start) else { return self }
        return CalendarDate(moved, in: utc)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = CalendarDate(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \"\(string)\"")
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// A network's local time of day, like `schedule.time` and `airtime` (`"21:00"`).
public struct AirTime: Hashable, Comparable, Sendable, LosslessStringConvertible {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:mm`. Returns `nil` for an empty string, which TVMaze uses for "no fixed time".
    public init?(_ description: String) {
        let parts = description.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// `HH:mm`, as in the API.
    public var description: String {
        (hour < 10 ? "0\(hour)" : "\(hour)") + ":" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }

    /// Minutes since midnight.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    /// The time in the locale's style, for example "9:00 PM" in the US or "21:00" in Germany.
    /// The time is not converted between time zones: it is the network's local time.
    public func formatted(locale: Locale = .current) -> String {
        let utc = TimeZone(identifier: "UTC") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        guard let date = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute)) else {
            return description
        }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = utc
        style.locale = locale
        return date.formatted(style)
    }

    public static func < (lhs: AirTime, rhs: AirTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
