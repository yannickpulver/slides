import CoreGraphics
import ImageIO
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
    @ObservationIgnored private var cameras: [URL: CameraInfo] = [:]

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

    /// Camera and lens from the photo's EXIF, read once per file.
    func camera(for url: URL) -> CameraInfo {
        if let info = cameras[url] { return info }
        let info = CameraInfo(url: url)
        cameras[url] = info
        return info
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

/// What a photo was taken with; `nil` where the file doesn't say.
struct CameraInfo {
    var camera: String?
    var lens: String?
    /// Focal length, aperture, shutter and ISO, as far as known: "35 mm", "f/3.5", "1/2000 s", "ISO 100".
    var exposure: [String] = []

    init(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        camera = Self.camera(make: Self.text(tiff?[kCGImagePropertyTIFFMake]), model: Self.text(tiff?[kCGImagePropertyTIFFModel]))
        lens = Self.text(exif?[kCGImagePropertyExifLensModel])
        let focal = (exif?[kCGImagePropertyExifFocalLength] as? Double).map { "\(Self.number($0)) mm" }
        let aperture = (exif?[kCGImagePropertyExifFNumber] as? Double).map { "f/\(Self.number($0))" }
        let shutter = (exif?[kCGImagePropertyExifExposureTime] as? Double).flatMap(Self.shutter)
        let iso = (exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first.map { "ISO \($0)" }
        exposure = [focal, aperture, shutter, iso].compactMap { $0 }
    }

    var isEmpty: Bool { camera == nil && lens == nil && exposure.isEmpty }

    /// 1/2000 s below a second, 2 s or 0.5 s otherwise, as cameras show it.
    private static func shutter(_ seconds: Double) -> String? {
        guard seconds > 0 else { return nil }
        return seconds < 0.4 ? "1/\(Int((1 / seconds).rounded())) s" : "\(number(seconds)) s"
    }

    /// At most one decimal, none when whole: 35, 5.6.
    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "Canon" + "Canon EOS R5" reads "Canon EOS R5"; "FUJIFILM" + "X100VI" reads "FUJIFILM X100VI".
    private static func camera(make: String?, model: String?) -> String? {
        guard let model else { return make }
        guard let brand = make?.split(separator: " ").first else { return model }
        return model.lowercased().hasPrefix(brand.lowercased()) ? model : "\(brand) \(model)"
    }

    private static func text(_ value: Any?) -> String? {
        let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return text?.isEmpty == false ? text : nil
    }
}
