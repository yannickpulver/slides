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

// MARK: - Format

/// Applies to every slide of the project.
private struct FormatCard: View {
    let editor: EditorModel

    var body: some View {
        Card(title: "Format", icon: "aspect-ratio") {
            Row(label: "Ratio") {
                Picker("Format", selection: Binding(get: { editor.project.format }, set: editor.setFormat)) {
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
                PixelSlider(label: "Blur", value: slide.style.blur, range: 0...SlideStyle.maxBlur, onChange: editor.setBlur)
            }
            if slide.layout.slotCount > 1 {
                PixelSlider(label: "Gap", value: slide.style.gap, range: 0...SlideStyle.maxGap, onChange: editor.setGap)
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
                Picker("Fit", selection: Binding(get: { slide.style.fit }, set: editor.setFit)) {
                    Text("Fill").tag(Fit.fill)
                    Text("Full").tag(Fit.full)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            PixelSlider(label: "Border", value: slide.style.border, range: 0...SlideStyle.maxBorder, onChange: editor.setBorder)
            VStack(alignment: .leading, spacing: 6) {
                Text("Film edge").foregroundStyle(.secondary)
                Picker("Film edge", selection: Binding(get: { slide.style.filmEdge }, set: editor.setFilmEdge)) {
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

// MARK: - Export

private struct ExportCard: View {
    @Bindable var editor: EditorModel

    var body: some View {
        Card(title: "Export", icon: "download") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Size").foregroundStyle(.secondary)
                Picker("Size", selection: $editor.exportSize) {
                    ForEach(EditorModel.ExportSize.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(maxWidth: .infinity)
                Text(editor.exportSize == .instagram
                     ? "\(editor.pixelSize(.instagram)) · the largest Instagram keeps"
                     : "\(editor.pixelSize(.large)) · for print or other apps")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
