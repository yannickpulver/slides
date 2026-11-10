import SlidesCore
import SwiftUI

/// All slides in one row. The selected slide is editable and scrolled to the center.
struct SlideRow: View {
    let editor: EditorModel
    let onBackgroundTap: () -> Void

    private let padding = 40.0
    private let spacing = 20.0

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height - padding * 2, 160)
            let frameWidth = height * editor.project.format.width / editor.project.format.height
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(editor.project.slides) { slide in
                            // A selected panorama shrinks to fit the window, so all of it stays editable.
                            let fits = slide.id == editor.selectedSlideID
                                ? min(1, (geometry.size.width - padding * 2) / (frameWidth * Double(slide.span)))
                                : 1
                            item(slide, width: frameWidth * Double(slide.span) * fits, height: height * fits)
                                .frame(height: height)
                                .id(slide.id)
                        }
                    }
                    .padding(padding)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBackgroundTap)
                }
                .onChange(of: editor.selectedSlideID, initial: true) { _, id in
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: editor.project.slides.count) { _, _ in
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(editor.selectedSlideID, anchor: .center) }
                }
            }
        }
        .background(Theme.canvas)
    }

    @ViewBuilder
    private func item(_ slide: Slide, width: Double, height: Double) -> some View {
        let selected = slide.id == editor.selectedSlideID
        SlideView(
            slide: slide,
            format: editor.project.format,
            editor: selected ? editor : nil,
            mediaURL: editor.mediaURL
        )
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(selected ? 0.6 : 0.35), radius: selected ? 16 : 8)
        .opacity(selected ? 1 : 0.55)
        .overlay {
            if !selected {
                // Neighbours only select; a drop on them still lands there.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { editor.select(slide.id) }
                    .dropDestination(for: URL.self) { urls, _ in
                        editor.drop(urls, slot: nil, in: slide.id)
                        editor.select(slide.id)
                        return true
                    }
            }
        }
    }
}
