import Foundation

/// A carousel: an ordered list of slides in one format.
public struct Project: Codable, Equatable, Sendable, Identifiable {
    public var version = 1
    public var id = UUID()
    public var name: String
    public var format: Format = .portrait4x3
    public var slides: [Slide] = [Slide()]

    public init(name: String) {
        self.name = name
    }

    /// Exported frames over all slides: a panorama of 3 counts as 3.
    public var frameCount: Int { slides.reduce(0) { $0 + $1.span } }
}

/// Size of one frame at 1x. Exports run at 2x or more: 2x of 4:3 is 1536 × 2048,
/// the largest photo Instagram keeps.
public enum Format: String, Codable, CaseIterable, Sendable {
    case portrait4x3
    case portrait16x9

    public var width: Double {
        switch self {
        case .portrait4x3: 768
        case .portrait16x9: 576
        }
    }

    public var height: Double { 1024 }

    public var label: String {
        switch self {
        case .portrait4x3: "4:3"
        case .portrait16x9: "16:9"
        }
    }
}

/// How many photos a slide stacks vertically.
public enum Layout: Int, Codable, CaseIterable, Sendable {
    case single = 1
    case two = 2
    case three = 3

    public var slotCount: Int { rawValue }
}

public struct Slide: Codable, Equatable, Sendable, Identifiable {
    public static let maxSpan = 5

    public var id = UUID()
    public var layout: Layout = .single
    /// Frames this slide covers. 2...5 makes a panorama; only with `.single`.
    public var span = 1
    /// One entry per slot of `layout`; `nil` is an empty slot.
    public var slots: [Media?] = [nil]
    public var style = SlideStyle()
    /// Set once the layout is picked by hand. Until then, drops grow the layout.
    public var layoutChosen = false
    /// Text over the photos, back to front.
    public var texts: [TextBox] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case id, layout, span, slots, style, layoutChosen, texts
    }

    /// Projects from before text have no `texts`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        layout = try c.decode(Layout.self, forKey: .layout)
        span = try c.decode(Int.self, forKey: .span)
        slots = try c.decode([Media?].self, forKey: .slots)
        style = try c.decode(SlideStyle.self, forKey: .style)
        layoutChosen = try c.decodeIfPresent(Bool.self, forKey: .layoutChosen) ?? false
        texts = try c.decodeIfPresent([TextBox].self, forKey: .texts) ?? []
    }

    public var isPanorama: Bool { span > 1 }
    public var mediaCount: Int { slots.compactMap(\.self).count }
    public var hasVideo: Bool { slots.contains { $0?.kind == .video } }
}

public struct Media: Codable, Equatable, Sendable {
    /// File name inside the project's `media/` folder.
    public var file: String
    public var kind: Kind
    public var crop = Crop()

    public init(file: String, kind: Kind, crop: Crop = Crop()) {
        self.file = file
        self.kind = kind
        self.crop = crop
    }

    public enum Kind: String, Codable, Sendable {
        case image
        case video
    }
}

/// Pan and zoom of a photo in fill mode.
public struct Crop: Codable, Equatable, Sendable {
    public static let maxZoom = 5.0

    /// Shift of the photo center, as a share of the visible slot area (-0.5...0.5 typical).
    public var x = 0.0
    public var y = 0.0
    /// 1 = photo just covers the slot.
    public var zoom = 1.0

    public init(x: Double = 0, y: Double = 0, zoom: Double = 1) {
        self.x = x
        self.y = y
        self.zoom = zoom
    }
}

public enum Fit: String, Codable, Sendable {
    /// Photo covers the slot and can be panned and zoomed.
    case fill
    /// Whole photo visible.
    case full
}

public struct SlideStyle: Codable, Equatable, Sendable {
    public static let maxBorder = 170.0
    public static let maxGap = 85.0
    public static let maxBlur = 70.0

