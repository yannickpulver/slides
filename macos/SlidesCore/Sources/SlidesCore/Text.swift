import CoreGraphics
import CoreText
import Foundation

/// Free text on a slide, drawn over the photos.
///
/// Like Figma's text layers: with no `width` the box grows with the text (auto width),
/// with a `width` the text wraps inside it and the box grows downward.
public struct TextBox: Codable, Equatable, Sendable, Identifiable {
    public static let defaultFont = "HelveticaNeue-Medium"
    public static let sizeRange = 4.0...600.0

    public var id = UUID()
    public var text: String
    /// Top-left corner in 1x pixels on the slide's canvas (a panorama's whole width).
    public var x: Double
    public var y: Double
    /// Fixed width that wraps the text; `nil` grows with the text.
    public var width: Double?
    /// PostScript name, e.g. `HelveticaNeue-Bold`.
    public var font = TextBox.defaultFont
    /// Font size in 1x pixels.
    public var size = 64.0
    public var color: RGB = .black
    public var alignment: TextAlignment = .left
    /// Line height in percent of the font size; `nil` is the font's own.
    public var lineHeight: Double?
    /// Letter spacing in percent of the font size, like Figma.
    public var letterSpacing = 0.0

    public init(text: String, x: Double, y: Double, width: Double? = nil) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
    }

    enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, font, size, color, alignment, lineHeight, letterSpacing
    }

    /// Missing values fall back to the defaults, so later additions keep older projects readable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decodeIfPresent(Double.self, forKey: .width)
        font = (try? c.decodeIfPresent(String.self, forKey: .font)) ?? Self.defaultFont
        size = (try? c.decodeIfPresent(Double.self, forKey: .size)) ?? 64
        color = (try? c.decodeIfPresent(RGB.self, forKey: .color)) ?? .black
        alignment = (try? c.decodeIfPresent(TextAlignment.self, forKey: .alignment)) ?? .left
        lineHeight = try? c.decodeIfPresent(Double.self, forKey: .lineHeight)
        letterSpacing = (try? c.decodeIfPresent(Double.self, forKey: .letterSpacing)) ?? 0
    }
}

public enum TextAlignment: String, Codable, CaseIterable, Sendable {
    case left, center, right
}

/// Measures and draws text boxes with CoreText, the same way in the editor and the export.
///
/// Lines are placed like in Figma: each line is exactly the line height tall, glyphs centered in it.
public enum TextRenderer {
    /// The box on the canvas in 1x pixels: its width (fixed or the text's), its height from the lines.
    public static func rect(of box: TextBox) -> CGRect {
        CGRect(origin: CGPoint(x: box.x, y: box.y), size: size(of: box))
    }

    public static func size(of box: TextBox) -> CGSize {
        let layout = Layout(box)
        return CGSize(width: box.width ?? ceil(layout.widest), height: ceil(layout.height))
    }

    /// Draws into a context in 1x canvas units with y pointing down.
    public static func draw(_ box: TextBox, in context: CGContext) {
        let layout = Layout(box)
        let width = box.width ?? ceil(layout.widest)
        context.saveGState()
        context.textMatrix = .identity
        for (index, line) in layout.lines.enumerated() {
            let free = width - line.width
            let offset = switch box.alignment {
            case .left: 0.0
            case .center: free / 2
            case .right: free
            }
            context.saveGState()
            // CoreText draws y-up: flip around the baseline.
            context.translateBy(x: box.x + offset, y: box.y + layout.baseline(of: index))
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(line.line, context)
            context.restoreGState()
        }
        context.restoreGState()
    }

    /// Font metrics a text box uses, for an editor that has to line up with the drawing.
    public static func metrics(_ box: TextBox) -> (lineHeight: Double, ascent: Double, descent: Double) {
        let layout = Layout(box)
        return (layout.lineHeight, layout.ascent, layout.descent)
    }

    public static func attributedString(_ box: TextBox) -> NSAttributedString {
        NSAttributedString(string: box.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font(box),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): box.color.cgColor,
            NSAttributedString.Key(kCTKernAttributeName as String): box.letterSpacing / 100 * box.size,
        ])
    }

    static func font(_ box: TextBox) -> CTFont {
        CTFontCreateWithName(box.font as CFString, box.size, nil)
    }

    /// Lines broken at the box width (or only at newlines for auto width).
    private struct Layout {
        struct Line {
            let line: CTLine
            /// Without trailing spaces.
            let width: Double
        }

        var lines: [Line] = []
        let ascent: Double
        let descent: Double
        let lineHeight: Double

        init(_ box: TextBox) {
            let font = TextRenderer.font(box)
            ascent = CTFontGetAscent(font)
            descent = CTFontGetDescent(font)
            lineHeight = box.lineHeight.map { $0 / 100 * box.size } ?? (ascent + descent + CTFontGetLeading(font))

            let string = TextRenderer.attributedString(box)
            let typesetter = CTTypesetterCreateWithAttributedString(string)
            let length = string.length
            var start = 0
            while start < length {
                let count = max(CTTypesetterSuggestLineBreak(typesetter, start, box.width ?? .greatestFiniteMagnitude), 1)
                let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
                let width = CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line)
                lines.append(Line(line: line, width: max(width, 0)))
                start += count
            }
            // An empty box, or a newline at the end, still gets a line to type in.
            if box.text.isEmpty || box.text.hasSuffix("\n") {
                lines.append(Line(line: CTLineCreateWithAttributedString(NSAttributedString(string: "")), width: 0))
            }
        }

        var widest: Double { lines.map(\.width).max() ?? 0 }
        var height: Double { Double(lines.count) * lineHeight }

        /// Baseline of line `index` from the box top: glyphs centered in the line height.
        func baseline(of index: Int) -> Double {
            Double(index) * lineHeight + (lineHeight - ascent - descent) / 2 + ascent
        }
    }
}

extension TextBox {
    init(copying box: TextBox, text: String) {
        self = box
        self.text = text
    }
}

extension Slide {
    /// Adds a text box and returns its id.
    @discardableResult
    public mutating func addText(_ box: TextBox) -> TextBox.ID {
        texts.append(box)
        return box.id
    }

    public mutating func updateText(_ id: TextBox.ID, _ change: (inout TextBox) -> Void) {
        guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
        change(&texts[index])
    }

    public mutating func removeText(_ id: TextBox.ID) {
        texts.removeAll { $0.id == id }
    }
}
