@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
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
        if let maxPixelSize, isRAW(url), let image = rawImage(at: url, maxPixelSize: maxPixelSize) { return image }
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

    /// Pixel size of a photo upright, read from the file's header without decoding.
    public static func imageSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        // Orientations 5 to 8 turn the photo by 90°.
        let turned = (properties[kCGImagePropertyOrientation] as? Int).map { (5...8).contains($0) } ?? false
        return turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    private static func isRAW(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .rawImage) ?? false
    }

    private static let rawContext = CIContext()

    /// A RAW developed at reduced scale: several times faster than ImageIO for a large sensor,
    /// with the same look (ImageIO uses the same RAW engine).
    private static func rawImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        let longSide = max(filter.nativeSize.width, filter.nativeSize.height)
        guard longSide > 0 else { return nil }
        filter.scaleFactor = Float(min(Double(maxPixelSize) / longSide, 1))
        guard let output = filter.outputImage, let space = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        return rawContext.createCGImage(output, from: output.extent.integral, format: .RGBA8, colorSpace: space)
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
