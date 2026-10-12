import SwiftUI
import TVMazeKit
import TVMazeUI

/// A show's page: poster, facts and summary, a season picker whose selection follows focus, the
/// season's episodes and the cast.
struct TVShowView: View {
    let showID: Int
    let scene: ScreenshotScene?

    @Environment(Guide.self) private var guide
    @State private var show: Show?
    @State private var errorMessage: String?
    @State private var season: Int?
    @FocusState private var focus: Focus?

    private enum Focus: Hashable {
        case season(Int)
        case episode(Int)
    }

    init(showID: Int, scene: ScreenshotScene?) {
        self.showID = showID
        self.scene = scene
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            if let show {
                content(show)
            } else if let errorMessage {
                TVMessage(title: "Couldn't load this show", message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: showID) {
            await load()
        }
        .signalsScreenshotReady(scene, when: show != nil)
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await guide.details(of: showID)
            season = loaded.defaultSeasonNumber
            show = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func content(_ show: Show) -> some View {
        ZStack(alignment: .top) {
            backdrop(show)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 40) {
                    header(show)
                    seasonPicker(show)
                    episodes(show)
                    if !show.cast.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Cast")
                                .font(.system(size: 34, weight: .bold))
                                .padding(.horizontal, 80)
                            CastStrip(cast: show.cast)
                                .contentMargins(.horizontal, 80, for: .scrollContent)
                                .focusSection()
                        }
                    }
                    TVMazeAttributionView()
                        .padding(.horizontal, 80)
                }
                .padding(.top, 60)
                .padding(.bottom, 80)
            }
            .ignoresSafeArea()
        }
        .defaultFocus($focus, season.map { Focus.season($0) })
        .onChange(of: focus) { _, newValue in
            // On Apple TV the selection follows focus, like the system apps' tab rows.
            if case let .season(number) = newValue {
                season = number
            }
        }
    }

    private func backdrop(_ show: Show) -> some View {
        TVMazeImage(url: show.backgroundImageURL ?? show.image?.original, title: show.name)
            .opacity(0.35)
            .overlay {
                LinearGradient(
                    colors: [Theme.background.opacity(0.4), Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func header(_ show: Show) -> some View {
        HStack(alignment: .top, spacing: 56) {
            TVMazeImage(url: show.image?.original, title: show.name)
                .frame(width: 250, height: 351)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 14)
            VStack(alignment: .leading, spacing: 14) {
                Text(show.name)
                    .font(.system(size: 64, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 18) {
                    RatingBadge(show.rating?.average)
                    Text(Theme.showFacts(show))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                if let airing = Theme.airing(show) {
                    Label(airing, systemImage: "calendar")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.moon)
                }
                if let summary = show.plainSummary {
                    Text(summary)
                        .font(.system(size: 25))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(4)
                        .frame(maxWidth: 1150, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 80)
    }

    private func seasonPicker(_ show: Show) -> some View {
        let numbers = show.episodes.seasonNumbers
        return HStack(spacing: 20) {
            ForEach(numbers, id: \.self) { number in
                Button {
                    season = number
                } label: {
                    Text("Season \(number)")
                }
                .buttonStyle(SeasonButtonStyle(isSelected: season == number))
                .focused($focus, equals: .season(number))
            }
        }
        .padding(.horizontal, 80)
        .focusSection()
    }

    private func episodes(_ show: Show) -> some View {
        let list = season.map { show.episodes.inSeason($0) } ?? []
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 44) {
                ForEach(list) { episode in
                    FocusLift {
                        EpisodeRow(episode: episode, style: .card)
                    }
                    .focusable()
                    .focused($focus, equals: .episode(episode.id))
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .focusSection()
    }
}

/// Grows its content a little and lifts it on a shadow while focused.
struct FocusLift<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        content
            .scaleEffect(isFocused ? 1.06 : 1)
            .shadow(color: Color.black.opacity(isFocused ? 0.55 : 0), radius: 20, x: 0, y: 14)
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

/// A capsule: white when focused, tinted when selected, translucent otherwise.
struct SeasonButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        SeasonButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct SeasonButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .font(.system(size: 26, weight: .semibold))
            .padding(.horizontal, 34)
            .padding(.vertical, 14)
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background {
                Capsule().fill(isFocused ? Color.white : (isSelected ? Theme.indigo : Color.white.opacity(0.14)))
            }
            .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.96 : 1))
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
