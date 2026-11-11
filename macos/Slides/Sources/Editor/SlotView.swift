import SlidesCore
import SwiftUI

/// One slot: the photo or video clipped to its visible area, or an empty drop target.
struct SlotView: View {
    let slide: Slide
    let index: Int
    let layout: SlideLayout
    let scale: Double
    let editor: EditorModel?
    let mediaURL: (String) -> URL

    @State private var hovering = false
    @State private var dropTargeted = false
    @State private var gestureStart: Crop?
    @State private var playing = false

    private var media: Media? { slide.slots[index] }
    private var slotRect: CGRect { layout.slots[index].scaled(scale) }
    private var visible: CGRect { layout.visibleArea(slot: index) }
    private var interactive: Bool { editor != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let media {
                filled(media)
            } else if interactive {
                empty
            }
            if dropTargeted {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: slotRect.width, height: slotRect.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .modifier(FileDrop(editor: editor, slot: index, slideID: slide.id, targeted: $dropTargeted))
        .offset(x: slotRect.minX, y: slotRect.minY)
    }

    // MARK: - Filled

    @ViewBuilder
    private func filled(_ media: Media) -> some View {
        let url = mediaURL(media.file)
        let image = MediaCache.shared.image(for: url)
        let size = image.map { CGSize(width: $0.width, height: $0.height) }
        // Visible area in slot-local points.
        let visibleRect = visible.scaled(scale).offsetBy(dx: -slotRect.minX, dy: -slotRect.minY)
        let origin = visible.scaled(scale).origin

        ZStack(alignment: .topLeading) {
            if let image, let size {
                let mediaRect = layout.mediaRect(slot: index, mediaSize: size, crop: media.crop).scaled(scale)
                    .offsetBy(dx: -origin.x, dy: -origin.y)
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .placed(at: mediaRect)
                if media.kind == .video, interactive {
                    VideoLayer(url: url, playing: playing)
                        .placed(at: mediaRect)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: visibleRect.width, height: visibleRect.height, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .modifier(CropGestures(
            enabled: interactive && slide.style.fit == .fill && size != nil,
            onChange: { update in
                guard let size else { return }
                let start = gestureStart ?? media.crop
                if gestureStart == nil { gestureStart = start }
                let crop = update(start, visibleRect.size)
                editor?.setCrop(SlideLayout.clampedCrop(crop, in: visible, mediaSize: size), slot: index, in: slide.id)
            },
            onEnd: { gestureStart = nil }
        ))
        .onTapGesture {
            if media.kind == .video { playing.toggle() }
        }
        .offset(x: visibleRect.minX, y: visibleRect.minY)

        if interactive, hovering || gestureStart != nil {
            if slide.style.fit == .fill, let size {
                CornerHandles(rect: visibleRect) { factor in
                    let start = gestureStart ?? media.crop
                    if gestureStart == nil { gestureStart = start }
                    var crop = start
                    crop.zoom = start.zoom * factor
                    editor?.setCrop(SlideLayout.clampedCrop(crop, in: visible, mediaSize: size), slot: index, in: slide.id)
                } onEnd: {
                    gestureStart = nil
                }
            }
            SlotButtons(
                isVideo: media.kind == .video,
                playing: playing,
                onPlay: { playing.toggle() },
                onReplace: pickFiles,
                onRemove: { editor?.removeMedia(slot: index, in: slide.id) }
            )
            .frame(width: slotRect.width, height: slotRect.height, alignment: .topTrailing)
        }
    }

    // MARK: - Empty

    private var empty: some View {
        ZStack {
            Rectangle().fill(slide.style.backgroundImage == nil ? Color(white: 0.96) : .clear)
            TablerIcon("photo-plus", size: max(min(slotRect.height * 0.1, 36), 14))
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(width: slotRect.width, height: slotRect.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: pickFiles)
        .pointerStyle(.link)
    }

    private func pickFiles() {
        guard let editor else { return }
        let urls = FilePanel.pickMedia()
        if !urls.isEmpty { editor.drop(urls, slot: index, in: slide.id) }
    }
}

/// Accepts files from Finder into a slot.
private struct FileDrop: ViewModifier {
    let editor: EditorModel?
    let slot: Int
    let slideID: Slide.ID
    @Binding var targeted: Bool

    func body(content: Content) -> some View {
        if let editor {
            content.dropDestination(for: URL.self) { urls, _ in
                editor.drop(urls, slot: slot, in: slideID)
                return true
            } isTargeted: { targeted = $0 }
        } else {
            content
        }
    }
}

/// Pan with a drag, zoom with a trackpad pinch.
private struct CropGestures: ViewModifier {
    let enabled: Bool
    /// Receives a function from the crop at gesture start and the visible size in points to the new crop.
    let onChange: ((Crop, CGSize) -> Crop) -> Void
    let onEnd: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            onChange { start, size in
                                var crop = start
                                crop.x = start.x + value.translation.width / max(size.width, 1)
                                crop.y = start.y + value.translation.height / max(size.height, 1)
                                return crop
                            }
                        }
                        .onEnded { _ in onEnd() }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            onChange { start, _ in
                                var crop = start
                                crop.zoom = start.zoom * value.magnification
                                return crop
                            }
                        }
                        .onEnded { _ in onEnd() }
                )
        } else {
            content
        }
    }
}

