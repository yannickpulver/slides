import SlidesCore
import SwiftUI

/// The selected slide on the canvas, all slides in the filmstrip below, settings in the inspector.
struct EditorView: View {
    @Bindable var editor: EditorModel
    let onBack: () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var showInspector = true
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            SlideCanvas(editor: editor)
            Filmstrip(editor: editor)
        }
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
            ToolbarItem(placement: .principal) {
                Picker("Format", selection: Binding(get: { editor.project.format }, set: editor.setFormat)) {
                    ForEach(Format.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Slide format")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: editor.exportWithPanel) {
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
        .onKeyPress(.leftArrow) { editor.selectPrevious(); return .handled }
        .onKeyPress(.rightArrow) { editor.selectNext(); return .handled }
        .onKeyPress(.escape) { onBack(); return .handled }
        .onAppear { editor.undoManager = undoManager }
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
}
