import SlidesCore
import SwiftUI

extension FreeItemsOverlay {
    /// Hit area of a free photo: click selects, drag moves (snapping to the centers), the corners
    /// resize it with its aspect ratio, two fingers on the trackpad turn it.
    @ViewBuilder
    func photoFrame(_ photo: FreePhoto) -> some View {
        let selected = editor.selectedPhotoID == photo.id
        HoverFrame(selected: selected)
            .placed(at: photo.outerRect.scaled(scale), angle: photo.angle)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let start = begin(photo)
                        guard hypot(value.translation.width, value.translation.height) > 2 else { return }
                        let outer = start.outerRect
                        let topLeft = snapped(outer.size, to: CGPoint(
                            x: outer.minX + value.translation.width / scale,
                            y: outer.minY + value.translation.height / scale
                        ))
                        let x = (topLeft.x + outer.width / 2).rounded()
                        let y = (topLeft.y + outer.height / 2).rounded()
                        editor.updatePhoto(photo.id, in: slide.id, "move") { $0.x = x; $0.y = y }
                    }
                    .onEnded { _ in end() }
            )
            .modifier(RotateGestures(enabled: true, onChange: { degrees in
                let start = begin(photo)
                let angle = Self.normalized(start.angle + degrees)
                editor.updatePhoto(photo.id, in: slide.id, "angle") { $0.angle = angle }
            }, onEnd: end))
            .contextMenu { arrangeMenu(photo.id) { editor.removePhoto(photo.id, in: slide.id) } }
        if selected {
            ForEach(Array(photo.corners.enumerated()), id: \.offset) { index, corner in
                CornerHandle(point: CGPoint(x: corner.x * scale, y: corner.y * scale), index: index) { value in
                    resize(photo, from: value.startLocation, to: value.location)
                } onEnd: {
                    end()
                }
            }
        }
    }

    /// Bring to front or back, and delete: for free text and free photos alike.
    @ViewBuilder
    func arrangeMenu(_ id: UUID, delete: @escaping () -> Void) -> some View {
        let count = slide.freeItems.count
        Button("Bring to Front") { editor.arrange(id, by: count, in: slide.id) }
        Button("Bring Forward") { editor.arrange(id, by: 1, in: slide.id) }
        Button("Send Backward") { editor.arrange(id, by: -1, in: slide.id) }
        Button("Send to Back") { editor.arrange(id, by: -count, in: slide.id) }
        Divider()
        Button("Delete", role: .destructive, action: delete)
    }

    /// Scales the photo by how far the corner moved from its center, so the opposite corner
    /// mirrors it and the aspect ratio stays.
    private func resize(_ photo: FreePhoto, from startLocation: CGPoint, to location: CGPoint) {
        let start = begin(photo)
        let center = CGPoint(x: start.x * scale, y: start.y * scale)
        let before = hypot(startLocation.x - center.x, startLocation.y - center.y)
        guard before > 1 else { return }
        let factor = hypot(location.x - center.x, location.y - center.y) / before
        let frame = start.frame?.width ?? 0
        let width = max(((start.width + 2 * frame) * factor - 2 * frame).rounded(), FreePhoto.minWidth)
        editor.updatePhoto(photo.id, in: slide.id, "resize") { $0.width = width }
    }

    /// Selects the photo and remembers how it was when the gesture started.
    private func begin(_ photo: FreePhoto) -> FreePhoto {
        if let photoStart { return photoStart }
        editor.selectPhoto(photo.id)
        photoStart = photo
        return photo
    }

    private func end() {
        photoStart = nil
        guides = []
    }

    /// An angle in -180...180, in 0.1° steps.
    static func normalized(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return (value * 10).rounded() / 10
    }
}

/// White square on a corner of the selected free photo; dragging it resizes the photo.
private struct CornerHandle: View {
    let point: CGPoint
    /// 0 top left, 1 top right, 2 bottom right, 3 bottom left.
    let index: Int
    let onDrag: (DragGesture.Value) -> Void
    let onEnd: () -> Void

    var body: some View {
        Rectangle()
            .fill(.white)
            .strokeBorder(Color.accentColor, lineWidth: 1.5)
            .frame(width: 8, height: 8)
            .padding(6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(FreeItemsOverlay.space))
                    .onChanged(onDrag)
                    .onEnded { _ in onEnd() }
            )
            .pointerStyle(.frameResize(position: [.topLeading, .topTrailing, .bottomTrailing, .bottomLeading][index]))
            .offset(x: point.x - 10, y: point.y - 10)
    }
}
