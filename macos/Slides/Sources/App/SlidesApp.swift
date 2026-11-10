import AppKit
import SwiftUI

@main
struct SlidesApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app = AppModel()
    @State private var updater = Updater()

    var body: some Scene {
        Window("Slides", id: "main") {
            RootView(app: app)
                .frame(minWidth: 960, minHeight: 620)
                .onAppear { delegate.app = app }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Project") { app.newProject() }
                    .keyboardShortcut("n")
                Button("Back to Projects") { app.close() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(app.editor == nil)
            }
            CommandGroup(after: .saveItem) {
                Group {
                    Button("Save") { app.editor?.saveNow() }
                        .keyboardShortcut("s")
                    Button("Rename Project…") { app.editor?.renaming = true }
                    Button("Export…") { app.editor?.exportWithPanel() }
                        .keyboardShortcut("e")
                    Button("Export Large…") { app.editor?.exportWithPanel(.large) }
                        .keyboardShortcut("e", modifiers: [.command, .option])
                }
                .disabled(app.editor == nil)
            }
            CommandMenu("Slide") {
                Group {
                    Button("Add Slide") { app.editor?.addSlide() }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("Add Photos…") { app.editor?.pickMediaForCurrentSlide() }
                        .keyboardShortcut("o")
                    Divider()
                    Button("Previous Slide") { app.editor?.selectPrevious() }
                        .keyboardShortcut("[")
                    Button("Next Slide") { app.editor?.selectNext() }
                        .keyboardShortcut("]")
                    Divider()
                    Button("Delete Slide") { app.editor.map { $0.removeSlide($0.selectedSlideID) } }
                        .disabled((app.editor?.project.slides.count ?? 0) < 2)
                }
                .disabled(app.editor == nil)
            }
        }
    }
}

struct RootView: View {
    let app: AppModel

    var body: some View {
        if let editor = app.editor {
            EditorView(editor: editor, onBack: app.close)
                .id(editor.url)
        } else {
            ProjectPickerView(app: app)
        }
    }
}

/// Saves the open project when the app quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var app: AppModel?

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { app?.editor?.saveNow() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
