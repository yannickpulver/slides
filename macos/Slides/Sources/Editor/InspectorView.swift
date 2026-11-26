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
                if let photo = editor.selectedPhoto {
                    FreePhotoCard(editor: editor, photo: photo)
                }
                FormatCard(editor: editor)
                LayoutCard(editor: editor, slide: slide)
                BackgroundCard(editor: editor, slide: slide)
                PhotoCard(editor: editor, slide: slide)
                CameraCard(editor: editor, slide: slide)
                FreePhotosCard(editor: editor)
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
            FontFamilyPicker(selection: family) { newFamily in
                let current = members.first { $0.postScript == box.font }?.style
                let options = Fonts.members(of: newFamily)
                let pick = options.first { $0.style == current } ?? options.first { $0.style == "Regular" } ?? options.first
                if let pick { style { $0.font = pick.postScript } }
            }
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
            Row(label: "Opacity") {
                Slider(value: Binding(get: { box.opacity }, set: { value in style("opacity") { $0.opacity = value.rounded() } }), in: 0...100)
                    .controlSize(.small)
                NumberField(value: box.opacity, placeholder: "100", suffix: "%", help: "Opacity in %") { value in
                    style { $0.opacity = min(max(value ?? 100, 0), 100) }
                }
                .frame(width: 64)
            }
            Row(label: "Align") {
                Segmented(
                    segments: SlidesCore.TextAlignment.allCases.map { .init(value: $0, icon: "align-\($0.rawValue)") },
                    selection: box.alignment,
                    minSegmentWidth: 30
                ) { alignment in style { $0.alignment = alignment } }
            }
            Row(label: "Width") {
                Segmented(segments: [.init(value: false, title: "Auto"), .init(value: true, title: "Fixed")], selection: box.width != nil) { fixed in
                    let width = TextRenderer.size(of: box).width
                    editor.updateText(box.id) { $0.width = fixed ? width : nil }
                }
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

/// Segmented control backed by AppKit. SwiftUI's segmented picker re-measures its segments
/// on updates and shifts by a few points, which shows while a slider redraws the inspector.
struct Segmented<Value: Equatable>: NSViewRepresentable {
    struct Segment {
        let value: Value
        var title: String?
        /// Tabler icon name.
        var icon: String?
    }

    let segments: [Segment]
    let selection: Value
    /// Stretches over the offered width; otherwise as wide as its widest label needs.
    var fill = false
    /// Icon segments are only as wide as the icon otherwise.
    var minSegmentWidth: CGFloat = 0
    /// Equal segments need the widest label times the count; proportional ones fit long labels in a narrow column.
    var distribution = NSSegmentedControl.Distribution.fillEqually
    let onPick: (Value) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = segments.count
        control.trackingMode = .selectOne
        control.segmentDistribution = distribution
        control.target = context.coordinator
        control.action = #selector(Coordinator.picked(_:))
        for (index, segment) in segments.enumerated() {
            if let title = segment.title { control.setLabel(title, forSegment: index) }
            if let icon = segment.icon, let source = NSImage(named: "ti-\(icon)")?.copy() as? NSImage {
                source.size = NSSize(width: 14, height: 14)
                source.isTemplate = true
                control.setImage(source, forSegment: index)
            }
        }
        return control
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView control: NSSegmentedControl, context: Context) -> CGSize? {
        var fitting = control.fittingSize
        fitting.width = max(fitting.width, minSegmentWidth * CGFloat(segments.count))
        guard fill, let width = proposal.width, width.isFinite else { return fitting }
        return CGSize(width: max(width, fitting.width), height: fitting.height)
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.pick = { index in onPick(segments[index].value) }
        control.selectedSegment = segments.firstIndex { $0.value == selection } ?? -1
    }

    final class Coordinator: NSObject {
        var pick: (Int) -> Void = { _ in }

        @objc func picked(_ sender: NSSegmentedControl) {
            if sender.selectedSegment >= 0 { pick(sender.selectedSegment) }
        }
    }
}

/// Font family menu: each family shown in its own typeface, recently picked ones on top.
private struct FontFamilyPicker: NSViewRepresentable {
    let selection: String
    let onPick: (String) -> Void

    @AppStorage("recentFontFamilies") private var recentRaw = ""

