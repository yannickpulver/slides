import CoreGraphics
import CoreImage
import Foundation
import ImageIO

/// Draws the frames of one slide at a fixed scale.
///
/// `images` maps a media file name to its decoded, upright pixels. The video export swaps
/// in a new frame per video file before each `draw`.
public final class SlideRenderer {
    public let layout: SlideLayout
    public let scale: Double
    public var images: [String: CGImage]
    private let background: CGImage?
    private var blurredBackgrounds: [Int: CGImage] = [:]

    public init(layout: SlideLayout, scale: Double, images: [String: CGImage], background: CGImage?) {
        self.layout = layout
        self.scale = scale
        self.images = images
        self.background = background
    }

    public var pixelWidth: Int { Int((layout.format.width * scale).rounded()) }
    public var pixelHeight: Int { Int((layout.format.height * scale).rounded()) }

    /// One exported frame as an image.
    public func render(part: Int) -> CGImage? {
        guard let context = Self.makeContext(width: pixelWidth, height: pixelHeight) else { return nil }
        draw(part: part, in: context)
        return context.makeImage()
    }

    /// Draws frame `part` into a context of `pixelWidth` × `pixelHeight`.
    public func draw(part: Int, in context: CGContext) {
        let slide = layout.slide
        let partRect = layout.part(part)
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .high
        // Flip to y-down, 1x units, origin at the part's left edge.
        context.translateBy(x: 0, y: Double(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -partRect.minX, y: 0)

        context.setFillColor(slide.style.color.cgColor)
        context.fill(partRect)

        if let backgroundImage = blurredBackground(part: part) {
            Self.draw(backgroundImage, in: partRect, context: context)
        }

        for (index, media) in slide.slots.enumerated() {
            guard let media, index < layout.slots.count, let image = images[media.file] else { continue }
            let mediaSize = CGSize(width: image.width, height: image.height)
            let visible = layout.visibleArea(slot: index)
            guard visible.intersects(partRect) else { continue }
            context.saveGState()
            context.clip(to: visible)
            Self.draw(image, in: layout.mediaRect(slot: index, mediaSize: mediaSize, crop: media.crop), context: context)
            context.restoreGState()
        }

        if let edge = slide.style.filmEdge {
            var sizes: [Int: CGSize] = [:]
            for (index, media) in slide.slots.enumerated() {
                if let media, let image = images[media.file] { sizes[index] = CGSize(width: image.width, height: image.height) }
            }
            let rect = layout.filmEdgeRect(mediaSizes: sizes)
            if !rect.isEmpty, let mask = FilmEdgeCache.shared.image(edge, landscape: rect.width > rect.height) {
                Self.draw(mask, in: rect, context: context)
            }
        }

        for box in slide.texts {
            TextRenderer.draw(box, in: context)
        }
    }

    /// Background image for one part: covered over the whole slide, blurred, cut to the part.
    private func blurredBackground(part: Int) -> CGImage? {
        guard let background else { return nil }
        if let cached = blurredBackgrounds[part] { return cached }
        let blur = clamp(layout.slide.style.blur, 0, SlideStyle.maxBlur)
        // Render a margin around the part so the blur pulls in the neighbouring pixels.
        let margin = blur * 3
        let partRect = layout.part(part)
        let region = partRect.insetBy(dx: -margin, dy: -margin).intersection(layout.canvas)
        let width = Int((region.width * scale).rounded(.up))
        let height = Int((region.height * scale).rounded(.up))
        guard let context = Self.makeContext(width: width, height: height) else { return nil }
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: Double(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -region.minX, y: -region.minY)
        let size = CGSize(width: background.width, height: background.height)
        Self.draw(background, in: layout.backgroundRect(imageSize: size), context: context)
        guard var image = context.makeImage() else { return nil }

        if blur * scale >= 0.5 {
            let input = CIImage(cgImage: image)
            let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: blur * scale).cropped(to: input.extent)
            guard let output = Self.ciContext.createCGImage(blurred, from: input.extent) else { return nil }
            image = output
        }
        // Crop the region down to the part, in pixel coordinates (y-down for CGImage cropping).
        let crop = CGRect(
            x: (partRect.minX - region.minX) * scale,
            y: (partRect.minY - region.minY) * scale,
            width: partRect.width * scale,
            height: partRect.height * scale
        ).integral
        let result = image.cropping(to: crop)
        blurredBackgrounds[part] = result
        return result
    }

    // MARK: - Drawing helpers

    static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: max(width, 1),
            height: max(height, 1),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Draws upright in a y-down context.
    static func draw(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}

extension RGB {
    public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

/// Full-size film-edge masks, decoded once.
final class FilmEdgeCache: @unchecked Sendable {
    static let shared = FilmEdgeCache()
    private let lock = NSLock()
    private var images: [String: CGImage] = [:]

    func image(_ edge: FilmEdge, landscape: Bool) -> CGImage? {
        let key = "\(edge.rawValue)-\(landscape)"
        lock.lock()
        defer { lock.unlock() }
        if let image = images[key] { return image }
        guard let url = edge.url(landscape: landscape, preview: false),
              let image = MediaLoader.image(at: url) else { return nil }
        images[key] = image
        return image
    }
}
