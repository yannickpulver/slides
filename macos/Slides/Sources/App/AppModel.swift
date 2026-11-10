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

    init(library: ProjectLibrary = AppModel.defaultLibrary) {
        self.library = library
        try? FileManager.default.createDirectory(at: library.root, withIntermediateDirectories: true)
        refresh()
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

    func open(_ summary: ProjectSummary) {
        guard let project = try? library.load(summary.url) else { return }
        editor = EditorModel(project: project, url: summary.url, library: library)
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

    func delete(_ summary: ProjectSummary) {
        try? library.trash(summary.url)
        refresh()
    }

    func revealInFinder(_ summary: ProjectSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([summary.url])
    }
}
