import CoreGraphics
import Foundation
import Observation
import SlidesCore

/// Small renders of every slide for the start screen's filmstrip, one image per frame.
/// A save changes the project's date, so its slides render again.
@MainActor
@Observable
final class SlideThumbnails {
    static let shared = SlideThumbnails()
    /// Pixels on the frame height: twice the filmstrip's points, for Retina.
    static let pixelHeight = 2 * ProjectFilmstrip.height

    /// One save of a project.
    private struct Version: Hashable {
        let url: URL
        let modified: Date
    }

    private struct Key: Hashable {
        let version: Version
        let slide: Slide.ID
    }

    private var rendered: [Key: [CGImage]] = [:]
    @ObservationIgnored private var loading: Set<Key> = []

    /// Returns the frames if rendered; otherwise starts rendering and returns `nil` until they land.
    func frames(of slide: Slide, in project: ProjectSummary, library: ProjectLibrary) -> [CGImage]? {
        let key = Key(version: Version(url: project.url, modified: project.modified), slide: slide.id)
        if let images = rendered[key] { return images }
        guard !loading.contains(key) else { return nil }
        loading.insert(key)
        let url = project.url
        Task {
            let images = await SlideRenderer.thumbnails(of: slide, format: project.format, height: Self.pixelHeight) {
                library.mediaURL($0, in: url)
            }
            loading.remove(key)
            rendered[key] = images
        }
        return nil
    }

    /// Drops the renders of deleted projects and older saves.
    func keep(_ projects: [ProjectSummary]) {
        let current = Set(projects.map { Version(url: $0.url, modified: $0.modified) })
        rendered = rendered.filter { current.contains($0.key.version) }
    }
}
