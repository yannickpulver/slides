import SlidesCore
import SwiftUI

struct EditorView: View {
    @Bindable var editor: EditorModel
    let onBack: () -> Void

    @Environment(\.undoManager) private var undoManager
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TopBar(editor: editor, onBack: onBack)
            Divider().overlay(Theme.outlineSoft)
            HStack(spacing: 0) {
                SlideRow(editor: editor, onBackgroundTap: { focused = true })
                Sidebar(editor: editor)
            }
            Divider().overlay(Theme.outlineSoft)
            Filmstrip(editor: editor)
        }
        .background(Theme.background)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.leftArrow) { editor.selectPrevious(); return .handled }
        .onKeyPress(.rightArrow) { editor.selectNext(); return .handled }
        .onKeyPress(.escape) { onBack(); return .handled }
        .onAppear {
            editor.undoManager = undoManager
            focused = true
        }
        .onChange(of: undoManager) { _, manager in editor.undoManager = manager }
        .onChange(of: editor.selectedSlideID) { _, _ in focused = true }
        .overlay(alignment: .top) {
            if editor.importing > 0 {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Importing…").font(Theme.font(11))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surface, in: Capsule())
                .padding(.top, 64)
            }
        }
        .overlay {
            if let progress = editor.exportProgress {
                ExportProgress(progress: progress)
            }
        }
        .alert("Export failed", isPresented: Binding(
            get: { editor.exportError != nil },
            set: { if !$0 { editor.exportError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(editor.exportError ?? "")
        }
    }
}

private struct TopBar: View {
    @Bindable var editor: EditorModel
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back to projects (Esc)")

            TextField("Name", text: Binding(get: { editor.project.name }, set: { editor.rename($0) }))
                .textFieldStyle(.plain)
                .font(Theme.font(13, .medium))
                .frame(width: 240)

            Spacer()

            Segmented(
                options: Format.allCases,
                selection: editor.project.format,
                label: \.label,
                onSelect: editor.setFormat
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

/// Small segmented switch in the original app's look.
struct Segmented<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { onSelect(option) } label: {
                    Text(label(option))
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(selected ? Theme.background : Theme.textMuted)
                        .padding(.horizontal, 8)
                        .frame(maxHeight: .infinity)
                        .background(selected ? Theme.text : .clear, in: RoundedRectangle(cornerRadius: 3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(height: 24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.outline, lineWidth: 0.5))
    }
}

private struct ExportProgress: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Exporting…").font(Theme.font(15, .medium))
                ProgressView(value: progress).frame(width: 240)
                Text("\(Int(progress * 100))%")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(24)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