    private var recent: [String] {
        recentRaw.split(separator: "\n").map(String.init).filter(Fonts.families.contains)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.picked(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // The button itself shows the name in the system font; only the menu previews the typefaces.
        if let cell = button.cell as? NSPopUpButtonCell {
            cell.usesItemFromMenu = false
            cell.menuItem = NSMenuItem()
        }
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        let recent = recent
        coordinator.pick = { family in
            recentRaw = ([family] + recent.filter { $0 != family }).prefix(5).joined(separator: "\n")
            onPick(family)
        }
        if coordinator.builtFor != recent {
            coordinator.builtFor = recent
            let menu = NSMenu()
            for family in recent { menu.addItem(Self.item(family)) }
            if !recent.isEmpty { menu.addItem(.separator()) }
            for family in Fonts.families { menu.addItem(Self.item(family)) }
            button.menu = menu
        }
        let index = button.itemArray.firstIndex { $0.representedObject as? String == selection }
        button.selectItem(at: index ?? -1)
        (button.cell as? NSPopUpButtonCell)?.menuItem?.title = selection
    }

    private static func item(_ family: String) -> NSMenuItem {
        let item = NSMenuItem(title: family, action: nil, keyEquivalent: "")
        item.representedObject = family
        if let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: NSFont.systemFontSize),
           family.unicodeScalars.allSatisfy({ $0 == " " || font.coveredCharacterSet.contains($0) }) {
            item.attributedTitle = NSAttributedString(string: family, attributes: [.font: font])
        }
        return item
    }

    final class Coordinator: NSObject {
        var builtFor: [String]?
        var pick: (String) -> Void = { _ in }

