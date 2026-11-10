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

/// Size of one exported frame, in pixels at 1x.
public enum Format: String, Codable, CaseIterable, Sendable {
    case portrait4x3
    case portrait16x9

    public var width: Double { 1080 }
    public var height: Double {
        switch self {
        case .portrait4x3: 1440
        case .portrait16x9: 1920
        }
    }

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

    public init() {}

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
    public static let maxBorder = 240.0
    public static let maxGap = 120.0
    public static let maxBlur = 100.0

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

/// Film-edge overlays stretched over the visible photo.
public enum FilmEdge: String, Codable, CaseIterable, Sendable {
    case whiteThin1 = "white_thin_1"
    case whiteThin2 = "white_thin_2"
    case whiteThin3 = "white_thin_3"
    case double1 = "double_1"
    case double2 = "double_2"
    case double3 = "double_3"
    case doubleInv1 = "double_inv_1"
    case doubleInv2 = "double_inv_2"
    case doubleInv3 = "double_inv_3"
    case whiteSoft = "white_soft"
    case blackSoft1 = "black_soft_1"
    case blackSoft2 = "black_soft_2"
    case blackSoft3 = "black_soft_3"

    /// Bundled PNG. `preview` is a quarter-size copy for the editor.
    public func url(landscape: Bool, preview: Bool) -> URL? {
        let name = "\(rawValue)_\(landscape ? "landscape" : "portrait")"
        return Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "FilmEdges/\(preview ? "preview" : "full")"
        )
    }
}
