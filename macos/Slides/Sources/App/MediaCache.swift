import CoreGraphics
import Foundation
import Observation
import SlidesCore

/// Decoded previews (photos and video posters) for the editor, at most 2048 px.
@MainActor
@Observable
final class MediaCache {
    static let shared = MediaCache()
    static let maxPixelSize = 2048

    private(set) var images: [URL: CGImage] = [:]
    @ObservationIgnored private var loading: Set<URL> = []

    /// Returns the preview if decoded; otherwise starts decoding and returns `nil` until it lands.
    func image(for url: URL) -> CGImage? {
        if let image = images[url] { return image }
        load(url)
        return nil
    }

    /// Decodes ahead of time, so a dropped file shows up without a loading flash.
    func preload(_ url: URL) async {
        guard images[url] == nil else { return }
        let image = await Self.decode(url)
        if let image { images[url] = image }
    }

    private func load(_ url: URL) {
        guard !loading.contains(url) else { return }
        loading.insert(url)
        Task {
            let image = await Self.decode(url)
            loading.remove(url)
            if let image { images[url] = image }
        }
    }

    @concurrent
    private static func decode(_ url: URL) async -> CGImage? {
        await MediaLoader.preview(at: url, maxPixelSize: maxPixelSize)
    }
}
