import SlidesCore
import SwiftUI

/// Draws one slide with the same geometry as the export.
///
/// `editor` makes it interactive: drops, file pickers, pan and zoom, video playback.
/// Without it (filmstrip, start screen, neighbours) it only draws.
struct SlideView: View {
    let slide: Slide
    let format: Format
    var editor: EditorModel?
    let mediaURL: (String) -> URL

    var body: some View {
        GeometryReader { geometry in
            let layout = SlideLayout(slide: slide, format: format)
            let scale = geometry.size.width / layout.canvas.width
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(slide.style.color))
                if let file = slide.style.backgroundImage {
                    BackgroundImage(url: mediaURL(file), layout: layout, scale: scale)
                }
                ForEach(slide.slots.indices, id: \.self) { index in
                    SlotView(
                        slide: slide,
                        index: index,
                        layout: layout,
                        scale: scale,
                        editor: editor,
                        mediaURL: mediaURL
                    )
                    // Drawn only (filmstrip, start screen): clicks go to the view around it.
                    .allowsHitTesting(editor != nil)
                }
                if let edge = slide.style.filmEdge {
                    FilmEdgeImage(edge: edge, rect: layout.filmEdgeRect(mediaSizes: mediaSizes).scaled(scale), frameHeight: layout.format.height * scale)
                }
                TextDrawing(texts: slide.texts, scale: scale, hidden: editor?.editingTextID)
                if editor != nil, slide.isPanorama {
                    PanoramaCuts(layout: layout, scale: scale)
                }
                if let editor {
                    TextOverlay(editor: editor, slide: slide, layout: layout, scale: scale)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                // A click next to the text ends editing and drops the selection, like in Figma.
                guard let editor, editor.selectedTextID != nil else { return }
                let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                if !slide.texts.contains(where: { TextRenderer.rect(of: $0).insetBy(dx: -6 / scale, dy: -6 / scale).contains(point) }) {
                    editor.selectText(nil)
                }
            }, isEnabled: editor != nil)
        }
    }

    /// Pixel sizes of the loaded photos by slot, for the film edge.
    private var mediaSizes: [Int: CGSize] {
        var sizes: [Int: CGSize] = [:]
        for (index, media) in slide.slots.enumerated() {
            if let media, let image = MediaCache.shared.image(for: mediaURL(media.file)) {
                sizes[index] = CGSize(width: image.width, height: image.height)
            }
        }
        return sizes
    }
}

extension View {
    /// Places a view at `rect` inside a top-leading `ZStack`.
    func placed(at rect: CGRect) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
    }
}

extension CGRect {
    func scaled(_ factor: Double) -> CGRect {
        CGRect(x: minX * factor, y: minY * factor, width: width * factor, height: height * factor)
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

private struct BackgroundImage: View {
    let url: URL
    let layout: SlideLayout
    let scale: Double

    var body: some View {
        if let image = MediaCache.shared.image(for: url) {
            let rect = layout.backgroundRect(imageSize: CGSize(width: image.width, height: image.height)).scaled(scale)
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .placed(at: rect)
            }
            .frame(width: layout.canvas.width * scale, height: layout.canvas.height * scale, alignment: .topLeading)
            .blur(radius: layout.slide.style.blur * scale, opaque: true)
            .clipped()
            .allowsHitTesting(false)
        }
    }
}

/// Dashed lines where a panorama gets cut into frames.
private struct PanoramaCuts: View {
    let layout: SlideLayout
    let scale: Double

    var body: some View {
        Path { path in
            for part in 1..<layout.slide.span {
                let x = layout.part(part).minX * scale
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: layout.canvas.height * scale))
            }
        }
        .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .shadow(color: .black.opacity(0.4), radius: 1)
        .allowsHitTesting(false)
    }
}