        @objc func picked(_ sender: NSPopUpButton) {
            if let family = sender.selectedItem?.representedObject as? String { pick(family) }
        }
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
            Segmented(segments: Format.allCases.map { .init(value: $0, title: $0.label) }, selection: editor.project.format, fill: true) { editor.setFormat($0) }
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
            Text(slide.isPanorama ? "\(slide.span) parts" : "\(slide.mediaCount) of \(slide.slotCount)")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(-1)
        } content: {
            // A menu picker writes its value back on its own when it appears; acting on that
            // would end a grid or a panorama and drop photos, so only a different value counts.
            Row(label: "Rows") {
                Picker("Rows", selection: Binding(get: { slide.layout }, set: { if $0 != slide.layout { editor.chooseLayout($0, columns: slide.columns) } })) {
                    ForEach(Layout.allCases, id: \.self) { layout in
                        Text(layout.slotCount == 1 ? "1 row" : "\(layout.slotCount) rows").tag(layout)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(width: 110)
            }
            Row(label: "Columns") {
                Picker("Columns", selection: Binding(get: { slide.columns }, set: { if $0 != slide.columns { editor.chooseLayout(slide.layout, columns: $0) } })) {
                    ForEach(1...Slide.maxColumns, id: \.self) { Text($0 == 1 ? "1 column" : "\($0) columns").tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(width: 110)
            }
            Row(label: "Panorama") {
                Picker("Panorama", selection: Binding(get: { slide.span }, set: { if $0 != slide.span { editor.chooseLayout(.single, span: $0) } })) {
                    Text("Off").tag(1)
                    ForEach(2...Slide.maxSpan, id: \.self) { Text("\($0) slides").tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(width: 110)
            }
        }
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
                Segmented(segments: [.init(value: Fit.fill, title: "Fill"), .init(value: Fit.full, title: "Full")], selection: slide.style.fit) { editor.setFit($0) }
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
                Segmented(
                    segments: [.init(value: nil, title: "None")] + FilmEdge.allCases.map { .init(value: Optional($0), title: $0.name) },
                    selection: slide.style.filmEdge,
                    fill: true
                ) { editor.setFilmEdge($0) }
            }
            Row(label: "Show crop", labelWidth: nil) {
                Toggle("", isOn: Binding(get: { slide.style.showCrop }, set: { editor.setShowCrop($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Whole photo, dimmed, with the crop as a box and thirds. Also in the export.")
            }
        }
    }
}

/// Camera, lens and exposure of the slide's photos, or of the selected free photo.
/// Hidden when no file says.
private struct CameraCard: View {
    let editor: EditorModel
    let slide: Slide

    private var infos: [CameraInfo] {
        let files = editor.selectedPhoto.map { [$0.file] }
            ?? slide.slots.compactMap { $0?.kind == .image ? $0?.file : nil }
        return files
            .map { MediaCache.shared.camera(for: editor.mediaURL($0)) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        let infos = infos
        if !infos.isEmpty {
            Card(title: "Camera", icon: "camera") {
                ForEach(infos.indices, id: \.self) { index in
                    if index > 0 { Divider() }
                    CameraDetails(info: infos[index])
                }
            }
        }
    }
}

/// Like the info panel in Photos: body in bold, lens below, exposure in a strip.
private struct CameraDetails: View {
    let info: CameraInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let camera = info.camera {
                    Text(camera).fontWeight(.semibold)
                }
                if let lens = info.lens {
                    Text(lens).foregroundStyle(.secondary)
                }
            }
            // Wraps instead of widening the inspector.
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(-1)
            .textSelection(.enabled)
            if !info.exposure.isEmpty {
                HStack(spacing: 0) {
                    ForEach(info.exposure.indices, id: \.self) { index in
                        if index > 0 {
                            Spacer(minLength: 4)
                            Divider().frame(height: 12)
                            Spacer(minLength: 4)
                        }
                        Text(info.exposure[index])
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .font(.callout)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

/// Fine rotation: the slider moves in 0.1° steps, the field takes any value. Right-click resets.
private struct AngleSlider: View {
    let label: String
    let value: Double
    var limit = Crop.maxAngle
    let onChange: (Double) -> Void

    var body: some View {
        Row(label: label) {
            Slider(value: Binding(get: { value }, set: { onChange(($0 * 10).rounded() / 10) }), in: -limit...limit)
                .controlSize(.small)
            NumberField(value: value, placeholder: "0", suffix: "°", help: "Rotation in degrees, clockwise, ±\(Int(limit))") { value in
                onChange(value ?? 0)
            }
            .frame(width: 64)
        }
        .contextMenu {
            Button("Reset Rotation") { onChange(0) }.disabled(value == 0)
        }
    }
}

// MARK: - Free photos

/// Adds free photos to the selected slide.
private struct FreePhotosCard: View {
    let editor: EditorModel

    var body: some View {
        Card(title: "Free Photos", icon: "library-photo") {
            Button(action: editor.pickFreePhotos) {
                Label { Text("Add Free Photo…") } icon: { TablerIcon("photo-plus", size: 14) }
                    .frame(maxWidth: .infinity)
            }
            if editor.selectedPhoto == nil {
                Text("Placed in the middle. Drag to move, corners to resize.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The selected free photo: rotation, photo frame and order.
private struct FreePhotoCard: View {
    let editor: EditorModel
    let photo: FreePhoto

    private func update(_ key: String? = nil, _ change: @escaping (inout FreePhoto) -> Void) {
        editor.updatePhoto(photo.id, key, change)
    }

    var body: some View {
        let frame = photo.frame
        Card(title: "Free Photo", icon: "library-photo") {
            Button { editor.removePhoto(photo.id) } label: { TablerIcon("trash", size: 15) }
                .buttonStyle(.borderless)
                .help("Delete photo (⌫)")
        } content: {
            AngleSlider(label: "Rotate", value: photo.angle, limit: 180) { angle in
                update("angle") { $0.angle = angle }
            }
            Row(label: "Frame") {
                HStack(spacing: 8) {
                    NoFrameSwatch(selected: frame == nil) { update { $0.frame = nil } }
                    Swatch(color: .white, selected: frame?.color == .white) { update { $0.frame = PhotoFrame(width: $0.frame?.width ?? 16, color: .white) } }
                    Swatch(color: .black, selected: frame?.color == .black) { update { $0.frame = PhotoFrame(width: $0.frame?.width ?? 16, color: .black) } }
                    ColorPicker("Frame color", selection: Binding(
                        get: { Color(frame?.color ?? .white) },
                        set: { color in update("frame-color") { $0.frame = PhotoFrame(width: $0.frame?.width ?? 16, color: RGB(NSColor(color))) } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
            }
            if let frame {
                PixelSlider(label: "Width", value: frame.width, range: 1...PhotoFrame.maxWidth) { width in
                    update("frame-width") { $0.frame?.width = width }
                }
            }
            Row(label: "Order") {
                HStack(spacing: 6) {
                    Button { editor.arrange(photo.id, by: -1) } label: {
                        Text("Back").frame(maxWidth: .infinity)
                    }
                    .help("Send Backward (⌥⌘[)")
                    Button { editor.arrange(photo.id, by: 1) } label: {
                        Text("Forward").frame(maxWidth: .infinity)
                    }
                    .help("Bring Forward (⌥⌘])")
                }
                .controlSize(.small)
            }
        }
    }
}

/// "No frame": a gray circle crossed out in red.
private struct NoFrameSwatch: View {
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.quaternary)
                .frame(width: 18, height: 18)
                .overlay(Rectangle().fill(.red).frame(width: 1.5).rotationEffect(.degrees(45)))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.separator, lineWidth: 1))
                .padding(2)
                .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help("No frame")
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Sharpening").foregroundStyle(.secondary)
                Segmented(
                    segments: Sharpening.allCases.map { .init(value: $0, title: $0.name) },
                    selection: editor.exportSharpening,
                    fill: true,
                    distribution: .fillProportionally
                ) { editor.exportSharpening = $0 }
                .help("Sharpens photos that are exported smaller than their original")
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
