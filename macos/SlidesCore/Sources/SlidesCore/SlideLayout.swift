import CoreGraphics
import Foundation

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

    /// The canvas minus the border: the border runs once around the whole slide.
    public var content: CGRect {
        let border = min(clamp(slide.style.border, 0, SlideStyle.maxBorder), canvas.width / 2 - 0.5, canvas.height / 2 - 0.5)
        return canvas.insetBy(dx: max(border, 0), dy: max(border, 0))
    }

    /// Slot areas inside `content`, row by row, with the gap between rows and columns.
    public var slots: [CGRect] {
        let area = content
        let rows = slide.layout.slotCount
        let columns = max(slide.columns, 1)
        let gap = clamp(slide.style.gap, 0, SlideStyle.maxGap)
        let rowGap = rows > 1 ? min(gap, area.height / Double(rows - 1) - 1) : 0
        let columnGap = columns > 1 ? min(gap, area.width / Double(columns - 1) - 1) : 0
        let height = (area.height - rowGap * Double(rows - 1)) / Double(rows)
        let width = (area.width - columnGap * Double(columns - 1)) / Double(columns)
        return (0..<rows * columns).map { i in
            let (row, column) = i.quotientAndRemainder(dividingBy: columns)
            return CGRect(x: area.minX + Double(column) * (width + columnGap), y: area.minY + Double(row) * (height + rowGap), width: width, height: height)
        }
    }

    /// Part of the slide the photo in a slot may cover.
    public func visibleArea(slot index: Int) -> CGRect {
        slots[index]
    }

    /// Where the photo is drawn, before turning by `crop.angle` around its center and clipping to `visibleArea`.
    public func mediaRect(slot index: Int, mediaSize: CGSize, crop: Crop) -> CGRect {
        Self.mediaRect(in: visibleArea(slot: index), mediaSize: mediaSize, fit: slide.style.fit, crop: crop)
    }

    /// Where the film edge goes: once around the visible parts of all photos together.
    /// `mediaSizes` maps a slot index to its photo's pixel size; slots without a size are skipped.
    public func filmEdgeRect(mediaSizes: [Int: CGSize]) -> CGRect {
        mediaSizes.reduce(CGRect.null) { union, entry in
            guard entry.key < slots.count, entry.key < slide.slots.count, let media = slide.slots[entry.key] else { return union }
            let rect = mediaRect(slot: entry.key, mediaSize: entry.value, crop: media.crop)
            let visible = Self.turnedBounds(rect, angle: media.crop.angle).intersection(visibleArea(slot: entry.key))
            return union.union(visible)
        }
    }

    /// Show Crop: the whole photo scaled down to fit its slot, and the box on it that the slot normally shows.
    public func cropPreview(slot index: Int, mediaSize: CGSize, crop: Crop) -> CropPreview {
        CropPreview(mediaRect: mediaRect(slot: index, mediaSize: mediaSize, crop: crop), angle: crop.angle, area: visibleArea(slot: index))
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
            // The turned photo fits inside the slot.
            let (c, s) = absTurn(crop.angle)
            let scale = min(area.width / (w * c + h * s), area.height / (w * s + h * c))
            return centered(in: area, width: w * scale, height: h * scale)
        case .fill:
            let fill = fillPlacement(in: area, mediaSize: mediaSize, crop: crop)
            return fill.rect.offsetBy(dx: fill.shift.x, dy: fill.shift.y)
        }
    }

    /// Keeps the photo covering `area`: zoom within 1...max, shift within the overhang, angle within ±max.
    public static func clampedCrop(_ crop: Crop, in area: CGRect, mediaSize: CGSize) -> Crop {
        var result = crop
        result.zoom = clamp(crop.zoom, 1, Crop.maxZoom)
        result.angle = clamp(crop.angle, -Crop.maxAngle, Crop.maxAngle)
        let shift = fillPlacement(in: area, mediaSize: mediaSize, crop: result).shift
        result.x = shift.x / max(area.width, 1)
        result.y = shift.y / max(area.height, 1)
        return result
    }

    /// Bounding box of `rect` turned by `angle` degrees around its center.
    public static func turnedBounds(_ rect: CGRect, angle: Double) -> CGRect {
        let (c, s) = absTurn(angle)
        return centered(in: rect, width: rect.width * c + rect.height * s, height: rect.width * s + rect.height * c)
    }

    /// Fill mode: the photo rect centered on the slot, and its shift from there.
    ///
    /// The slot, seen in the turned photo's axes, has to stay inside the photo. So the photo grows
    /// to cover the slot's turned bounding box, and the shift is clamped along the photo's axes.
    private static func fillPlacement(in area: CGRect, mediaSize: CGSize, crop: Crop) -> (rect: CGRect, shift: CGPoint) {
        let w = max(mediaSize.width, 1)
        let h = max(mediaSize.height, 1)
        let (c, s) = absTurn(crop.angle)
        let needW = area.width * c + area.height * s
        let needH = area.width * s + area.height * c
        let scale = max(needW / w, needH / h) * clamp(crop.zoom, 1, Crop.maxZoom)
        let rect = centered(in: area, width: w * scale, height: h * scale)
        // Never shift past the overhang, so the photo covers the slot even after the slot changed shape.
        let maxX = max(rect.width - needW, 0) / 2
        let maxY = max(rect.height - needH, 0) / 2
        let radians = clamp(crop.angle, -Crop.maxAngle, Crop.maxAngle) * .pi / 180
        let (cos, sin) = (Foundation.cos(radians), Foundation.sin(radians))
        let dx = crop.x * area.width, dy = crop.y * area.height
        // Into the photo's axes, clamp, and back.
        let u = clamp(dx * cos + dy * sin, -maxX, maxX)
        let v = clamp(-dx * sin + dy * cos, -maxY, maxY)
        return (rect, CGPoint(x: u * cos - v * sin, y: u * sin + v * cos))
    }

    /// |cos| and |sin| of a clamped angle in degrees.
    private static func absTurn(_ angle: Double) -> (Double, Double) {
        let radians = clamp(angle, -Crop.maxAngle, Crop.maxAngle) * .pi / 180
        return (abs(Foundation.cos(radians)), abs(Foundation.sin(radians)))
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

/// Show Crop geometry for one slot, in the same coordinates as the slot's area.
public struct CropPreview: Equatable, Sendable {
    /// Width of the box outline and grid lines, in 1x pixels.
    public static let lineWidth = 2.0
    /// Opacity of the black over the photo outside the box.
    public static let dim = 0.55

    /// The whole photo, before turning by the crop's angle around its center.
    public let photo: CGRect
    /// The part of the photo the slot shows without Show Crop.
    public let box: CGRect
    /// How much the photo shrinks: on-screen distances inside the box times this.
    public let factor: Double

    /// Shrinks the turned photo to fit `area` and centers it; the area itself becomes the box.
    public init(mediaRect: CGRect, angle: Double, area: CGRect) {
        let bounds = SlideLayout.turnedBounds(mediaRect, angle: angle)
        let factor = min(area.width / max(bounds.width, 1), area.height / max(bounds.height, 1), 1)
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x - mediaRect.midX) * factor + area.midX, y: (point.y - mediaRect.midY) * factor + area.midY)
        }
        self.factor = factor
        photo = CGRect(origin: map(mediaRect.origin), size: CGSize(width: mediaRect.width * factor, height: mediaRect.height * factor))
        box = CGRect(origin: map(area.origin), size: CGSize(width: area.width * factor, height: area.height * factor))
    }

    /// Lines at a third and two thirds of the box, both ways.
    public var thirds: [(CGPoint, CGPoint)] {
        (1...2).flatMap { i -> [(CGPoint, CGPoint)] in
            let x = box.minX + box.width * Double(i) / 3, y = box.minY + box.height * Double(i) / 3
            return [(CGPoint(x: x, y: box.minY), CGPoint(x: x, y: box.maxY)), (CGPoint(x: box.minX, y: y), CGPoint(x: box.maxX, y: y))]
        }
    }
}
