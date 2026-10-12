import SwiftUI
import TVMazeKit

/// Text formatting shared by the views.
public enum TVMazeFormat {
    /// "Thu, Oct 8" in the current locale. The day is not shifted between time zones.
    public static func airdate(_ date: CalendarDate, locale: Locale = .current) -> String {
        let utc = TimeZone(identifier: "UTC") ?? .current
        guard let day = date.date(in: utc) else { return date.description }
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = utc
        style.locale = locale
        return day.formatted(style)
    }

    /// "52 min", or "1 h 5 min".
    public static func runtime(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }

    /// "8.6".
    public static func rating(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// The show's days, network-local time and channel: "Sun 9:00 PM · HBO", or
    /// "Mon–Fri 11:35 PM · KBX".
    public static func airing(_ show: Show, locale: Locale = .current) -> String? {
        var parts: [String] = []
        if let schedule = show.schedule {
            let days = schedule.days.map { String($0.rawValue.prefix(3)) }
            var when = days.count > 2 ? "\(days.first ?? "")–\(days.last ?? "")" : days.joined(separator: ", ")
            if let time = schedule.airTime {
                when += when.isEmpty ? time.formatted(locale: locale) : " " + time.formatted(locale: locale)
            }
            if !when.isEmpty { parts.append(when) }
        }
        if let channel = show.channel?.name {
            parts.append(channel)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "2011–2019 · HBO · Drama".
    public static func showLine(_ show: Show) -> String {
        var parts: [String] = []
        if let years = show.yearsText { parts.append(years) }
        if let channel = show.channel?.name { parts.append(channel) }
        if let genre = show.genres.first { parts.append(genre) }
        return parts.joined(separator: " · ")
    }
}

/// A star and the rating, on a dark capsule. Draws nothing without a rating.
public struct RatingBadge: View {
    private let rating: Double?

    public init(_ rating: Double?) {
        self.rating = rating
    }

    public var body: some View {
        if let rating {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.yellow)
                Text(TVMazeFormat.rating(rating))
                    .monospacedDigit()
            }
            .font(Metrics.badgeFont)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Metrics.badgePadding)
            .padding(.vertical, Metrics.badgePadding * 0.5)
            .background(Capsule().fill(Color.black.opacity(0.62)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rated \(TVMazeFormat.rating(rating)) out of 10")
        }
    }
}

/// "Data provided by TVmaze.com", as TVMaze's CC BY-SA license asks. A link where links open.
public struct TVMazeAttributionView: View {
    public init() {}

    public var body: some View {
        #if os(tvOS)
        label
        #else
        Link(destination: TVMazeAttribution.url) {
            label
        }
        #endif
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text(TVMazeAttribution.text)
        }
        .font(Metrics.captionFont)
        .foregroundStyle(.secondary)
    }
}

/// A button style for cards: on Apple TV the focused card grows and lifts on a shadow; elsewhere
/// it dims a little while pressed.
///
/// On tvOS a custom button style replaces the system focus effect, so this style draws its own.
public struct TVMazeCardButtonStyle: ButtonStyle {
    private let focusedScale: CGFloat

    public init(focusedScale: CGFloat = 1.08) {
        self.focusedScale = focusedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        CardButtonBody(configuration: configuration, focusedScale: focusedScale)
    }
}

private struct CardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let focusedScale: CGFloat

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .shadow(color: Color.black.opacity(isFocused ? 0.55 : 0), radius: 22, x: 0, y: 16)
            .zIndex(isFocused ? 1 : 0)
            .animation(reduceMotion ? nil : Animation.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var scale: CGFloat {
        #if os(tvOS)
        let base = isFocused ? focusedScale : 1
        #else
        let base: CGFloat = 1
        #endif
        return configuration.isPressed ? base * 0.97 : base
    }
}

/// Sizes that differ between the ten-foot Apple TV screen and a phone.
@MainActor
enum Metrics {
    #if os(tvOS)
    static let posterWidth: CGFloat = 220
    static let rowPosterWidth: CGFloat = 120
    static let cornerRadius: CGFloat = 14
    static let stillWidth: CGFloat = 400
    static let listStillWidth: CGFloat = 240
    static let headshot: CGFloat = 140
    static let castItemWidth: CGFloat = 180
    static let badgePadding: CGFloat = 12
    static let badgeFont: Font = .system(size: 22, weight: .bold)
    static let titleFont: Font = .system(size: 26, weight: .semibold)
    static let subtitleFont: Font = .system(size: 21, weight: .medium)
    static let bodyFont: Font = .system(size: 22)
    static let captionFont: Font = .system(size: 20, weight: .medium)
    static let spacing: CGFloat = 40
    #else
    static let posterWidth: CGFloat = 132
    static let rowPosterWidth: CGFloat = 70
    static let cornerRadius: CGFloat = 10
    static let stillWidth: CGFloat = 260
    static let listStillWidth: CGFloat = 124
    static let headshot: CGFloat = 76
    static let castItemWidth: CGFloat = 92
    static let badgePadding: CGFloat = 7
    static let badgeFont: Font = .caption.weight(.bold)
    static let titleFont: Font = .headline
    static let subtitleFont: Font = .subheadline
    static let bodyFont: Font = .subheadline
    static let captionFont: Font = .caption
    static let spacing: CGFloat = 14
    #endif

    /// TVMaze posters are 210×295.
    static let posterAspectRatio: CGFloat = 210.0 / 295.0
}
