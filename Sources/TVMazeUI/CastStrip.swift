import SwiftUI
import TVMazeKit

/// A horizontal strip of round headshots with each person's name and role.
///
/// Pass `onSelect` to make the people tappable (and focusable buttons on Apple TV). Without it,
/// on Apple TV every person is still focusable so the strip can be scrolled with the remote.
public struct CastStrip: View {
    private let cast: [CastCredit]
    private let onSelect: ((CastCredit) -> Void)?

    public init(cast: [CastCredit], onSelect: ((CastCredit) -> Void)? = nil) {
        self.cast = cast
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Metrics.spacing * 0.9) {
                ForEach(cast) { credit in
                    item(credit)
                }
            }
            #if os(tvOS)
            .padding(.vertical, 24)
            #endif
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func item(_ credit: CastCredit) -> some View {
        if let onSelect {
            Button {
                onSelect(credit)
            } label: {
                CastMember(credit: credit)
            }
            .buttonStyle(TVMazeCardButtonStyle(focusedScale: 1.1))
        } else {
            #if os(tvOS)
            CastMember(credit: credit)
                .focusable()
            #else
            CastMember(credit: credit)
            #endif
        }
    }
}

/// One person in a ``CastStrip``.
public struct CastMember: View {
    private let credit: CastCredit

    @Environment(\.isFocused) private var isFocused

    public init(credit: CastCredit) {
        self.credit = credit
    }

    public var body: some View {
        VStack(spacing: 6) {
            TVMazeImage(url: credit.person.image?.preferred) {
                ZStack {
                    ArtworkPlaceholder(title: credit.person.name, systemImage: "person.fill")
                    Text(credit.person.initials)
                        .font(.system(size: Metrics.headshot * 0.32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
            .frame(width: Metrics.headshot, height: Metrics.headshot)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Color.white.opacity(isFocused ? 0.9 : 0.12), lineWidth: isFocused ? 4 : 1)
            }
            .scaleEffect(isFocused ? 1.1 : 1)
            .shadow(color: Color.black.opacity(isFocused ? 0.5 : 0), radius: 16, x: 0, y: 10)
            .animation(.easeOut(duration: 0.2), value: isFocused)

            Text(credit.person.name)
                .font(Metrics.captionFont.weight(.semibold))
                .lineLimit(1)
            Text(role)
                .font(Metrics.captionFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: Metrics.castItemWidth)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var role: String {
        if credit.isSelf { return "Self" }
        if credit.isVoice { return "Voice of \(credit.character.name)" }
        return credit.character.name
    }
}