/// White L-brackets on the corners. Dragging outward zooms in.
private struct CornerHandles: View {
    let rect: CGRect
    let onZoom: (Double) -> Void
    let onEnd: () -> Void

    var body: some View {
        ForEach(Corner.allCases, id: \.self) { corner in
            Bracket(corner: corner)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: .black.opacity(0.35), radius: 1, x: 1, y: 1)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let outward = (value.translation.width * corner.signX + value.translation.height * corner.signY) / 2
                            onZoom(max(1 + outward / 200, 0.1))
                        }
                        .onEnded { _ in onEnd() }
                )
                .pointerStyle(.frameResize(position: corner.position))
                .offset(
                    x: corner.signX < 0 ? rect.minX + 6 : rect.maxX - 34,
                    y: corner.signY < 0 ? rect.minY + 6 : rect.maxY - 34
                )
        }
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var signX: Double { self == .topLeft || self == .bottomLeft ? -1 : 1 }
        var signY: Double { self == .topLeft || self == .topRight ? -1 : 1 }
        var position: FrameResizePosition {
            switch self {
            case .topLeft: .topLeading
            case .topRight: .topTrailing
            case .bottomLeft: .bottomLeading
            case .bottomRight: .bottomTrailing
            }
        }
    }

    struct Bracket: Shape {
        let corner: Corner

        func path(in rect: CGRect) -> Path {
            let arm = 18.0
            let x = corner.signX < 0 ? rect.minX + 2 : rect.maxX - 2
            let y = corner.signY < 0 ? rect.minY + 2 : rect.maxY - 2
            var path = Path()
            path.move(to: CGPoint(x: x - corner.signX * arm, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y - corner.signY * arm))
            return path
        }
    }
}

private struct SlotButtons: View {
    let isVideo: Bool
    let playing: Bool
    let onPlay: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isVideo {
                RoundButton(icon: playing ? "player-pause" : "player-play", help: playing ? "Pause" : "Play", action: onPlay)
            }
            RoundButton(icon: "refresh", help: "Replace", action: onReplace)
            RoundButton(icon: "x", help: "Remove", action: onRemove)
        }
        .padding(8)
    }
}

struct RoundButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TablerIcon(icon, size: 13)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.55), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .pointerStyle(.link)
    }
}

/// Film edge from the quarter-size preview set, stretched over the visible photo.
struct FilmEdgeImage: View {
    let edge: FilmEdge
    let rect: CGRect

    var body: some View {
        if let url = edge.url(landscape: rect.width > rect.height, preview: true),
           let image = MediaCache.shared.image(for: url) {
            Image(decorative: image, scale: 1)
                .resizable()
                .placed(at: rect)
                .allowsHitTesting(false)
        }
    }
}
