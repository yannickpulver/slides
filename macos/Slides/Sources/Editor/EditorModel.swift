import AppKit
import Foundation
import Observation
import SlidesCore

/// One open project: edits with undo, imports, autosave and export.
@MainActor
@Observable
final class EditorModel {
    private(set) var project: Project
    let url: URL
    let library: ProjectLibrary

    var selectedSlideID: Slide.ID
    private(set) var importing = 0
    private(set) var exportProgress: Double?
    var exportError: String?
    var exportScale = 2

    @ObservationIgnored weak var undoManager: UndoManager?
    @ObservationIgnored private var lastEdit: (key: String, time: Date)?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(project: Project, url: URL, library: ProjectLibrary) {
        self.project = project
        self.url = url
        self.library = library
        selectedSlideID = project.slides[0].id
    }

    var currentSlide: Slide {
        project.slides.first { $0.id == selectedSlideID } ?? project.slides[0]
    }

    var currentIndex: Int { project.index(of: selectedSlideID) ?? 0 }

    func mediaURL(_ file: String) -> URL {
        library.mediaURL(file, in: url)
    }

    // MARK: - Edits

    /// Applies a change with undo. Edits with the same `key` within a second merge into one undo step,
    /// so a slider drag or a pan undoes in one go.
    func edit(_ key: String? = nil, _ change: (inout Project) -> Void) {
        let before = project
        change(&project)
        guard project != before else { return }
        let now = Date()
        let merges = key != nil && lastEdit?.key == key && now.timeIntervalSince(lastEdit!.time) < 1
        if !merges { registerUndo(restoring: before) }
        lastEdit = key.map { ($0, now) }
        scheduleSave()
    }

    func editSlide(_ id: Slide.ID? = nil, _ key: String? = nil, _ change: (inout Slide) -> Void) {
        edit(key) { $0.updateSlide(id ?? selectedSlideID, change) }
    }

    private func registerUndo(restoring snapshot: Project) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                // Registering while undoing fills the redo stack.
                model.registerUndo(restoring: model.project)
                model.project = snapshot
                model.lastEdit = nil
                if model.project.index(of: model.selectedSlideID) == nil {
                    model.selectedSlideID = model.project.slides[0].id
                }
                model.scheduleSave()
            }
        }
    }

    func rename(_ name: String) { edit("name") { $0.name = name } }
    func setFormat(_ format: Format) { edit { $0.format = format } }
    func chooseLayout(_ layout: Layout, span: Int = 1) { editSlide { $0.choose(layout, span: span) } }
    func setColor(_ color: RGB) { editSlide(nil, "color") { $0.style.color = color } }
    func setGap(_ gap: Double) { editSlide(nil, "gap") { $0.style.gap = gap } }
    func setBorder(_ border: Double) { editSlide(nil, "border") { $0.style.border = border } }
    func setBlur(_ blur: Double) { editSlide(nil, "blur") { $0.style.blur = blur } }
    func setFit(_ fit: Fit) { editSlide { $0.style.fit = fit } }
    func setFilmEdge(_ edge: FilmEdge?) { editSlide { $0.style.filmEdge = edge } }
    func clearBackgroundImage() { editSlide { $0.style.backgroundImage = nil } }
    func removeMedia(slot: Int, in slideID: Slide.ID) { editSlide(slideID) { $0.removeMedia(at: slot) } }

    func setCrop(_ crop: Crop, slot: Int, in slideID: Slide.ID) {
        editSlide(slideID, "crop-\(slideID)-\(slot)") { $0.slots[slot]?.crop = crop }
    }

    // MARK: - Slides

    func select(_ id: Slide.ID) { selectedSlideID = id }

    func selectPrevious() {
        if currentIndex > 0 { selectedSlideID = project.slides[currentIndex - 1].id }
    }

    func selectNext() {
        if currentIndex < project.slides.count - 1 { selectedSlideID = project.slides[currentIndex + 1].id }
    }

    func addSlide() {
        var id = selectedSlideID
        edit { id = $0.insertSlide(after: id) }
        selectedSlideID = id
    }

    func removeSlide(_ id: Slide.ID) {
        var next: Slide.ID?
        edit { next = $0.removeSlide(id) }
        if let next, id == selectedSlideID { selectedSlideID = next }
    }

    func moveSlide(_ id: Slide.ID, to destination: Int) {
        edit { $0.moveSlide(id, to: destination) }
    }

    // MARK: - Import

    /// Copies dropped or picked files into the project and places them, starting at `slot`.
    func drop(_ urls: [URL], slot: Int?, in slideID: Slide.ID) {
        let files = urls.filter { MediaLoader.kind(of: $0) != nil }
        guard !files.isEmpty else { return }
        importing += 1
        Task {
            defer { importing -= 1 }
            let media = await Self.importFiles(files, library: library, project: url)
            for item in media { await MediaCache.shared.preload(mediaURL(item.file)) }
            editSlide(slideID) { $0.place(media, at: slot) }
        }
    }

    func setBackgroundImage(_ source: URL) {
        let slideID = selectedSlideID
        importing += 1
        Task {
            defer { importing -= 1 }
            guard let media = await Self.importFiles([source], library: library, project: url).first else { return }
            await MediaCache.shared.preload(mediaURL(media.file))
            editSlide(slideID) { $0.style.backgroundImage = media.file }
        }
    }

    @concurrent
    private static func importFiles(_ urls: [URL], library: ProjectLibrary, project: URL) async -> [Media] {
        urls.compactMap { source in
            guard let kind = MediaLoader.kind(of: source),
                  let file = try? library.importMedia(source, into: project) else { return nil }
            return Media(file: file, kind: kind)
        }
    }

    // MARK: - Save

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    /// Writes `project.json` right away; the cover follows when it's rendered.
    func saveNow() {
        saveTask?.cancel()
        try? library.save(project, at: url)
        Task { await saveCover() }
    }

    /// Writes `project.json` and waits for the cover, so the start screen shows it.
    func save() async {
        saveTask?.cancel()
        try? library.save(project, at: url)
        await saveCover()
    }

    private func saveCover() async {
        let project = project
        let library = library
        let url = url
        guard let cover = await Self.renderCover(project, mediaURL: { library.mediaURL($0, in: url) }) else { return }
        try? library.saveCover(cover, at: url)
    }

    /// First frame at 480 px high, from small decodes of the media.
    @concurrent
    private static func renderCover(_ project: Project, mediaURL: @Sendable (String) -> URL) async -> CGImage? {
        let slide = project.slides[0]
        var images: [String: CGImage] = [:]
        for media in slide.slots.compactMap(\.self) {
            images[media.file] = await MediaLoader.preview(at: mediaURL(media.file), maxPixelSize: 1200)
        }
        let background = slide.style.backgroundImage.flatMap { MediaLoader.image(at: mediaURL($0), maxPixelSize: 1200) }
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: project.format),
            scale: 480 / project.format.height,
            images: images,
            background: background
        )
        return renderer.render(part: 0)
    }

    // MARK: - Export

    func export(to folder: URL) {
        guard exportProgress == nil else { return }
        saveNow()
        exportProgress = 0
        let library = library
        let projectURL = url
        let exporter = Exporter(project: project, scale: exportScale) { library.mediaURL($0, in: projectURL) }
        Task {
            do {
                let urls = try await exporter.export(to: folder) { fraction in
                    Task { @MainActor in
                        if self.exportProgress != nil { self.exportProgress = fraction }
                    }
                }
                exportProgress = nil
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            } catch {
                exportProgress = nil
                exportError = error.localizedDescription
            }
        }
    }
}
