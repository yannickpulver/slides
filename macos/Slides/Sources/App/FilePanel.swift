import AppKit
import SlidesCore
import UniformTypeIdentifiers

@MainActor
enum FilePanel {
    static func pickMedia(multiple: Bool = true, imagesOnly: Bool = false) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        panel.allowedContentTypes = imagesOnly ? [.image] : MediaLoader.contentTypes
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// Asks for an export folder, starting where the last export went.
    static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose a folder for the exported slides"
        if let last = UserDefaults.standard.url(forKey: "lastExportFolder") { panel.directoryURL = last }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        UserDefaults.standard.set(url, forKey: "lastExportFolder")
        return url
    }
}
