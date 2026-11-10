import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the start screen shows per project.
public struct ProjectSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let modified: Date
    public let frameCount: Int
    public let hasPanorama: Bool

    public var coverURL: URL { url.appending(path: ProjectLibrary.coverFile) }
}

/// Projects as folders `<id>.slides/` holding `project.json`, `media/` and `cover.jpg`.
public struct ProjectLibrary: Sendable {
    static let projectFile = "project.json"
    static let mediaFolder = "media"
    static let coverFile = "cover.jpg"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "Slides/Projects", directoryHint: .isDirectory)
    }

    public func list() -> [ProjectSummary] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return folders.filter { $0.pathExtension == "slides" }.compactMap { url in
            let file = url.appending(path: Self.projectFile)
            guard let project = try? load(url) else { return nil }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return ProjectSummary(
                id: project.id,
                url: url,
                name: project.name,
                modified: modified,
                frameCount: project.frameCount,
                hasPanorama: project.slides.contains(where: \.isPanorama)
            )
        }
    }

    public func create(name: String) throws -> (Project, URL) {
        let project = Project(name: name)
        let url = root.appending(path: "\(project.id.uuidString).slides", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: mediaFolder(of: url), withIntermediateDirectories: true)
        try save(project, at: url)
        return (project, url)
    }

    public func load(_ url: URL) throws -> Project {
        let data = try Data(contentsOf: url.appending(path: Self.projectFile))
        return try JSONDecoder().decode(Project.self, from: data)
    }

    public func save(_ project: Project, at url: URL, cover: CGImage? = nil) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(project).write(to: url.appending(path: Self.projectFile), options: .atomic)
        if let cover { try saveCover(cover, at: url) }
    }

    public func saveCover(_ cover: CGImage, at url: URL) throws {
        try Self.writeJPEG(cover, to: url.appending(path: Self.coverFile))
    }

    public func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public func mediaFolder(of project: URL) -> URL {
        project.appending(path: Self.mediaFolder, directoryHint: .isDirectory)
    }

    public func mediaURL(_ file: String, in project: URL) -> URL {
        mediaFolder(of: project).appending(path: file)
    }

    /// Copies a file into the project's `media/` folder and returns its file name.
    /// A file with the same name and size counts as the same file and gets reused.
    public func importMedia(_ source: URL, into project: URL) throws -> String {
        let folder = mediaFolder(of: project)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if source.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL {
            return source.lastPathComponent
        }
        let size = Self.fileSize(source)
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var name = source.lastPathComponent
        var counter = 1
        while FileManager.default.fileExists(atPath: folder.appending(path: name).path) {
            if Self.fileSize(folder.appending(path: name)) == size { return name }
            name = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            counter += 1
        }
        try FileManager.default.copyItem(at: source, to: folder.appending(path: name))
        return name
    }

    static func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
