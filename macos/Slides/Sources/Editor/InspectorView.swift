import AppKit
import SlidesCore
import SwiftUI

/// Settings of the selected slide, and export.
struct InspectorView: View {
    let editor: EditorModel

    private var slide: Slide { editor.currentSlide }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let box = editor.selectedText {
                    TextCard(editor: editor, box: box)
                }
                FormatCard(editor: editor)
                LayoutCard(editor: editor, slide: slide)
                BackgroundCard(editor: editor, slide: slide)
                PhotoCard(editor: editor, slide: slide)
                ExportCard(editor: editor)
            }
            .padding(16)
            // No preferred width of its own: otherwise the column re-measures on every slide
            // switch and grows to the sliders' preferred width.
            .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity)
        }
    }
}

// MARK: - Text

/// The selected text box, like Figma's typography panel.
private struct TextCard: View {
    let editor: EditorModel
    let box: TextBox

    private func style(_ key: String? = nil, _ change: @escaping (inout TextBox) -> Void) {
        editor.styleText(box.id, key, change)
    }

    var body: some View {
        let family = Fonts.family(of: box.font)
        let members = Fonts.members(of: family)
        Card(title: "Text", icon: "typography") {
            Button { editor.removeText(box.id) } label: { TablerIcon("trash", size: 15) }
                .buttonStyle(.borderless)
                .help("Delete text (⌫)")
        } content: {
            Picker("Font", selection: Binding(get: { family }, set: { newFamily in
                let current = members.first { $0.postScript == box.font }?.style
                let options = Fonts.members(of: newFamily)
                let pick = options.first { $0.style == current } ?? options.first { $0.style == "Regular" } ?? options.first
                if let pick { style { $0.font = pick.postScript } }
            })) {
                ForEach(Fonts.families, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .buttonSizing(.flexible)
            .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Picker("Style", selection: Binding(get: { box.font }, set: { name in style { $0.font = name } })) {
                    ForEach(members, id: \.postScript) { Text($0.style).tag($0.postScript) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(maxWidth: .infinity)
                NumberField(value: box.size, placeholder: "Size", help: "Font size in px") { value in
                    if let value { style { $0.size = min(max(value, TextBox.sizeRange.lowerBound), TextBox.sizeRange.upperBound) } }
                }
                .frame(width: 64)
            }
            Row(label: "Color") {
                HStack(spacing: 8) {
                    Swatch(color: .white, selected: box.color == .white) { style { $0.color = .white } }
                    Swatch(color: .black, selected: box.color == .black) { style { $0.color = .black } }
                    ColorPicker("Text color", selection: Binding(
                        get: { Color(box.color) },
                        set: { color in style("color") { $0.color = RGB(NSColor(color)) } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
            }
            Row(label: "Align") {
                Picker("Align", selection: Binding(get: { box.alignment }, set: { alignment in style { $0.alignment = alignment } })) {
                    ForEach(TextAlignment.allCases, id: \.self) { alignment in
                        TablerIcon("align-\(alignment.rawValue)", size: 14).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Row(label: "Width") {
                Picker("Width", selection: Binding(get: { box.width != nil }, set: { fixed in
                    let width = TextRenderer.size(of: box).width
                    editor.updateText(box.id) { $0.width = fixed ? width : nil }
                })) {
                    Text("Auto").tag(false)
                    Text("Fixed").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Auto grows with the text; Fixed wraps it. The side handles set the width too.")
            }
            HStack(spacing: 10) {
                NumberField(icon: "line-height", value: box.lineHeight, placeholder: "Auto", suffix: "%", help: "Line height in % of the font size, empty for auto") { value in
                    style { $0.lineHeight = value.map { max($0, 10) } }
                }
                NumberField(icon: "letter-spacing", value: box.letterSpacing, placeholder: "0", suffix: "%", help: "Letter spacing in % of the font size") { value in
                    style { $0.letterSpacing = value ?? 0 }
                }
            }
        }
    }
}

/// Number entry that commits on Return or when it loses focus. Empty commits `nil`.
private struct NumberField: View {
    var icon: String?
    let value: Double?
    let placeholder: String
    var suffix = ""
    let help: String
    let onCommit: (Double?) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                TablerIcon(icon, size: 15).foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, focused in if !focused { commit() } }
            if !suffix.isEmpty {
                Text(suffix).foregroundStyle(.secondary)
            }
        }
        .help(help)
        .onAppear { text = format(value) }
        .onChange(of: value) { _, value in if !focused { text = format(value) } }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let number = Double(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "%px ")))
        if trimmed.isEmpty || number != nil, number != value { onCommit(number) }
        text = format(number ?? value)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// Installed fonts by family, with their styles as PostScript names.
enum Fonts {
    struct Member: Hashable {
        let postScript: String
        let style: String
    }

    static let families: [String] = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }

    static func members(of family: String) -> [Member] {
        (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).compactMap { member in
            guard let name = member.first as? String, let style = member.dropFirst().first as? String else { return nil }
            return Member(postScript: name, style: style)
        }
    }

    static func family(of postScript: String) -> String {
        NSFont(name: postScript, size: 12)?.familyName ?? "Helvetica Neue"
    }
}

// MARK: - Format

/// Applies to every slide of the project.
private struct FormatCard: View {
    let editor: EditorModel

    var body: some View {
        Card(title: "Format", icon: "aspect-ratio") {
            Row(label: "Ratio") {
                Picker("Format", selection: Binding(get: { editor.project.format }, set: { editor.setFormat($0) })) {
                    ForEach(Format.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Text("Applies to all slides")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Layout

private struct LayoutCard: View {
    let editor: EditorModel
    let slide: Slide

    var body: some View {
        Card(title: "Slide \(editor.currentIndex + 1)", icon: "layout-rows") {
            // Short and allowed to truncate: a longer text here would widen the inspector.
            Text(slide.isPanorama ? "\(slide.span) parts" : "\(slide.mediaCount) of \(slide.layout.slotCount)")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(-1)
        } content: {
            Text("Stack").foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Layout.allCases, id: \.self) { layout in
                    LayoutTile(selected: !slide.isPanorama && slide.layout == layout, help: "\(layout.slotCount) stacked") {
                        StackIcon(count: layout.slotCount)
                    } action: {
                        editor.chooseLayout(layout)
                    }
                }
            }
            Text("Panorama").foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(2...Slide.maxSpan, id: \.self) { span in
                    LayoutTile(selected: slide.span == span, help: "One photo across \(span) slides") {
                        PanoramaIcon(count: span)
                    } action: {
                        editor.chooseLayout(.single, span: span)
                    }
                }
            }
        }
    }
}

private struct LayoutTile<Icon: View>: View {
    let selected: Bool
    let help: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon()
                .padding(7)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(selected ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.primary.opacity(0.8) : .clear, lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(selected ? 0.9 : 0.4))
        .help(help)
    }
}

private struct StackIcon: View {
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in RoundedRectangle(cornerRadius: 1.5).fill(.foreground) }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}

private struct PanoramaIcon: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in RoundedRectangle(cornerRadius: 1.5).fill(.foreground) }
        }
        .frame(height: 18)
    }
}

// MARK: - Background

private struct BackgroundCard: View {
    let editor: EditorModel
    let slide: Slide

    var body: some View {
        Card(title: "Background", icon: "palette") {
            Row(label: "Color") {
                HStack(spacing: 8) {
                    Swatch(color: .white, selected: slide.style.color == .white) { editor.setColor(.white) }
                    Swatch(color: .black, selected: slide.style.color == .black) { editor.setColor(.black) }
                    ColorPicker("Custom color", selection: Binding(
                        get: { Color(slide.style.color) },
                        set: { editor.setColor(RGB(NSColor($0))) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
            }
            Row(label: "Image") {
                HStack(spacing: 8) {
                    if let file = slide.style.backgroundImage,
                       let image = MediaCache.shared.image(for: editor.mediaURL(file)) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Button(slide.style.backgroundImage == nil ? "Choose…" : "Replace…") {
                        if let url = FilePanel.pickMedia(multiple: false, imagesOnly: true).first {
                            editor.setBackgroundImage(url)
                        }
                    }
                    if slide.style.backgroundImage != nil {
                        Button(action: editor.clearBackgroundImage) { TablerIcon("x", size: 13) }
                            .buttonStyle(.borderless)
                            .help("Remove background image")
                    }
                }
                .controlSize(.small)
            }
            if slide.style.backgroundImage != nil {
                PixelSlider(label: "Blur", value: slide.style.blur, range: 0...SlideStyle.maxBlur, onChange: { editor.setBlur($0) })
            }
            if slide.layout.slotCount > 1 {
                PixelSlider(label: "Gap", value: slide.style.gap, range: 0...SlideStyle.maxGap, onChange: { editor.setGap($0) })
            }
        }
    }
}

private struct Swatch: View {
    let color: RGB
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.separator, lineWidth: 1))
                .padding(2)
                .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(color == .white ? "White" : "Black")
    }
}

// MARK: - Photo

private struct PhotoCard: View {
    let editor: EditorModel
    let slide: Slide

    var body: some View {
        Card(title: "Photos", icon: "photo") {
            Button(action: editor.pickMediaForCurrentSlide) { TablerIcon("photo-plus", size: 15) }
                .buttonStyle(.borderless)
                .help("Add photos or videos (⌘O)")
        } content: {
            Row(label: "Fit") {
                Picker("Fit", selection: Binding(get: { slide.style.fit }, set: { editor.setFit($0) })) {
                    Text("Fill").tag(Fit.fill)
                    Text("Full").tag(Fit.full)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ForEach(slide.slots.indices, id: \.self) { slot in
                if let media = slide.slots[slot] {
                    AngleSlider(
                        label: slide.mediaCount > 1 ? "Rotate \(slot + 1)" : "Rotate",
                        value: media.crop.angle,
                        onChange: { editor.setAngle($0, slot: slot) }
                    )
                }
            }
            PixelSlider(label: "Border", value: slide.style.border, range: 0...SlideStyle.maxBorder, onChange: { editor.setBorder($0) })
            VStack(alignment: .leading, spacing: 6) {
                Text("Film edge").foregroundStyle(.secondary)
                Picker("Film edge", selection: Binding(get: { slide.style.filmEdge }, set: { editor.setFilmEdge($0) })) {
                    Text("None").tag(FilmEdge?.none)
                    ForEach(FilmEdge.allCases, id: \.self) { Text($0.name).tag(FilmEdge?.some($0)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Fine rotation: the slider moves in 0.1° steps, the field takes any value. Right-click resets.
private struct AngleSlider: View {
    let label: String
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        Row(label: label) {
            Slider(value: Binding(get: { value }, set: { onChange(($0 * 10).rounded() / 10) }), in: -Crop.maxAngle...Crop.maxAngle)
                .controlSize(.small)
            NumberField(value: value, placeholder: "0", suffix: "°", help: "Rotation in degrees, clockwise, ±\(Int(Crop.maxAngle))") { value in
                onChange(value ?? 0)
            }
            .frame(width: 64)
        }
        .contextMenu {
            Button("Reset Rotation") { onChange(0) }.disabled(value == 0)
        }
    }
}

// MARK: - Export

private struct ExportCard: View {
    @Bindable var editor: EditorModel

    var body: some View {
        Card(title: "Export", icon: "download") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Size").foregroundStyle(.secondary)
                Picker("Size", selection: $editor.exportSize) {
                    ForEach(EditorModel.ExportSize.allCases, id: \.self) { size in
                        Text("\(size.name) · \(editor.pixelSize(size))").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(maxWidth: .infinity)
            }
            Button { editor.exportWithPanel() } label: {
                Text("Export \(editor.project.frameCount) \(editor.project.frameCount == 1 ? "Slide" : "Slides")…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

extension RGB {
    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .white
        self.init(r: resolved.redComponent, g: resolved.greenComponent, b: resolved.blueComponent)
    }
}
