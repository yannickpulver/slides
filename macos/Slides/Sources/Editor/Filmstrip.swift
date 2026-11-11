import SlidesCore
import SwiftUI

/// All slides in carousel order, below the canvas.
/// Drag a slide onto another to move it there; drop files on a slide to add them.
struct Filmstrip: View {
    let editor: EditorModel

    static let height = 72.0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(editor.project.slides.enumerated()), id: \.element.id) { index, slide in
                        FilmstripItem(editor: editor, slide: slide, index: index)
                            .id(slide.id)
                    }
                    addButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
            .onChange(of: editor.selectedSlideID) { _, id in
                withAnimation { proxy.scrollTo(id) }
            }
        }
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var addButton: some View {
        Button(action: editor.addSlide) {
            TablerIcon("plus", size: 18)
                .foregroundStyle(.secondary)
                .frame(width: Self.height * 0.75, height: Self.height)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add slide (⌘N)")
        // Dropping a slide here moves it to the end.
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            editor.moveSlide(id, to: editor.project.slides.count)
            return true
        }
    }
}

private struct FilmstripItem: View {
    let editor: EditorModel
    let slide: Slide
    let index: Int

    @State private var slideTargeted = false
    @State private var filesTargeted = false

    var body: some View {
        let format = editor.project.format
        let selected = slide.id == editor.selectedSlideID
        let size = CGSize(width: Filmstrip.height * format.width / format.height * Double(slide.span), height: Filmstrip.height)
        VStack(spacing: 4) {
            SlideView(slide: slide, format: format, editor: nil, mediaURL: editor.mediaURL)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator, lineWidth: 0.5))
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: selected || filesTargeted ? 2.5 : 0))
                // Where a dragged slide would land: before this one.
                .overlay(alignment: .leading) {
                    if slideTargeted {
                        Capsule().fill(Color.accentColor).frame(width: 3).offset(x: -7)
                    }
                }
            Text(slide.isPanorama ? "\(index + 1) · \(slide.span) parts" : "\(index + 1)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { editor.select(slide.id) }
        .contextMenu {
            Button("Add Slide After") {
                editor.select(slide.id)
                editor.addSlide()
            }
            Button("Duplicate Slide") { editor.duplicateSlide(slide.id) }
            Divider()
            Button("Delete Slide", role: .destructive) { editor.removeSlide(slide.id) }
                .disabled(editor.project.slides.count < 2)
        }
        .draggable(slide.id.uuidString) {
            SlideView(slide: slide, format: format, editor: nil, mediaURL: editor.mediaURL)
                .frame(width: size.width, height: size.height)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            editor.moveSlide(id, to: index)
            return true
        } isTargeted: { slideTargeted = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            editor.drop(urls, slot: nil, in: slide.id)
            editor.select(slide.id)
            return true
        } isTargeted: { filesTargeted = $0 }
        .help(slide.isPanorama ? "Slide \(index + 1), panorama over \(slide.span) slides" : "Slide \(index + 1)")
    }
}
