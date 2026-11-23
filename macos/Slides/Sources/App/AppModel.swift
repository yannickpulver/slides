import AppKit
import Foundation
import Observation
import SlidesCore

/// The project list and the open editor.
@MainActor
@Observable
final class AppModel {
    let library: ProjectLibrary
    private(set) var projects: [ProjectSummary] = []
    private(set) var editor: EditorModel?
    @ObservationIgnored private var mcp: MCPServer?

    init(library: ProjectLibrary = AppModel.defaultLibrary) {
        self.library = library
        try? FileManager.default.createDirectory(at: library.root, withIntermediateDirectories: true)
        refresh()
        let tools = MCPProtocol(tools: SlidesTools(app: self))
        mcp = MCPServer { await tools.handle($0) }
        mcp?.start()
        #if DEBUG
            // `SLIDES_OPEN_PROJECT=<path to .slides folder>` opens a project at launch, for screenshots.
            if let path = ProcessInfo.processInfo.environment["SLIDES_OPEN_PROJECT"],
               let summary = projects.first(where: { $0.url.standardizedFileURL.path == URL(filePath: path).standardizedFileURL.path }) {
                open(summary)
                if let index = ProcessInfo.processInfo.environment["SLIDES_SELECT"].flatMap(Int.init),
                   let editor, editor.project.slides.indices.contains(index) {
                    editor.select(editor.project.slides[index].id)
                }
                if let folder = ProcessInfo.processInfo.environment["SLIDES_EXPORT"] {
                    editor?.export(to: URL(filePath: folder, directoryHint: .isDirectory))
                }
            }
        #endif
    }

    private static var defaultLibrary: ProjectLibrary {
        #if DEBUG
            // `SLIDES_LIBRARY=<folder>` keeps test runs out of the real projects.
            if let path = ProcessInfo.processInfo.environment["SLIDES_LIBRARY"] {
                return ProjectLibrary(root: URL(filePath: path, directoryHint: .isDirectory))
            }
        #endif
        return ProjectLibrary(root: ProjectLibrary.defaultRoot)
    }

    func refresh() {
        projects = library.list()
    }

    func newProject() {
        close()
        let name = "Project \(Date.now.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))"
        guard let (project, url) = try? library.create(name: name) else { return }
        editor = EditorModel(project: project, url: url, library: library)
        refresh()
    }

    /// Opens a project, on `slide` when given.
    func open(_ summary: ProjectSummary, slide: Slide.ID? = nil) {
        guard let project = try? library.load(summary.url) else { return }
        let editor = EditorModel(project: project, url: summary.url, library: library)
        if let slide, project.slides.contains(where: { $0.id == slide }) { editor.select(slide) }
        self.editor = editor
    }

    /// Saves and goes back to the project list.
    func close() {
        guard let editor else { return }
        self.editor = nil
        refresh()
        Task {
            await editor.save()
            refresh()
        }
    }

    /// A text field undoes its typing; otherwise the open project undoes its last edit.
    /// The menu's own Undo can't reach the project: the editor's key-focus proxy has no undo manager.
    func undo() {
        if NSApp.keyWindow?.firstResponder is NSTextView {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        } else if editor?.undoManager?.canUndo == true {
            editor?.undoManager?.undo()
        }
    }

    func redo() {
        if NSApp.keyWindow?.firstResponder is NSTextView {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        } else if editor?.undoManager?.canRedo == true {
            editor?.undoManager?.redo()
        }
    }

    func delete(_ summary: ProjectSummary) {
        try? library.trash(summary.url)
        refresh()
    }

    func revealInFinder(_ summary: ProjectSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([summary.url])
    }

    /// Puts one slide on the clipboard as PNG, rendered like the export at Instagram size.
    /// A panorama goes on as one image per frame; a video slide as its first frame.
    func copy(_ slide: Slide.ID, of summary: ProjectSummary) {
        guard let project = try? library.load(summary.url),
              let index = project.slides.firstIndex(where: { $0.id == slide }) else { return }
        let library = library
        let url = summary.url
        let exporter = Exporter(project: project, scale: EditorModel.ExportSize.instagram.rawValue) { library.mediaURL($0, in: url) }
        Task {
            let items = await exporter.render(slideAt: index).compactMap { image -> NSPasteboardItem? in
                guard let png = Exporter.pngData(image) else { return nil }
                let item = NSPasteboardItem()
                item.setData(png, forType: .png)
                return item
            }
            guard !items.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(items)
        }
    }
}
