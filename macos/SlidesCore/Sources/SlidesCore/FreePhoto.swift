import CoreGraphics
import Foundation

/// A still image placed anywhere on a slide's canvas, like free text. Always shown whole,
/// it keeps its aspect ratio and can be moved, resized, turned and given a photo frame.
public struct FreePhoto: Codable, Equatable, Sendable, Identifiable {
    public static let minWidth = 20.0

    public var id = UUID()
    /// File name inside the project's `media/` folder.
    public var file: String
    /// Center in 1x pixels on the slide's canvas (a panorama's whole width).
    public var x: Double
    public var y: Double
    /// Width of the photo itself in 1x pixels; the frame comes on top.
    public var width: Double
    /// Height over width of the photo, read from the file when it was added.
    public var aspect: Double
    /// Rotation in degrees, clockwise, around the center.
    public var angle = 0.0
    public var frame: PhotoFrame? = PhotoFrame()

    public init(file: String, x: Double, y: Double, width: Double, aspect: Double) {
        self.file = file
        self.x = x
        self.y = y
        self.width = width
        self.aspect = aspect
    }

    enum CodingKeys: String, CodingKey {
        case id, file, x, y, width, aspect, angle, frame
    }

    /// Missing values fall back to the defaults, so later additions keep older projects readable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        file = try c.decode(String.self, forKey: .file)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width)
        aspect = try c.decode(Double.self, forKey: .aspect)
        angle = (try? c.decodeIfPresent(Double.self, forKey: .angle)) ?? 0
        frame = try? c.decodeIfPresent(PhotoFrame.self, forKey: .frame)
    }

    public var height: Double { width * aspect }
    public var center: CGPoint { CGPoint(x: x, y: y) }

    /// The photo with its frame, upright, in canvas pixels. Rotation turns it around its center.
    public var outerRect: CGRect {
        let inset = frame?.width ?? 0
        return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height).insetBy(dx: -inset, dy: -inset)
    }

    /// Corners of the turned photo with its frame: top left, top right, bottom right, bottom left.
    public var corners: [CGPoint] {
        let rect = outerRect
        let radians = angle * .pi / 180
        return [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
        ].map { point in
            let dx = point.x - x, dy = point.y - y
            return CGPoint(x: x + dx * cos(radians) - dy * sin(radians), y: y + dx * sin(radians) + dy * cos(radians))
        }
    }

    /// Whether `point` (canvas pixels) lies on the turned photo or its frame.
    public func contains(_ point: CGPoint) -> Bool {
        let radians = -angle * .pi / 180
        let dx = point.x - x, dy = point.y - y
        let local = CGPoint(x: x + dx * cos(radians) - dy * sin(radians), y: y + dx * sin(radians) + dy * cos(radians))
        return outerRect.contains(local)
    }

    /// Draws the frame and the photo into a y-down context in 1x canvas units. Without an image only the frame shows.
    public func draw(_ image: CGImage?, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: x, y: y)
        context.rotate(by: angle * .pi / 180)
        let photo = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        if let frame, frame.width > 0 {
            context.setFillColor(frame.color.cgColor)
            context.fill(photo.insetBy(dx: -frame.width, dy: -frame.width))
        }
        guard let image else { return }
        context.translateBy(x: photo.minX, y: photo.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: photo.size))
    }
}

/// The colored edge around one free photo, even on all sides.
public struct PhotoFrame: Codable, Equatable, Sendable {
    public static let maxWidth = 120.0

    /// In 1x pixels.
    public var width = 16.0
    public var color: RGB = .white

    public init(width: Double = 16, color: RGB = .white) {
        self.width = width
        self.color = color
    }
}

/// Free text or a free photo. A slide keeps them in one back-to-front order, above the slot photos.
public enum FreeItem: Codable, Equatable, Sendable, Identifiable {
    case text(TextBox)
    case photo(FreePhoto)

    public var id: UUID {
        switch self {
        case .text(let box): box.id
        case .photo(let photo): photo.id
        }
    }

    /// Where the item sits: the middle of the text box or the photo's center.
    public var center: CGPoint {
        switch self {
        case .text(let box):
            let rect = TextRenderer.rect(of: box)
            return CGPoint(x: rect.midX, y: rect.midY)
        case .photo(let photo):
            return photo.center
        }
    }

    public mutating func move(dx: Double, dy: Double) {
        switch self {
        case .text(var box):
            box.x += dx
            box.y += dy
            self = .text(box)
        case .photo(var photo):
            photo.x += dx
            photo.y += dy
            self = .photo(photo)
        }
    }

    enum CodingKeys: String, CodingKey {
        case text, photo
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let box = try c.decodeIfPresent(TextBox.self, forKey: .text) {
            self = .text(box)
        } else {
            self = .photo(try c.decode(FreePhoto.self, forKey: .photo))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let box): try c.encode(box, forKey: .text)
        case .photo(let photo): try c.encode(photo, forKey: .photo)
        }
    }
}

extension Slide {
    public var freePhotos: [FreePhoto] {
        freeItems.compactMap { if case .photo(let photo) = $0 { photo } else { nil } }
    }

    /// Adds a free photo on top and returns its id.
    @discardableResult
    public mutating func addFreePhoto(_ photo: FreePhoto) -> FreePhoto.ID {
        freeItems.append(.photo(photo))
        return photo.id
    }

    public mutating func updateFreePhoto(_ id: FreePhoto.ID, _ change: (inout FreePhoto) -> Void) {
        guard let index = freeItems.firstIndex(where: { $0.id == id }), case .photo(var photo) = freeItems[index] else { return }
        change(&photo)
        photo.width = max(photo.width, FreePhoto.minWidth)
        if var frame = photo.frame {
            frame.width = min(max(frame.width, 0), PhotoFrame.maxWidth)
            photo.frame = frame
        }
        freeItems[index] = .photo(photo)
    }

    /// Removes free text or a free photo.
    public mutating func removeFreeItem(_ id: UUID) {
        freeItems.removeAll { $0.id == id }
    }

    /// Moves free text or a free photo `steps` places toward the front (positive) or the back (negative).
    public mutating func arrangeFreeItem(_ id: UUID, by steps: Int) {
        guard let index = freeItems.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(index + steps, 0), freeItems.count - 1)
        guard target != index else { return }
        freeItems.insert(freeItems.remove(at: index), at: target)
    }

    /// Moves free items whose middle left `canvas` back to its edge, so none gets lost
    /// when a panorama gets shorter or the format narrower.
    public mutating func keepFreeItems(in canvas: CGRect) {
        for index in freeItems.indices {
            let center = freeItems[index].center
            let x = min(max(center.x, canvas.minX), canvas.maxX)
            let y = min(max(center.y, canvas.minY), canvas.maxY)
            if x != center.x || y != center.y { freeItems[index].move(dx: x - center.x, dy: y - center.y) }
        }
    }
}

extension Project {
    /// Keeps every slide's free items on its canvas, see `Slide.keepFreeItems(in:)`.
    public mutating func keepFreeItemsOnCanvas() {
        for index in slides.indices {
            let canvas = SlideLayout(slide: slides[index], format: format).canvas
            slides[index].keepFreeItems(in: canvas)
        }
    }
}
