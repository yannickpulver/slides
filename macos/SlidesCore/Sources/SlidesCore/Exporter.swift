import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes every frame of a project into a folder: PNG for photo slides, MP4 for slides with video.
///
/// Files are named `slide01-<id>@2x.png` and dated one second apart (slide 1 oldest),
/// so apps that sort by date keep the carousel order.
public struct Exporter: Sendable {
    public let project: Project
    public let mediaURL: @Sendable (String) -> URL
    public let scale: Int

    public init(project: Project, scale: Int, mediaURL: @escaping @Sendable (String) -> URL) {
        self.project = project
        self.scale = scale
        self.mediaURL = mediaURL
    }

    /// File names in export order, one per frame.
    public func fileNames() -> [String] {
        let digits = String(project.frameCount).count
        let suffix = scale > 1 ? "@\(scale)x" : ""
        var names: [String] = []
        for slide in project.slides {
            let id = slide.id.uuidString.prefix(8).lowercased()
            let ext = slide.hasVideo ? "mp4" : "png"
            for part in 0..<slide.span {
                let number = String(names.count + 1).leftPadded(to: digits)
                let partSuffix = slide.isPanorama ? "-\(part + 1)" : ""
                names.append("slide\(number)-\(id)\(partSuffix)\(suffix).\(ext)")
            }
        }
        return names
    }

    @concurrent
    public func export(to folder: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> [URL] {
        let names = fileNames()
        let total = Double(max(names.count, 1))
        let now = Date()
        var written: [URL] = []

        for slide in project.slides {
            try Task.checkCancellation()
            let layout = SlideLayout(slide: slide, format: project.format)
            let images = await loadImages(for: slide)
            let background = slide.style.backgroundImage.flatMap { MediaLoader.image(at: mediaURL($0)) }

            for part in 0..<slide.span {
                let url = folder.appending(path: names[written.count])
                let done = Double(written.count)
                let renderer = SlideRenderer(layout: layout, scale: Double(scale), images: images, background: background)
                if slide.hasVideo {
                    try await VideoExporter(renderer: renderer, part: part, mediaURL: mediaURL).export(to: url) { fraction in
                        progress((done + fraction) / total)
                    }
                } else {
                    guard let image = renderer.render(part: part) else { throw CocoaError(.fileWriteUnknown) }
                    try Self.writePNG(image, to: url)
                }
                // Slide 1 oldest, each next one second newer.
                let date = now.addingTimeInterval(Double(written.count) - Double(names.count - 1))
                try? FileManager.default.setAttributes([.modificationDate: date, .creationDate: date], ofItemAtPath: url.path)
                written.append(url)
                progress(Double(written.count) / total)
            }
        }
        return written
    }

    /// The frames of one slide as images, one per panorama part. Videos show their first frame.
    @concurrent
    public func render(slideAt index: Int) async -> [CGImage] {
        let slide = project.slides[index]
        let images = await loadImages(for: slide)
        let background = slide.style.backgroundImage.flatMap { MediaLoader.image(at: mediaURL($0)) }
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: project.format),
            scale: Double(scale),
            images: images,
            background: background
        )
        return (0..<slide.span).compactMap { renderer.render(part: $0) }
    }

    /// Full-size photos, plus video posters so a video slide has pixels before its first frame.
    private func loadImages(for slide: Slide) async -> [String: CGImage] {
        var images: [String: CGImage] = [:]
        for media in slide.slots.compactMap(\.self) where images[media.file] == nil {
            images[media.file] = await MediaLoader.preview(at: mediaURL(media.file))
        }
        return images
    }

    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: "0", count: max(length - count, 0)) + self
    }
}
