@preconcurrency import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum MediaLoader {
    /// File types the app accepts as photos or videos.
    public static let contentTypes: [UTType] = [.image, .movie]

    public static func kind(of url: URL) -> Media.Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .image) { return .image }
        return nil
    }

    /// Decodes a photo upright (EXIF orientation applied), at most `maxPixelSize` on its long side.
    public static func image(at url: URL, maxPixelSize: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if let maxPixelSize { options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// First frame of a video, upright.
    public static func videoPoster(at url: URL, maxPixelSize: Int? = nil) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
        if let maxPixelSize {
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        }
        return try? await generator.image(at: .zero).image
    }

    /// Photo or video poster, whichever the file is.
    public static func preview(at url: URL, maxPixelSize: Int? = nil) async -> CGImage? {
        switch kind(of: url) {
        case .image: image(at: url, maxPixelSize: maxPixelSize)
        case .video: await videoPoster(at: url, maxPixelSize: maxPixelSize)
        case nil: nil
        }
    }
}
