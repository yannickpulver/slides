import CoreGraphics
import Foundation
import Observation
import SlidesCore

/// Decoded previews (photos and video posters) for the editor, at most 2048 px.
/// A photo zoomed in past its preview also gets a sharper decode, for the few most recent ones.
@MainActor
@Observable
final class MediaCache {
    static let shared = MediaCache()
    static let maxPixelSize = 2048
    /// Long side of the sharpest decode: 8192 px is about 180 MB for a 3:2 photo.
    static let maxSharpPixelSize = 8192
    static let sharpLimit = 3

    private(set) var images: [URL: CGImage] = [:]
    /// Sharper decodes with the long side they were asked for.
    private(set) var sharp: [URL: (image: CGImage, size: Int)] = [:]
    @ObservationIgnored private var loading: Set<URL> = []
    @ObservationIgnored private var loadingSharp: [URL: Int] = [:]
    @ObservationIgnored private var sharpOrder: [URL] = []

    /// Returns the preview if decoded; otherwise starts decoding and returns `nil` until it lands.
    func image(for url: URL) -> CGImage? {
        if let image = images[url] { return image }
        load(url)
        return nil
    }

    /// Like `image(for:)`, but sharp enough for `pixels` on the long side: decodes a bigger
    /// version when the preview falls short and shows the preview until it lands.
    func image(for url: URL, pixels: Double) -> CGImage? {
        guard let preview = image(for: url) else { return nil }
        // A preview smaller than the limit is already the whole photo.
        guard max(preview.width, preview.height) >= Self.maxPixelSize, pixels > Double(Self.maxPixelSize) * 1.1 else {
            return sharp[url]?.image ?? preview
        }
        // Powers of two, so a pinch decodes a few times instead of on every step.
        var size = Self.maxPixelSize * 2
        while Double(size) < pixels, size < Self.maxSharpPixelSize { size *= 2 }
        if let entry = sharp[url] {
            touch(url)
            // Asked for at least this much, or the decode came back smaller: the whole photo.
            let whole = max(entry.image.width, entry.image.height) < entry.size
            if entry.size >= size || whole { return entry.image }
        }
        loadSharp(url, size: size)
        return sharp[url]?.image ?? preview
    }

    /// Decodes ahead of time, so a dropped file shows up without a loading flash.
    func preload(_ url: URL) async {
        guard images[url] == nil else { return }
        let image = await Self.decode(url, maxPixelSize: Self.maxPixelSize)
        if let image { images[url] = image }
    }

    private func load(_ url: URL) {
        guard !loading.contains(url) else { return }
        loading.insert(url)
        Task {
            let image = await Self.decode(url, maxPixelSize: Self.maxPixelSize)
            loading.remove(url)
            if let image { images[url] = image }
        }
    }

    private func loadSharp(_ url: URL, size: Int) {
        guard (loadingSharp[url] ?? 0) < size else { return }
        loadingSharp[url] = size
        Task {
            let image = await Self.decode(url, maxPixelSize: size)
            guard loadingSharp[url] == size else { return }
            loadingSharp[url] = nil
            guard let image else { return }
            sharp[url] = (image, size)
            touch(url)
            while sharpOrder.count > Self.sharpLimit { sharp[sharpOrder.removeFirst()] = nil }
        }
    }

    private func touch(_ url: URL) {
        sharpOrder.removeAll { $0 == url }
        sharpOrder.append(url)
    }

    @concurrent
    private static func decode(_ url: URL, maxPixelSize: Int) async -> CGImage? {
        await MediaLoader.preview(at: url, maxPixelSize: maxPixelSize)
    }
}
