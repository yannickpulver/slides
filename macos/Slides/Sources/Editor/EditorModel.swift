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
    var renaming = false
    var exportSize = ExportSize.instagram

    /// Text tool: the next click on the slide places a text box.
    var placingText = false
    private(set) var selectedTextID: TextBox.ID?
    private(set) var editingTextID: TextBox.ID?
    /// Style of the last text the user styled, for the next new box.
    @ObservationIgnored private var textStyle: TextBox?

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

    func setAngle(_ angle: Double, slot: Int, in slideID: Slide.ID? = nil) {
        let angle = min(max(angle, -Crop.maxAngle), Crop.maxAngle)
        editSlide(slideID, "angle-\(slideID ?? selectedSlideID)-\(slot)") { $0.slots[slot]?.crop.angle = angle }
    }

    // MARK: - Slides

    func select(_ id: Slide.ID) {
        guard id != selectedSlideID else { return }
        endTextEditing()
        selectedTextID = nil
        selectedSlideID = id
    }

    func selectPrevious() {
        if currentIndex > 0 { select(project.slides[currentIndex - 1].id) }
    }

    func selectNext() {
        if currentIndex < project.slides.count - 1 { select(project.slides[currentIndex + 1].id) }
    }

    func addSlide() {
        var id = selectedSlideID
        edit { id = $0.insertSlide(after: id) }
        select(id)
    }

    func duplicateSlide(_ id: Slide.ID) {
        var copy: Slide.ID?
        edit { copy = $0.duplicateSlide(id) }
        if let copy { select(copy) }
    }

    func removeSlide(_ id: Slide.ID) {
        var next: Slide.ID?
        edit { next = $0.removeSlide(id) }
        if let next, id == selectedSlideID { select(next) }
    }

    // MARK: - Text

    var selectedText: TextBox? {
        guard let id = selectedTextID else { return nil }
        return currentSlide.texts.first { $0.id == id }
    }

    /// Places a text box with its top-left at `point` (1x canvas pixels) and starts editing it.
    /// A `width` makes it wrap; without one it grows with the text.
    @discardableResult
    func addText(at point: CGPoint, width: Double? = nil, text: String = "", in slideID: Slide.ID? = nil) -> TextBox.ID {
        let slideID = slideID ?? selectedSlideID
        var box = textStyle ?? TextBox(text: "", x: 0, y: 0)
        box.id = UUID()
        box.text = text
        box.x = point.x
        box.y = point.y
        box.width = width
        if textStyle == nil, let slide = project.slides.first(where: { $0.id == slideID }) {
            // White on dark backgrounds until a color is picked.
            let color = slide.style.color
            box.color = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b < 0.5 ? .white : .black
        }
        editSlide(slideID) { $0.addText(box) }
        placingText = false
        if slideID == selectedSlideID {
            selectedTextID = box.id
            editingTextID = text.isEmpty ? box.id : nil
        }
        return box.id
    }

    /// Changes a text box. `key` merges a drag or typing into one undo step.
    func updateText(_ id: TextBox.ID, in slideID: Slide.ID? = nil, _ key: String? = nil, _ change: (inout TextBox) -> Void) {
        editSlide(slideID, key.map { "text-\(id)-\($0)" }) { $0.updateText(id, change) }
    }

    /// Changes the look of a text box and remembers it for the next new one.
    func styleText(_ id: TextBox.ID, _ key: String? = nil, _ change: (inout TextBox) -> Void) {
        updateText(id, in: nil, key, change)
        if let box = currentSlide.texts.first(where: { $0.id == id }) { textStyle = box }
    }

    func removeText(_ id: TextBox.ID, in slideID: Slide.ID? = nil) {
        if editingTextID == id { editingTextID = nil }
        if selectedTextID == id { selectedTextID = nil }
        editSlide(slideID) { $0.removeText(id) }
    }

    func selectText(_ id: TextBox.ID?) {
        if id != editingTextID { endTextEditing() }
        selectedTextID = id
        if id != nil { placingText = false }
    }

    func editText(_ id: TextBox.ID) {
        selectedTextID = id
        editingTextID = id
        placingText = false
    }

    /// Leaves the text field. An empty box goes away, like in Figma.
    func endTextEditing() {
        guard let id = editingTextID else { return }
        editingTextID = nil
        if let box = currentSlide.texts.first(where: { $0.id == id }), box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            removeText(id)
        }
    }

    func moveSlide(_ id: Slide.ID, to destination: Int) {
        edit { $0.moveSlide(id, to: destination) }
    }

    // MARK: - Import

    /// Copies dropped or picked files into the project and places them, starting at `slot`.
    func drop(_ urls: [URL], slot: Int?, in slideID: Slide.ID) {
        Task { await place(urls, slot: slot, in: slideID) }
    }

    /// Imports and places the files; returns how many were placed (media that doesn't fit is left out).
    @discardableResult
    func place(_ urls: [URL], slot: Int?, in slideID: Slide.ID) async -> Int {
        let media = await importMedia(urls)
        guard !media.isEmpty else { return 0 }
        var placed = 0
        editSlide(slideID) { placed = $0.place(media, at: slot) }
        return placed
    }

    func setBackgroundImage(_ source: URL) {
        let slideID = selectedSlideID
        Task {
            guard let media = await importMedia([source]).first else { return }
            editSlide(slideID) { $0.style.backgroundImage = media.file }
        }
    }

    /// Copies photos and videos into the project's `media/` folder and decodes them for the editor.
    /// Other files are skipped.
    func importMedia(_ urls: [URL]) async -> [Media] {
        let files = urls.filter { MediaLoader.kind(of: $0) != nil }
        guard !files.isEmpty else { return [] }
        importing += 1
        defer { importing -= 1 }
        let media = await Self.importFiles(files, library: library, project: url)
        for item in media { await MediaCache.shared.preload(mediaURL(item.file)) }
        return media
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

    /// Export sizes: Instagram keeps photos up to 2× (1536 × 2048 for 4:3).
    enum ExportSize: Int, CaseIterable {
        case instagram = 2
        case large = 3

        var name: String {
            switch self {
            case .instagram: "Instagram"
            case .large: "Large"
            }
        }
    }

    func pixelSize(_ size: ExportSize) -> String {
        let scale = Double(size.rawValue)
        return "\(String(Int(project.format.width * scale))) × \(String(Int(project.format.height * scale))) px"
    }

    func exportWithPanel() {
        if let folder = FilePanel.pickFolder() { export(to: folder, size: exportSize) }
    }

    func pickMediaForCurrentSlide() {
        let urls = FilePanel.pickMedia()
        if !urls.isEmpty { drop(urls, slot: nil, in: selectedSlideID) }
    }

    func export(to folder: URL, size: ExportSize = .instagram) {
        Task {
            guard let urls = try? await exportFiles(to: folder, size: size) else { return }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    /// Writes all frames into `folder` and returns the files. Fails while another export runs.
    func exportFiles(to folder: URL, size: ExportSize = .instagram) async throws -> [URL] {
        guard exportProgress == nil else { throw CocoaError(.userCancelled) }
        saveNow()
        exportProgress = 0
        defer { exportProgress = nil }
        let library = library
        let projectURL = url
        let exporter = Exporter(project: project, scale: size.rawValue) { library.mediaURL($0, in: projectURL) }
        do {
            return try await exporter.export(to: folder) { fraction in
                Task { @MainActor in
                    if self.exportProgress != nil { self.exportProgress = fraction }
                }
            }
        } catch {
            exportError = error.localizedDescription
            throw error
        }
    }
}
