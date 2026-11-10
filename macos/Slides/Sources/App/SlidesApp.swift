import AppKit
import SwiftUI

@main
struct SlidesApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app = AppModel()
    @State private var updater = Updater()

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        Window("Slides", id: "main") {
            RootView(app: app)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
                .font(Theme.font(13))
                .onAppear { delegate.app = app }
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
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
                Button("Save") { app.editor?.saveNow() }
                    .keyboardShortcut("s")
                    .disabled(app.editor == nil)
            }
            CommandMenu("Slide") {
                Group {
                    Button("Add Slide") { app.editor?.addSlide() }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("Previous Slide") { app.editor?.selectPrevious() }
                        .keyboardShortcut("[")
                    Button("Next Slide") { app.editor?.selectNext() }
                        .keyboardShortcut("]")
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
