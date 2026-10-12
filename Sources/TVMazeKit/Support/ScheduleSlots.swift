import Foundation

/// A show's episodes in one time slot of a schedule. Streaming services often release a whole
/// season at once; those episodes become one entry.
public struct ScheduleEntry: Hashable, Sendable, Identifiable {
    public var show: Show
    /// In season and episode order.
    public var episodes: [Episode]

    public init(show: Show, episodes: [Episode]) {
        self.show = show
        self.episodes = episodes
    }

    public var id: String { "\(show.id)-\(episodes.first?.id ?? 0)" }

    /// The first episode of the entry.
    public var episode: Episode? { episodes.first }
}

/// The entries that start at the same time.
public struct ScheduleSlot: Hashable, Sendable, Identifiable {
    /// The network-local start time, or `nil` for episodes without one (most streaming releases).
    public var time: AirTime?
    public var entries: [ScheduleEntry]

    public init(time: AirTime?, entries: [ScheduleEntry]) {
        self.time = time
        self.entries = entries
    }

    public var id: String { time?.description ?? "anytime" }

    /// Every episode in the slot.
    public var episodeCount: Int { entries.reduce(0) { $0 + $1.episodes.count } }
}

extension Array where Element == Episode {
    /// Groups schedule episodes (from `/schedule` or `/schedule/web`) into time slots.
    ///
    /// Slots are ordered by when they air (the airstamp, so a 00:30 slot after midnight comes
    /// last), episodes without a time come at the end. In a slot, a show's episodes are merged into
    /// one entry, and entries are ordered by popularity (`weight`), then by name. Episodes without
    /// an embedded show are left out.
    public func scheduleSlots() -> [ScheduleSlot] {
        struct Bucket {
            var time: AirTime?
            var earliest: Date?
            var order: [Int] = []
            var shows: [Int: Show] = [:]
            var episodes: [Int: [Episode]] = [:]
        }

        var buckets: [String: Bucket] = [:]
        var keys: [String] = []
        for episode in self {
            guard let show = episode.show else { continue }
            let time = episode.airTime
            let key = time?.description ?? ""
            if buckets[key] == nil {
                buckets[key] = Bucket(time: time)
                keys.append(key)
            }
            var bucket = buckets[key]!
            if let stamp = episode.airstamp, bucket.earliest.map({ stamp < $0 }) ?? true {
                bucket.earliest = stamp
            }
            if bucket.shows[show.id] == nil {
                bucket.shows[show.id] = show
                bucket.order.append(show.id)
            }
            bucket.episodes[show.id, default: []].append(episode)
            buckets[key] = bucket
        }

        let sortedKeys = keys.sorted { lhsKey, rhsKey in
            let lhs = buckets[lhsKey]!
            let rhs = buckets[rhsKey]!
            switch (lhs.time, rhs.time) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case let (l?, r?):
                if let a = lhs.earliest, let b = rhs.earliest, a != b { return a < b }
                return l < r
            }
        }

        return sortedKeys.map { key in
            let bucket = buckets[key]!
            let entries = bucket.order.compactMap { id -> ScheduleEntry? in
                guard let show = bucket.shows[id] else { return nil }
                let episodes = (bucket.episodes[id] ?? []).sorted { lhs, rhs in
                    if lhs.season != rhs.season { return lhs.season < rhs.season }
                    return (lhs.number ?? Int.max) < (rhs.number ?? Int.max)
                }
                return ScheduleEntry(show: show, episodes: episodes)
            }
            .sorted { lhs, rhs in
                let l = lhs.show.weight ?? 0
                let r = rhs.show.weight ?? 0
                if l != r { return l > r }
                return lhs.show.name.localizedStandardCompare(rhs.show.name) == .orderedAscending
            }
            return ScheduleSlot(time: bucket.time, entries: entries)
        }
    }

    /// The shows in these episodes, each once, in order of first appearance.
    public var uniqueShows: [Show] {
        var seen = Set<Int>()
        var shows: [Show] = []
        for episode in self {
            guard let show = episode.show, seen.insert(show.id).inserted else { continue }
            shows.append(show)
        }
        return shows
    }
}
