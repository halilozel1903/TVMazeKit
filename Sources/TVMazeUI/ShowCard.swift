import SwiftUI
import TVMazeKit

/// A show as a poster with its title (`.poster`) or as a compact list row (`.row`).
///
/// The card is plain content: put it in a `Button` or `NavigationLink`. On Apple TV, use
/// ``TVMazeCardButtonStyle`` for the focus effect.
///
/// ```swift
/// Button { open(show) } label: {
///     ShowCard(show: show, caption: "9:00 PM · Northwind")
/// }
/// .buttonStyle(TVMazeCardButtonStyle())
/// ```
public struct ShowCard: View {
    public enum Style: Sendable {
        /// A poster with the title and a caption below. The default.
        case poster
        /// A small poster beside the title, the year, channel and genres, and the summary.
        case row
    }

    private let show: Show
    private let style: Style
    private let caption: String?
    private let width: CGFloat?

    /// - Parameters:
    ///   - show: The show.
    ///   - style: `.poster` or `.row`.
    ///   - caption: The line under the title; by default the years, channel and first genre.
    ///   - width: The poster width (`.poster` only); a size for the platform by default.
    public init(show: Show, style: Style = .poster, caption: String? = nil, width: CGFloat? = nil) {
        self.show = show
        self.style = style
        self.caption = caption
        self.width = width
    }

    public var body: some View {
        switch style {
        case .poster:
            posterCard
        case .row:
            rowCard
        }
    }

    private var posterCard: some View {
        let posterWidth = width ?? Metrics.posterWidth
        return VStack(alignment: .leading, spacing: Metrics.spacing * 0.3) {
            poster
                .frame(width: posterWidth, height: posterWidth / Metrics.posterAspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    RatingBadge(show.rating?.average)
                        .padding(Metrics.badgePadding * 0.8)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
                    .font(Metrics.titleFont)
                    .lineLimit(1)
                Text(caption ?? TVMazeFormat.showLine(show))
                    .font(Metrics.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: posterWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var rowCard: some View {
        let posterWidth = width ?? Metrics.rowPosterWidth
        return HStack(alignment: .top, spacing: Metrics.spacing) {
            poster
                .frame(width: posterWidth, height: posterWidth / Metrics.posterAspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius * 0.7, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(Metrics.titleFont)
                    .lineLimit(2)
                Text(caption ?? TVMazeFormat.showLine(show))
                    .font(Metrics.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let summary = show.plainSummary {
                    Text(summary)
                        .font(Metrics.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                RatingBadge(show.rating?.average)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var poster: some View {
        TVMazeImage(url: show.image?.preferred, title: show.name, systemImage: "tv")
    }
}
