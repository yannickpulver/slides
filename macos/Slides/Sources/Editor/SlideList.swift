import SlidesCore
import SwiftUI

/// Slides in order. Drag to reorder, drop files on a slide to add them there.
struct SlideList: View {
    let editor: EditorModel

    var body: some View {
        List(selection: Binding(get: { editor.selectedSlideID }, set: { if let id = $0 { editor.select(id) } })) {
            ForEach(Array(editor.project.slides.enumerated()), id: \.element.id) { index, slide in
                SlideListRow(editor: editor, slide: slide, number: index + 1)
                    .tag(slide.id)
                    .contextMenu {
                        Button("Add Slide After") {
                            editor.select(slide.id)
                            editor.addSlide()
                        }
                        Divider()
                        Button("Delete Slide", role: .destructive) { editor.removeSlide(slide.id) }
                            .disabled(editor.project.slides.count < 2)
                    }
            }
            .onMove { source, destination in
                if let index = source.first { editor.moveSlide(editor.project.slides[index].id, to: destination) }
            }
        }
        .onDeleteCommand {
            if editor.project.slides.count > 1 { editor.removeSlide(editor.selectedSlideID) }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: editor.addSlide) {
                Label { Text("Add Slide") } icon: { TablerIcon("plus", size: 14) }
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(10)
        }
    }
}

private struct SlideListRow: View {
    let editor: EditorModel
    let slide: Slide
    let number: Int

    @State private var targeted = false

    var body: some View {
        let format = editor.project.format
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            SlideView(slide: slide, format: format, editor: nil, mediaURL: editor.mediaURL)
                .aspectRatio(format.width * Double(slide.span) / format.height, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator, lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.accentColor, lineWidth: targeted ? 2 : 0))
                .frame(maxWidth: .infinity, maxHeight: slide.isPanorama ? nil : 140, alignment: .leading)
        }
        .padding(.vertical, 4)
        .dropDestination(for: URL.self) { urls, _ in
            editor.drop(urls, slot: nil, in: slide.id)
            editor.select(slide.id)
            return true
        } isTargeted: { targeted = $0 }
    }
}
