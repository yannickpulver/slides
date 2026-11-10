import AppKit
import SlidesCore
import SwiftUI

struct Sidebar: View {
    @Bindable var editor: EditorModel

    private var slide: Slide { editor.currentSlide }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    layoutSection
                    canvasSection
                    imageSection
                }
            }
            exportSection
        }
        .frame(width: 240)
        .background(Theme.background)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.outlineSoft).frame(width: 0.5) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Slide \(editor.currentIndex + 1)").font(Theme.font(13, .medium))
            Spacer()
            Text(slide.isPanorama ? "panorama · \(slide.span)" : "\(slide.mediaCount)/\(slide.layout.slotCount) images")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textMuted)
            Button { editor.removeSlide(slide.id) } label: {
                Image(systemName: "trash").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textMuted)
            .disabled(editor.project.slides.count < 2)
            .help("Delete slide")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineSoft).frame(height: 0.5) }
    }

    // MARK: - Layout

    private var layoutSection: some View {
        Section("Layout") {
            Caption("Stack · photos on this slide")
            HStack(spacing: 6) {
                ForEach(Layout.allCases, id: \.self) { layout in
                    LayoutTile(
                        selected: !slide.isPanorama && slide.layout == layout,
                        tile: { StackIcon(count: layout.slotCount) },
                        action: { editor.chooseLayout(layout) }
                    )
                }
            }
            Caption("Panorama · one photo across slides").padding(.top, 6)
            HStack(spacing: 6) {
                ForEach(2...Slide.maxSpan, id: \.self) { span in
                    LayoutTile(
                        selected: slide.span == span,
                        tile: { PanoramaIcon(count: span) },
                        action: { editor.chooseLayout(.single, span: span) }
                    )
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvasSection: some View {
        Section("Canvas") {
            Row("Background") {
                HStack(spacing: 6) {
                    ForEach([RGB.white, .black], id: \.self) { color in
                        Swatch(color: color, selected: slide.style.color == color) { editor.setColor(color) }
                    }
                    let custom = slide.style.color != .white && slide.style.color != .black
                    Button { ColorPanel.shared.show(slide.style.color, onChange: editor.setColor) } label: {
                        Circle()
                            .fill(custom ? AnyShapeStyle(Color(slide.style.color)) : AnyShapeStyle(AngularGradient(
                                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center
                            )))
                            .frame(width: 16, height: 16)
                            .padding(2)
                            .overlay(Circle().strokeBorder(custom ? Theme.text : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .help("Custom color")
                }
            }
            Row("Image") {
                HStack(spacing: 6) {
                    if let file = slide.style.backgroundImage,
                       let image = MediaCache.shared.image(for: editor.mediaURL(file)) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    SmallButton(slide.style.backgroundImage == nil ? "Pick" : "Replace") {
                        if let url = FilePanel.pickMedia(multiple: false, imagesOnly: true).first {
                            editor.setBackgroundImage(url)
                        }
                    }
                    if slide.style.backgroundImage != nil {
                        Button(action: editor.clearBackgroundImage) {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                        .help("Remove background image")
                    }
                }
            }
            if slide.style.backgroundImage != nil {
                ValueSlider(label: "Blur", value: slide.style.blur, range: 0...SlideStyle.maxBlur, onChange: editor.setBlur)
            }
            if slide.layout.slotCount > 1 {
                ValueSlider(label: "Gap", value: slide.style.gap, range: 0...SlideStyle.maxGap, onChange: editor.setGap)
            }
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        Section("Image") {
            Row("Fit") {
                Segmented(
                    options: [Fit.fill, .full],
                    selection: slide.style.fit,
                    label: { $0 == .fill ? "Fill" : "Full" },
                    onSelect: editor.setFit
                )
            }
            ValueSlider(label: "Border", value: slide.style.border, range: 0...SlideStyle.maxBorder, onChange: editor.setBorder)
            Caption("Film edge").padding(.top, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(27), spacing: 6), count: 6), alignment: .leading, spacing: 6) {
                FilmEdgeChip(edge: nil, selected: slide.style.filmEdge == nil) { editor.setFilmEdge(nil) }
                ForEach(FilmEdge.allCases, id: \.self) { edge in
                    FilmEdgeChip(edge: edge, selected: slide.style.filmEdge == edge) { editor.setFilmEdge(edge) }
                }
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Export")
            Row("Scale") {
                Segmented(options: [1, 2, 3], selection: editor.exportScale, label: { "\($0)x" }) { editor.exportScale = $0 }
            }
            Button {
                if let folder = FilePanel.pickFolder() { editor.export(to: folder) }
            } label: {
                Label("Export \(editor.project.frameCount) \(editor.project.frameCount == 1 ? "slide" : "slides")", systemImage: "square.and.arrow.down")
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.outlineSoft).frame(height: 0.5) }
    }
}

// MARK: - Building blocks

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title).padding(.bottom, 2)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineSoft).frame(height: 0.5) }
    }
}

private struct Row<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label).font(Theme.font(11)).foregroundStyle(Theme.textMuted)
            Spacer()
            content
        }
        .frame(minHeight: 24)
    }
}

private struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(Theme.font(10)).foregroundStyle(Theme.textMuted.opacity(0.7))
    }
}

private struct ValueSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(Theme.font(11)).foregroundStyle(Theme.textMuted).frame(width: 44, alignment: .leading)
            Slider(value: Binding(get: { value }, set: { onChange($0.rounded()) }), in: range)
                .controlSize(.mini)
            Text("\(Int(value))")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text)
                .frame(width: 26, alignment: .trailing)
            Text("px").font(Theme.mono(9)).foregroundStyle(Theme.textMuted.opacity(0.6))
        }
    }
}

private struct SmallButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(10, .medium))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.outline, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(Theme.outline, lineWidth: 1))
                .padding(2)
                .overlay(Circle().strokeBorder(selected ? Theme.text : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct LayoutTile<Tile: View>: View {
    let selected: Bool
    @ViewBuilder let tile: () -> Tile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            tile()
                .padding(5)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Theme.text : Theme.outline, lineWidth: selected ? 1.5 : 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct StackIcon: View {
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1).fill(Theme.textMuted.opacity(0.7))
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}

private struct PanoramaIcon: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1).fill(Theme.textMuted.opacity(0.7))
            }
        }
        .frame(height: 16)
    }
}

private struct FilmEdgeChip: View {
    let edge: FilmEdge?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(Color(hex: 0x7A8A99))
                if let edge, let url = edge.url(landscape: false, preview: true),
                   let image = MediaCache.shared.image(for: url) {
                    Image(decorative: image, scale: 1).resizable()
                } else if edge == nil {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .frame(width: 27, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(selected ? Theme.text : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help(edge?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "No film edge")
    }
}

extension RGB {
    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .white
        self.init(r: resolved.redComponent, g: resolved.greenComponent, b: resolved.blueComponent)
    }
}

/// The system color panel, reporting picks back to the open slide.
@MainActor
final class ColorPanel: NSObject {
    static let shared = ColorPanel()
    private var onChange: ((RGB) -> Void)?

    func show(_ color: RGB, onChange: @escaping (RGB) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.color = NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: 1)
        panel.orderFront(nil)
    }

    @objc private func changed(_ panel: NSColorPanel) {
        onChange?(RGB(panel.color))
    }
}