    public var fit: Fit = .fill
    /// Inset around each photo, in 1x pixels.
    public var border = 0.0
    /// Space between stacked photos, in 1x pixels.
    public var gap = 0.0
    public var color: RGB = .white
    /// File name inside `media/`.
    public var backgroundImage: String?
    /// Blur radius of the background image, in 1x pixels.
    public var blur = 0.0
    public var filmEdge: FilmEdge?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case fit, border, gap, color, backgroundImage, blur, filmEdge
    }

    /// Missing or unknown values fall back to the defaults, so an older project still opens.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fit = (try? c.decodeIfPresent(Fit.self, forKey: .fit)) ?? .fill
        border = (try? c.decodeIfPresent(Double.self, forKey: .border)) ?? 0
        gap = (try? c.decodeIfPresent(Double.self, forKey: .gap)) ?? 0
        color = (try? c.decodeIfPresent(RGB.self, forKey: .color)) ?? .white
        backgroundImage = try? c.decodeIfPresent(String.self, forKey: .backgroundImage)
        blur = (try? c.decodeIfPresent(Double.self, forKey: .blur)) ?? 0
        filmEdge = try? c.decodeIfPresent(FilmEdge.self, forKey: .filmEdge)
    }
}

public struct RGB: Codable, Equatable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let white = RGB(r: 1, g: 1, b: 1)
    public static let black = RGB(r: 0, g: 0, b: 0)
}

/// Thin film-gate edge around the visible photos (from the "Film mask/thin" set in Figma).
///
/// The mask is drawn in nine pieces: corners and edge thickness keep the size they have
/// on one frame, only the edges grow. So a panorama gets the same edge as a single frame.
public enum FilmEdge: String, Codable, CaseIterable, Sendable {
    case gateWhite = "gate_white"
    case gateBlack = "gate_black"

    public var name: String {
        switch self {
        case .gateWhite: "White"
        case .gateBlack: "Black"
        }
    }

    /// Bundled portrait mask for one 4:3 frame. `preview` is a 1024 px copy for the editor.
    public func url(preview: Bool) -> URL? {
        Bundle.module.url(
            forResource: "\(rawValue)_portrait",
            withExtension: "png",
            subdirectory: "FilmEdges/\(preview ? "preview" : "full")"
        )
    }

    /// Share of the mask height that holds a corner. The edge itself is about 1 %.
    static let cap = 0.05

    /// Pieces to draw the mask over `rect`: `source` in mask pixels (y down), `target` in `rect`'s units.
    ///
    /// `frameHeight` is one frame's height in `rect`'s units; it sets how thick corners and edges are.
    public static func pieces(maskSize: CGSize, in rect: CGRect, frameHeight: Double) -> [(source: CGRect, target: CGRect)] {
        let c = (maskSize.height * cap).rounded()
        guard rect.width > 0, rect.height > 0, maskSize.width > 2 * c, maskSize.height > 2 * c else { return [] }
        // Corners as on one frame, but never more than half the rect.
        let t = min(c * frameHeight / maskSize.height, rect.width / 2, rect.height / 2)
        let mw = maskSize.width, mh = maskSize.height
        let sx = [0, c, mw - c, mw]
        let sy = [0, c, mh - c, mh]
        let tx = [rect.minX, rect.minX + t, rect.maxX - t, rect.maxX]
        let ty = [rect.minY, rect.minY + t, rect.maxY - t, rect.maxY]
        var result: [(CGRect, CGRect)] = []
        for row in 0..<3 {
            for column in 0..<3 where !(row == 1 && column == 1) {
                let source = CGRect(x: sx[column], y: sy[row], width: sx[column + 1] - sx[column], height: sy[row + 1] - sy[row])
                let target = CGRect(x: tx[column], y: ty[row], width: tx[column + 1] - tx[column], height: ty[row + 1] - ty[row])
                if target.width > 0, target.height > 0 { result.append((source, target)) }
            }
        }
        return result
    }
}
