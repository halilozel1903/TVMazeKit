import SwiftUI
import TVMazeKit

/// A day's schedule as a list with a section per start time.
///
/// Feed it what ``TVMazeClient/schedule(country:date:)`` or
/// ``TVMazeClient/webSchedule(date:country:)`` returns. Episodes of the same show in the same slot
/// (a season released at once) become one row. Style it with `.listStyle(_:)`.
///
/// ```swift
/// ScheduleList(episodes: tonight) { entry in
///     path.append(entry.show)
/// }
/// ```
public struct ScheduleList: View {
    private let slots: [ScheduleSlot]
    private let untimedTitle: String
    private let onSelect: ((ScheduleEntry) -> Void)?

    /// - Parameters:
    ///   - episodes: Schedule episodes, each with its show.
    ///   - untimedTitle: The header of episodes without a start time.
    ///   - onSelect: Called when a row is tapped; rows are not buttons without it.
    public init(
        episodes: [Episode],
        untimedTitle: String = "Available today",
        onSelect: ((ScheduleEntry) -> Void)? = nil
    ) {
        self.slots = episodes.scheduleSlots()
        self.untimedTitle = untimedTitle
        self.onSelect = onSelect
    }

    public var body: some View {
        List {
            ForEach(slots) { slot in
                Section {
                    ForEach(slot.entries) { entry in
                        row(entry)
                    }
                } header: {
                    Text(slot.time?.formatted() ?? untimedTitle)
                        .font(Metrics.subtitleFont.weight(.bold))
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: ScheduleEntry) -> some View {
        if let onSelect {
            Button {
                onSelect(entry)
            } label: {
                ScheduleRow(entry: entry)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            ScheduleRow(entry: entry)
        }
    }
}

/// One show in a ``ScheduleList``: its poster, name, the episode (or how many were released)
/// and the channel.
public struct ScheduleRow: View {
    private let entry: ScheduleEntry

    public init(entry: ScheduleEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: Metrics.spacing) {
            TVMazeImage(url: entry.show.image?.preferred, title: entry.show.name)
                .frame(width: Metrics.rowPosterWidth * 0.7, height: Metrics.rowPosterWidth * 0.7 / Metrics.posterAspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius * 0.5, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.show.name)
                    .font(Metrics.titleFont)
                    .lineLimit(1)
                Text(episodeLine)
                    .font(Metrics.subtitleFont)
                    .lineLimit(1)
                Text(channelLine)
                    .font(Metrics.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            RatingBadge(entry.show.rating?.average)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// "S1 · E1 · Winter Is Coming", or "Season 2 · 8 episodes".
    private var episodeLine: String {
        guard let first = entry.episodes.first else { return "" }
        if entry.episodes.count > 1 {
            return "Season \(first.season) · \(entry.episodes.count) episodes"
        }
        return "\(first.shortCode) · \(first.name)"
    }

    /// "HBO · Drama".
    private var channelLine: String {
        [entry.show.channel?.name, entry.show.genres.first].compactMap { $0 }.joined(separator: " · ")
    }
}
