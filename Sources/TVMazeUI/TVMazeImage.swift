import SwiftUI
import TVMazeKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an image URL. The views in this module load posters, stills and headshots
/// through the loader in the environment, so you can swap in your own cache or, in previews and
/// tests, bundled artwork.
///
/// ```swift
/// ContentView()
///     .tvMazeImageLoader(TVMazeImageLoader { url in
///         try Data(contentsOf: Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil)!)
///     })
/// ```
public struct TVMazeImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared` (or from disk for file URLs), keeping recent images in
    /// memory.
    public static let urlSession = TVMazeImageLoader { url in
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await ImageDataCache.shared.data(for: url) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await ImageDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back doesn't hit the network again.
actor ImageDataCache {
    static let shared = ImageDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 200

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so a poster that scrolls back into view appears at once.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 300

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    static func decode(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct TVMazeImageLoaderKey: EnvironmentKey {
    static let defaultValue: TVMazeImageLoader = .urlSession
}

extension EnvironmentValues {
    /// The loader ``TVMazeImage`` uses. Defaults to ``TVMazeImageLoader/urlSession``.
    public var tvMazeImageLoader: TVMazeImageLoader {
        get { self[TVMazeImageLoaderKey.self] }
        set { self[TVMazeImageLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every TVMaze image below this view with `loader`.
    public func tvMazeImageLoader(_ loader: TVMazeImageLoader) -> some View {
        environment(\.tvMazeImageLoader, loader)
    }
}

/// An image from a TVMaze URL that fills the space it is given, with a placeholder while it loads
/// or when there is no image.
///
/// Give it a frame or an aspect ratio; the image is scaled to fill and clipped.
public struct TVMazeImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @Environment(\.tvMazeImageLoader) private var loader
    @State private var loaded: LoadedImage?

    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedImageCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedImageCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let image = DecodedImageCache.decode(data) else { return }
        DecodedImageCache.shared.insert(image, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = LoadedImage(url: url, image: image)
        }
    }
}

private struct LoadedImage {
    let url: URL
    let image: Image
}

extension TVMazeImage where Placeholder == ArtworkPlaceholder {
    /// An image with a generated placeholder: a gradient picked from `title`, with a symbol.
    public init(url: URL?, title: String?, systemImage: String = "tv", contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            ArtworkPlaceholder(title: title, systemImage: systemImage)
        }
    }
}

/// A gradient with a symbol, the same colors every time for the same title.
public struct ArtworkPlaceholder: View {
    private let title: String?
    private let systemImage: String

    public init(title: String?, systemImage: String = "tv") {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        let palette = ArtworkPlaceholder.palette(for: title ?? "")
        LinearGradient(colors: [palette.0, palette.1], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .accessibilityHidden(true)
    }

    /// A stable (not per-launch) hash of the title picks one of a few dark gradients.
    static func palette(for title: String) -> (Color, Color) {
        let seed = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let palettes: [(Color, Color)] = [
            (Color(red: 0.16, green: 0.20, blue: 0.36), Color(red: 0.06, green: 0.08, blue: 0.16)),
            (Color(red: 0.32, green: 0.14, blue: 0.26), Color(red: 0.10, green: 0.05, blue: 0.10)),
            (Color(red: 0.10, green: 0.28, blue: 0.26), Color(red: 0.04, green: 0.10, blue: 0.10)),
            (Color(red: 0.34, green: 0.22, blue: 0.10), Color(red: 0.12, green: 0.07, blue: 0.04)),
            (Color(red: 0.18, green: 0.18, blue: 0.22), Color(red: 0.06, green: 0.06, blue: 0.08)),
        ]
        return palettes[seed % palettes.count]
    }
}
