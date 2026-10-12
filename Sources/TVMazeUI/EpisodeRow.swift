import SwiftUI
import TVMazeKit

/// An episode with its still, number, title, air date, runtime, rating and summary.
///
/// `.list` puts the still beside the text, for an episode list. `.card` puts it on top, for a
/// horizontal rail on Apple TV. The summary has its HTML removed.
public struct EpisodeRow: View {
    public enum Style: Sendable {
        case list
        case card
    }

    private let episode: Episode
    private let style: Style
    private let summaryLines: Int

    public init(episode: Episode, style: Style = .list, summaryLines: Int = 2) {
        self.episode = episode
        self.style = style
        self.summaryLines = summaryLines
    }

    public var body: some View {
        switch style {
        case .list:
            HStack(alignment: .top, spacing: Metrics.spacing) {
                still(width: Metrics.listStillWidth)
                text
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        case .card:
            VStack(alignment: .leading, spacing: Metrics.spacing * 0.35) {
                still(width: Metrics.stillWidth)
                text
                    .frame(width: Metrics.stillWidth, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func still(width: CGFloat) -> some View {
        TVMazeImage(url: episode.image?.preferred) {
            ZStack {
                ArtworkPlaceholder(title: episode.links?.show?.name ?? episode.name, systemImage: "film")
                Text(episode.code)
                    .font(Metrics.captionFont.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .offset(y: width * 0.14)
            }
        }
        .frame(width: width, height: width * 9 / 16)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius * 0.8, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if let runtime = episode.runtime {
                Text(TVMazeFormat.runtime(runtime))
                    .font(Metrics.captionFont.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(6)
            }
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Metrics.titleFont)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(detail)
                    .lineLimit(1)
                if let rating = episode.rating?.average {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.yellow)
                        Text(TVMazeFormat.rating(rating))
                            .monospacedDigit()
                    }
                }
            }
            .font(Metrics.captionFont)
            .foregroundStyle(.secondary)
            if let summary = episode.plainSummary, summaryLines > 0 {
                Text(summary)
                    .font(Metrics.bodyFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(summaryLines)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    /// "1. Winter Is Coming", or "Special · The Last Watch".
    private var title: String {
        if let number = episode.number {
            return "\(number). \(episode.name)"
        }
        return "Special · \(episode.name)"
    }

    /// "S2 · E5 · Thu, Oct 8", or "S2 · E10 · TBA".
    private var detail: String {
        let date = episode.airdate.map { TVMazeFormat.airdate($0) } ?? "TBA"
        return "\(episode.shortCode) · \(date)"
    }
}
