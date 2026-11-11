import AppKit
import SlidesCore
import SwiftUI

/// The selected slide on the canvas, all slides in the filmstrip below, settings in the inspector.
struct EditorView: View {
    @Bindable var editor: EditorModel
    let onBack: () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var showInspector = true
    @State private var newName = ""
    /// Holds keyboard focus for the arrow keys, so they switch slides.
    @FocusState private var keysFocused: Bool

    var body: some View {
        canvas
        .inspector(isPresented: $showInspector) {
            InspectorView(editor: editor)
                .inspectorColumnWidth(min: 280, ideal: 300, max: 400)
        }
        .navigationTitle(editor.project.name)
        .navigationSubtitle("\(editor.project.frameCount) \(editor.project.frameCount == 1 ? "slide" : "slides")")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label { Text("Projects") } icon: { TablerIcon("chevron-left", size: 18) }
                }
                .help("Back to projects")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: toggleTextTool) {
                    Label { Text("Text") } icon: { TablerIcon("typography", size: 18) }
                        .foregroundStyle(editor.placingText ? Color.accentColor : .primary)
                }
                .help("Add text (T): click on the slide, or drag for a fixed width")
                Button { editor.exportWithPanel() } label: {
                    Label { Text("Export") } icon: { TablerIcon("download", size: 18) }
                }
                .help("Export all slides (⌘E)")
                Button {
                    showInspector.toggle()
                } label: {
                    Label { Text("Inspector") } icon: { TablerIcon("layout-sidebar-right", size: 18) }
                }
                .help(showInspector ? "Hide inspector" : "Show inspector")
            }
        }
        .onAppear {
            editor.undoManager = undoManager
            keysFocused = true
        }
        .onChange(of: undoManager) { _, manager in editor.undoManager = manager }
        .overlay(alignment: .bottom) {
            if editor.importing > 0 {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Importing…")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: Binding(get: { editor.exportProgress != nil }, set: { _ in })) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exporting \(editor.project.frameCount) slides…").font(.headline)
                ProgressView(value: editor.exportProgress ?? 0)
                    .frame(width: 280)
            }
            .padding(20)
            .interactiveDismissDisabled()
        }
        .alert("Export failed", isPresented: Binding(
            get: { editor.exportError != nil },
            set: { if !$0 { editor.exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editor.exportError ?? "")
        }
        .alert("Rename Project", isPresented: $editor.renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { if !newName.isEmpty { editor.rename(newName) } }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: editor.renaming) { _, renaming in
            if renaming { newName = editor.project.name }
        }
    }

    /// Canvas and filmstrip with the keyboard shortcuts. Split from `body`, which the
    /// compiler can't type-check in time otherwise (Release, universal).
    private var canvas: some View {
        VStack(spacing: 0) {
            SlideCanvas(editor: editor)
            Filmstrip(editor: editor)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($keysFocused)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow], action: arrow)
        .onKeyPress(.escape, action: escape)
        .onKeyPress(.return, action: enter)
        .onKeyPress(action: otherKey)
        .onChange(of: editor.editingTextID) { _, id in
            // While editing, the text field holds the keys; SwiftUI focus would take them back.
            keysFocused = id == nil
        }
        .onChange(of: editor.selectedSlideID) { _, _ in keysFocused = true }
    }

    /// Arrows nudge the selected text (10 px with ⇧), otherwise switch slides.
    private func arrow(_ press: KeyPress) -> KeyPress.Result {
        guard !typing else { return .ignored }
        if let id = editor.selectedTextID {
            let step = press.modifiers.contains(.shift) ? 10.0 : 1.0
            let (dx, dy) = switch press.key {
            case .leftArrow: (-step, 0.0)
            case .rightArrow: (step, 0.0)
            case .upArrow: (0.0, -step)
            default: (0.0, step)
            }
            editor.updateText(id, "nudge") { $0.x += dx; $0.y += dy }
        } else if press.key == .leftArrow || press.key == .upArrow {
            editor.selectPrevious()
        } else {
            editor.selectNext()
        }
        return .handled
    }

    private func escape() -> KeyPress.Result {
        guard !typing else { return .ignored }
        if editor.placingText {
            editor.placingText = false
        } else if editor.selectedTextID != nil {
            editor.selectText(nil)
        } else {
            onBack()
        }
        return .handled
    }

    private func enter() -> KeyPress.Result {
        guard !typing, let id = editor.selectedTextID else { return .ignored }
        editor.editText(id)
        return .handled
    }

    /// T toggles the text tool; ⌫ deletes the selected text, or else the slide.
    private func otherKey(_ press: KeyPress) -> KeyPress.Result {
        guard !typing else { return .ignored }
        if press.characters == "t", press.modifiers.isEmpty {
            toggleTextTool()
            return .handled
        }
        // ⌫ arrives as U+007F on macOS, forward delete as `.deleteForward`.
        guard press.key == .delete || press.key == .deleteForward || press.characters == "\u{7F}" else { return .ignored }
        if let id = editor.selectedTextID {
            editor.removeText(id)
        } else {
            deleteSelectedSlide()
        }
        return .handled
    }

    /// A text field has the keys (inline text, inspector fields): the shortcuts step aside.
    /// SwiftUI asks these handlers before the field gets the key.
    private var typing: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    private func toggleTextTool() {
        editor.selectText(nil)
        editor.placingText.toggle()
    }

    /// ⌫ deletes the selected slide; the last remaining slide stays.
    private func deleteSelectedSlide() {
        guard editor.project.slides.count > 1 else { return }
        editor.removeSlide(editor.selectedSlideID)
    }
}

