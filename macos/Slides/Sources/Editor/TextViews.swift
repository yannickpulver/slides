import AppKit
import SlidesCore
import SwiftUI

/// Draws a slide's free text and free photos back to front with the export's code, so the screen matches the files.
struct FreeItemsDrawing: View {
    let items: [FreeItem]
    let scale: Double
    /// The box being edited, drawn by its text field instead.
    var hiddenText: TextBox.ID?
    let mediaURL: (String) -> URL

    var body: some View {
        // Read the photos here, not in the canvas, so the view redraws when a decode lands.
        let images = Dictionary(items.compactMap { item -> (String, CGImage)? in
            guard case .photo(let photo) = item, let image = MediaCache.shared.image(for: mediaURL(photo.file)) else { return nil }
            return (photo.file, image)
        }, uniquingKeysWith: { first, _ in first })
        Canvas { context, _ in
            context.withCGContext { cg in
                cg.interpolationQuality = .high
                cg.scaleBy(x: scale, y: scale)
                for item in items {
                    switch item {
                    case .text(let box): if box.id != hiddenText { TextRenderer.draw(box, in: cg) }
                    case .photo(let photo): photo.draw(images[photo.file], in: cg)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Select, move, resize and edit free text and free photos, and place new text with the text tool. Works like Figma:
/// click selects, drag moves (snapping to the centers), handles resize, a double-click edits text.
/// Hit areas follow the back-to-front order, so the front item takes the click.
struct FreeItemsOverlay: View {
    let editor: EditorModel
    let slide: Slide
    let layout: SlideLayout
    let scale: Double

    @State var dragStart: CGPoint?
    @State var guides: [Guide] = []
    @State private var newBox: CGRect?
    /// The text box a drag moves: the clicked one, or its copy on ⌥-drag.
    @State private var dragID: TextBox.ID?
    /// The photo as it was when a drag, resize or turn started.
    @State var photoStart: FreePhoto?

    static let space = "freeItems"

    var body: some View {
        ZStack(alignment: .topLeading) {
            if editor.placingText {
                placement
            }
            ForEach(slide.freeItems) { item in
                switch item {
                case .text(let box):
                    if box.id == editor.editingTextID {
                        editing(box)
                    } else {
                        frame(box)
                    }
                case .photo(let photo):
                    photoFrame(photo)
                }
            }
            ForEach(guides, id: \.self) { guide in
                guideLine(guide)
            }
            if let newBox {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 1)
                    .placed(at: newBox)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.canvas.width * scale, height: layout.canvas.height * scale, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
    }

    // MARK: - Text tool

    /// Click places an auto-width box, drag draws a fixed-width one.
    private var placement: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard abs(value.translation.width) > 4 else { return newBox = nil }
                        newBox = CGRect(
                            x: min(value.startLocation.x, value.location.x),
                            y: value.startLocation.y,
                            width: abs(value.translation.width),
                            height: TextRenderer.size(of: TextBox(text: "", x: 0, y: 0)).height * scale
                        )
                    }
                    .onEnded { value in
                        let start = value.startLocation
                        if let rect = newBox {
                            editor.addText(at: CGPoint(x: (rect.minX / scale).rounded(), y: (start.y / scale).rounded()), width: (rect.width / scale).rounded())
                        } else {
                            editor.addText(at: CGPoint(x: (start.x / scale).rounded(), y: (start.y / scale).rounded()))
                        }
                        newBox = nil
                    }
            )
            .pointerStyle(.horizontalText)
    }

    // MARK: - Frame

    @ViewBuilder
    private func frame(_ box: TextBox) -> some View {
        let rect = TextRenderer.rect(of: box).scaled(scale)
        let selected = editor.selectedTextID == box.id
        HoverFrame(selected: selected)
            .placed(at: rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            editor.selectText(box.id)
                            dragStart = CGPoint(x: box.x, y: box.y)
                        }
                        guard let start = dragStart, hypot(value.translation.width, value.translation.height) > 2 else { return }
                        // ⌥-drag leaves the box in place and drags a copy, like in Figma.
                        let id = dragID ?? (NSEvent.modifierFlags.contains(.option) ? editor.insertCopy(of: box, key: "move") : box.id)
                        dragID = id
                        let moved = snapped(TextRenderer.size(of: box), to: CGPoint(
                            x: (start.x + value.translation.width / scale).rounded(),
                            y: (start.y + value.translation.height / scale).rounded()
                        ))
                        editor.updateText(id, "move") { $0.x = moved.x; $0.y = moved.y }
                    }
                    .onEnded { _ in
                        dragStart = nil
                        dragID = nil
                        guides = []
                    }
            )
            .simultaneousGesture(TapGesture(count: 2).onEnded { editor.editText(box.id) })
            .contextMenu { arrangeMenu(box.id) { editor.removeText(box.id) } }
        if selected {
            WidthHandle(rect: rect, edge: .leading) { dx in
                resize(box, leading: dx)
            } onEnd: {
                dragStart = nil
            }
            WidthHandle(rect: rect, edge: .trailing) { dx in
                resize(box, trailing: dx)
            } onEnd: {
                dragStart = nil
            }
        }
    }

    /// Dragging a side handle fixes the width, so the text wraps.
    private func resize(_ box: TextBox, leading dx: Double = 0, trailing: Double = 0) {
        let start = dragStart ?? CGPoint(x: box.x, y: box.width ?? TextRenderer.size(of: box).width)
        if dragStart == nil { dragStart = start }
        let width = max(start.y - dx / scale + trailing / scale, 8).rounded()
        let x = start.x + (start.y - width) * (dx != 0 ? 1 : 0)
        editor.updateText(box.id, "width") { $0.width = width; $0.x = x }
    }

    // MARK: - Editing

    @ViewBuilder
    private func editing(_ box: TextBox) -> some View {
        let rect = TextRenderer.rect(of: box).scaled(scale)
        InlineTextEditor(box: box, scale: scale) { text in
            editor.updateText(box.id, "text") { $0.text = text }
        } onEnd: {
            editor.endTextEditing()
        }
        .placed(at: rect)
        Rectangle()
            .strokeBorder(Color.accentColor, lineWidth: 1)
            .placed(at: rect)
            .allowsHitTesting(false)
    }

    // MARK: - Snapping

    struct Guide: Hashable {
        let vertical: Bool
        /// In 1x canvas pixels.
        let position: Double
    }

    /// Snaps the center of a box of `size` with its top-left at `point` to the frame centers
    /// (each panorama part and the whole canvas), and shows a guide where it snapped.
    func snapped(_ size: CGSize, to point: CGPoint) -> CGPoint {
        let threshold = 6 / scale
        var result = point
        var found: [Guide] = []
        let xs = (0..<slide.span).map { layout.part($0).midX } + (slide.span > 1 ? [layout.canvas.midX] : [])
        if let x = xs.min(by: { abs($0 - (point.x + size.width / 2)) < abs($1 - (point.x + size.width / 2)) }),
           abs(x - (point.x + size.width / 2)) < threshold {
            result.x = x - size.width / 2
            found.append(Guide(vertical: true, position: x))
        }
        let y = layout.canvas.midY
        if abs(y - (point.y + size.height / 2)) < threshold {
            result.y = y - size.height / 2
            found.append(Guide(vertical: false, position: y))
        }
        if found != guides { guides = found }
        return result
    }

    private func guideLine(_ guide: Guide) -> some View {
        Path { path in
            if guide.vertical {
                path.move(to: CGPoint(x: guide.position * scale, y: 0))
                path.addLine(to: CGPoint(x: guide.position * scale, y: layout.canvas.height * scale))
            } else {
                path.move(to: CGPoint(x: 0, y: guide.position * scale))
                path.addLine(to: CGPoint(x: layout.canvas.width * scale, y: guide.position * scale))
            }
        }
        .stroke(Color(red: 0.95, green: 0.28, blue: 0.13), lineWidth: 1)
        .allowsHitTesting(false)
    }
}

/// Invisible hit area of free text or a free photo: outlined on hover and when selected.
struct HoverFrame: View {
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(.clear)
            .strokeBorder(Color.accentColor.opacity(selected || hovering ? 1 : 0), lineWidth: selected ? 1.5 : 1)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

/// White square on the middle of a side; dragging it sets the box width.
private struct WidthHandle: View {
    let rect: CGRect
    let edge: HorizontalEdge
    let onDrag: (Double) -> Void
    let onEnd: () -> Void

    var body: some View {
        Rectangle()
            .fill(.white)
            .strokeBorder(Color.accentColor, lineWidth: 1.5)
            .frame(width: 8, height: 8)
            .padding(6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { onDrag($0.translation.width) }
                    .onEnded { _ in onEnd() }
            )
            .pointerStyle(.frameResize(position: edge == .leading ? .leading : .trailing))
            .offset(x: (edge == .leading ? rect.minX : rect.maxX) - 10, y: rect.midY - 10)
    }
}

/// Text field over a text box while editing. It lines up with the drawn text: same font,
/// line height and spacing, glyphs centered in each line.
struct InlineTextEditor: NSViewRepresentable {
    let box: TextBox
    let scale: Double
    let onChange: (String) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView(frame: .zero)
        view.drawsBackground = false
        view.isRichText = false
        view.allowsUndo = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = false
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.focusRingType = .none
        view.delegate = context.coordinator
        view.string = box.text
        context.coordinator.apply(box, scale: scale, to: view)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
            view.selectAll(nil)
        }
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.parent = self
        if view.string != box.text { view.string = box.text }
        context.coordinator.apply(box, scale: scale, to: view)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineTextEditor

        init(parent: InlineTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            // Size the field for the new text right away, so it doesn't wrap before the model catches up.
            var box = parent.box
            box.text = view.string
            apply(box, scale: parent.scale, to: view)
            parent.onChange(view.string)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // Esc arrives as `complete:` in a text view.
            if selector == #selector(NSResponder.cancelOperation(_:)) || selector == #selector(NSResponder.complete(_:)) {
                parent.onEnd()
                return true
            }
            return false
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEnd()
        }

        func apply(_ box: TextBox, scale: Double, to view: NSTextView) {
            let size = TextRenderer.size(of: box)
            let metrics = TextRenderer.metrics(box)
            let font = NSFont(name: box.font, size: box.size * scale) ?? .systemFont(ofSize: box.size * scale)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = switch box.alignment {
            case .left: .left
            case .center: .center
            case .right: .right
            }
            paragraph.minimumLineHeight = metrics.lineHeight * scale
            paragraph.maximumLineHeight = metrics.lineHeight * scale
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(Color(box.color)),
                .kern: box.letterSpacing / 100 * box.size * scale,
                .paragraphStyle: paragraph,
                // TextKit puts the extra line height above the glyphs; center them like the renderer.
                .baselineOffset: (metrics.lineHeight - metrics.ascent - metrics.descent) / 2 * scale,
            ]
            view.typingAttributes = attributes
            view.insertionPointColor = NSColor(Color(box.color))
            if let storage = view.textStorage, storage.length > 0 {
                storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
            }
            // Auto width: the widest line plus a hair, so rounding never wraps it.
            let width = (box.width ?? size.width + 2) * scale
            view.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        }
    }
}
