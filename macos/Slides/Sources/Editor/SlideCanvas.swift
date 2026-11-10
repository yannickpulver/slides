import SlidesCore
import SwiftUI

/// The selected slide, as large as the window allows. A panorama shows all its parts.
struct SlideCanvas: View {
    let editor: EditorModel

    var body: some View {
        GeometryReader { proxy in
            let slide = editor.currentSlide
            let format = editor.project.format
            let padding = 40.0
            let scale = max(0.05, min(
                (proxy.size.width - padding * 2) / (format.width * Double(slide.span)),
                (proxy.size.height - padding * 2) / format.height
            ))
            SlideView(slide: slide, format: format, editor: editor, mediaURL: editor.mediaURL)
                .frame(width: format.width * Double(slide.span) * scale, height: format.height * scale)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .id(slide.id)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            editor.drop(urls, slot: nil, in: editor.selectedSlideID)
            return true
        }
    }
}
