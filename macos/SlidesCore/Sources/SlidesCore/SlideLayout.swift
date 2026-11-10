import CoreGraphics

/// Geometry of a slide in 1x pixels, y pointing down.
///
/// A slide spans `span` frames side by side. The editor and the export both place
/// everything with these functions, so the export matches the screen.
public struct SlideLayout: Sendable {
    public let slide: Slide
    public let format: Format

    public init(slide: Slide, format: Format) {
        self.slide = slide
        self.format = format
    }

    public var frameSize: CGSize { CGSize(width: format.width, height: format.height) }

    /// The whole slide: all frames of a panorama next to each other.
    public var canvas: CGRect {
        CGRect(x: 0, y: 0, width: format.width * Double(slide.span), height: format.height)
    }

    /// Area of one exported frame within `canvas`.
    public func part(_ index: Int) -> CGRect {
        CGRect(x: format.width * Double(index), y: 0, width: format.width, height: format.height)
    }

    /// Slot areas, top to bottom, with the gap between them.
    public var slots: [CGRect] {
        let count = slide.layout.slotCount
        let gap = count > 1 ? clamp(slide.style.gap, 0, SlideStyle.maxGap) : 0
        let height = (canvas.height - gap * Double(count - 1)) / Double(count)
        return (0..<count).map { i in
            CGRect(x: 0, y: Double(i) * (height + gap), width: canvas.width, height: height)
        }
    }

    /// Part of a slot the photo may cover: the slot minus the border.
    public func visibleArea(slot index: Int) -> CGRect {
        let slot = slots[index]
        let border = min(clamp(slide.style.border, 0, SlideStyle.maxBorder), slot.width / 2 - 0.5, slot.height / 2 - 0.5)
        return slot.insetBy(dx: max(border, 0), dy: max(border, 0))
    }

    /// Where the photo is drawn, before clipping to `visibleArea`.
    public func mediaRect(slot index: Int, mediaSize: CGSize, crop: Crop) -> CGRect {
        Self.mediaRect(in: visibleArea(slot: index), mediaSize: mediaSize, fit: slide.style.fit, crop: crop)
    }

    /// Visible part of the photo, which the film edge covers.
    public func filmEdgeRect(slot index: Int, mediaSize: CGSize, crop: Crop) -> CGRect {
        mediaRect(slot: index, mediaSize: mediaSize, crop: crop).intersection(visibleArea(slot: index))
    }

    /// Background image covering the whole canvas, centered.
    public func backgroundRect(imageSize: CGSize) -> CGRect {
        Self.coverRect(in: canvas, size: imageSize)
    }

    // MARK: - Pure helpers

    public static func mediaRect(in area: CGRect, mediaSize: CGSize, fit: Fit, crop: Crop) -> CGRect {
        let w = max(mediaSize.width, 1)
        let h = max(mediaSize.height, 1)
        switch fit {
        case .full:
            let scale = min(area.width / w, area.height / h)
            return centered(in: area, width: w * scale, height: h * scale)
        case .fill:
            let scale = max(area.width / w, area.height / h) * clamp(crop.zoom, 1, Crop.maxZoom)
            let rect = centered(in: area, width: w * scale, height: h * scale)
            // Never shift past the overhang, so the photo covers the slot even after the slot changed shape.
            let maxX = max(rect.width - area.width, 0) / 2
            let maxY = max(rect.height - area.height, 0) / 2
            return rect.offsetBy(dx: clamp(crop.x * area.width, -maxX, maxX), dy: clamp(crop.y * area.height, -maxY, maxY))
        }
    }

    /// Keeps the photo covering `area`: zoom within 1...max, shift within the overhang.
    public static func clampedCrop(_ crop: Crop, in area: CGRect, mediaSize: CGSize) -> Crop {
        let zoom = clamp(crop.zoom, 1, Crop.maxZoom)
        let rect = mediaRect(in: area, mediaSize: mediaSize, fit: .fill, crop: Crop(zoom: zoom))
        let maxX = max(rect.width - area.width, 0) / 2 / max(area.width, 1)
        let maxY = max(rect.height - area.height, 0) / 2 / max(area.height, 1)
        return Crop(x: clamp(crop.x, -maxX, maxX), y: clamp(crop.y, -maxY, maxY), zoom: zoom)
    }

    public static func coverRect(in area: CGRect, size: CGSize) -> CGRect {
        let scale = max(area.width / max(size.width, 1), area.height / max(size.height, 1))
        return centered(in: area, width: size.width * scale, height: size.height * scale)
    }

    static func centered(in area: CGRect, width: Double, height: Double) -> CGRect {
        CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
    }
}

func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
    min(max(value, lower), upper)
}
