import AppKit
import CoreText
import SwiftUI

/// Dark gray palette and Miranda Sans, as in the original app.
enum Theme {
    static let background = Color(hex: 0x0E0E0F)
    static let canvas = Color(hex: 0x0A0A0B)
    static let surface = Color(hex: 0x17171A)
    static let surfaceHigh = Color(hex: 0x1D1D20)
    static let outline = Color(hex: 0x2A2A2E)
    static let outlineSoft = Color(hex: 0x232327)
    static let text = Color(hex: 0xEDEDEF)
    static let textMuted = Color(hex: 0x8E8E93)
    static let emptySlot = Color(hex: 0xF5F5F5)

    static let fontFamily = "Miranda Sans"

    static func font(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        .custom(fontFamily, size: size).weight(weight)
    }

    static func mono(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Registers the bundled Miranda Sans files for this process.
    static func registerFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
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

/// Small uppercase section label.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(9, .semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.textMuted.opacity(0.7))
    }
}
