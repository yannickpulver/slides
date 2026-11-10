import SwiftUI

/// Tabler icon from the asset catalog, tinted like text.
struct TablerIcon: View {
    let name: String
    var size: CGFloat = 16

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("ti-\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// A titled group: icon and title above a rounded panel.
struct Card<Content: View, Accessory: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                TablerIcon(icon).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Spacer()
                accessory
            }
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

extension Card where Accessory == EmptyView {
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, icon: icon, accessory: { EmptyView() }, content: content)
    }
}

/// Label in a fixed column on the left, control on the right.
struct Row<Control: View>: View {
    let label: String
    var labelWidth: CGFloat? = 70
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
                .fixedSize(horizontal: labelWidth == nil, vertical: false)
            Spacer(minLength: 0)
            control
        }
        .frame(minHeight: 22)
    }
}

/// Slider with its value in pixels.
struct PixelSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void

    var body: some View {
        Row(label: label) {
            Slider(value: Binding(get: { value }, set: { onChange($0.rounded()) }), in: range)
                .controlSize(.small)
            Text("\(Int(value)) px")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
