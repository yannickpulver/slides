import SlidesCore
import SwiftUI

/// Thumbnails of all slides. Drag a thumbnail onto another to move it before that one.
struct Filmstrip: View {
    let editor: EditorModel

    private let height = 56.0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(editor.project.slides.enumerated()), id: \.element.id) { index, slide in
                        Thumb(editor: editor, slide: slide, index: index, height: height)
                            .id(slide.id)
                    }
                    addButton
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: editor.selectedSlideID) { _, id in
                withAnimation { proxy.scrollTo(id) }
            }
        }
        .frame(height: height + 24)
        .background(Theme.background)
    }

    private var addButton: some View {
        Button(action: editor.addSlide) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.textMuted)
                .frame(width: height * 0.75, height: height)
                .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.outline, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add slide")
        // Dropping a thumbnail here moves it to the end.
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            editor.moveSlide(id, to: editor.project.slides.count)
            return true
        }
    }
}

private struct Thumb: View {
    let editor: EditorModel
    let slide: Slide
    let index: Int
    let height: Double

    @State private var hovering = false
    @State private var targeted = false

    var body: some View {
        let format = editor.project.format
        let selected = slide.id == editor.selectedSlideID
        SlideView(slide: slide, format: format, editor: nil, mediaURL: editor.mediaURL)
            .frame(width: height * format.width / format.height * Double(slide.span), height: height)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Theme.text : .clear, lineWidth: 1.5))
            .overlay(alignment: .leading) {
                if targeted { Rectangle().fill(Color.accentColor).frame(width: 3).offset(x: -5) }
            }
            .overlay(alignment: .topTrailing) {
                if hovering, editor.project.slides.count > 1 {
                    Button { editor.removeSlide(slide.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(.black.opacity(0.7), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 3, y: -3)
                    .help("Remove slide")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editor.select(slide.id) }
            .onHover { hovering = $0 }
            .draggable(slide.id.uuidString) {
                SlideView(slide: slide, format: format, editor: nil, mediaURL: editor.mediaURL)
                    .frame(width: height * format.width / format.height * Double(slide.span), height: height)
            }
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
                editor.moveSlide(id, to: index)
                return true
            } isTargeted: { targeted = $0 }
    }
}
