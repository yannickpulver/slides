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
                LayoutCard(editor: editor, slide: slide)
                BackgroundCard(editor: editor, slide: slide)
                PhotoCard(editor: editor, slide: slide)
                ExportCard(editor: editor)
            }
            .padding(16)
        }
    }
}

// MARK: - Layout

private struct LayoutCard: View {
    let editor: EditorModel
    let slide: Slide

    var body: some View {
        Card(title: "Slide \(editor.currentIndex + 1)", icon: "layout-rows") {
            Text(slide.isPanorama ? "Panorama over \(slide.span) slides" : "\(slide.mediaCount) of \(slide.layout.slotCount) photos")
                .foregroundStyle(.secondary)
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
                .background(selected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.accentColor : .secondary)
        .help(help)
    }
}

private struct StackIcon: View {
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in RoundedRectangle(cornerRadius: 1.5).fill(.tint.opacity(0.6)) }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}

private struct PanoramaIcon: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in RoundedRectangle(cornerRadius: 1.5).fill(.tint.opacity(0.6)) }
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
            Text("Film edge").foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                FilmEdgeChip(edge: nil, selected: slide.style.filmEdge == nil) { editor.setFilmEdge(nil) }
                ForEach(FilmEdge.allCases, id: \.self) { edge in
                    FilmEdgeChip(edge: edge, selected: slide.style.filmEdge == edge) { editor.setFilmEdge(edge) }
                }
            }
        }
    }
}

private struct FilmEdgeChip: View {
    let edge: FilmEdge?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color(hex: 0x6B747E)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    GeometryReader { proxy in
                        if let edge, let url = edge.url(landscape: false, preview: true),
                           let image = MediaCache.shared.image(for: url) {
                            // The top-left corner, zoomed in: at chip size the whole edge would be under a pixel.
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .frame(width: proxy.size.width * 4, height: proxy.size.height * 4)
                        } else if edge == nil {
                            TablerIcon("x", size: 12)
                                .foregroundStyle(.white)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(edge?.rawValue.replacingOccurrences(of: "_", with: " ").capitalized ?? "No film edge")
    }
}

// MARK: - Export

private struct ExportCard: View {
    let editor: EditorModel

    var body: some View {
        Card(title: "Export", icon: "download") {
            Button { editor.exportWithPanel() } label: {
                Text("Export \(editor.project.frameCount) \(editor.project.frameCount == 1 ? "Slide" : "Slides")…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            HStack {
                Text("\(editor.pixelSize(.instagram)), the largest size Instagram keeps")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Menu("Other Size") {
                    ForEach(EditorModel.ExportSize.allCases.filter { $0 != .instagram }, id: \.self) { size in
                        Button("\(size.name) · \(editor.pixelSize(size))…") { editor.exportWithPanel(size) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

extension RGB {
    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .white
        self.init(r: resolved.redComponent, g: resolved.greenComponent, b: resolved.blueComponent)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
