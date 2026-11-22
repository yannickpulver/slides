import CoreGraphics
import CoreImage

/// Output sharpening for photos that the export draws smaller than their file, like Lightroom's "Sharpen for Screen".
public enum Sharpening: String, CaseIterable, Sendable {
    case off, low, standard, high

    public var name: String { rawValue.capitalized }

    var amount: Double {
        switch self {
        case .off: 0
        case .low: 0.3
        case .standard: 0.6
        case .high: 1
        }
    }

    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!])

    /// Sharpens a photo shrunk from `fullLongSide` pixels to its current size. Barely shrunk photos get less,
    /// full strength from half size down. Sharpens brightness only, so edges get no color fringes.
    public func apply(to image: CGImage, fullLongSide: Double) -> CGImage {
        let ratio = fullLongSide / Double(max(image.width, image.height))
        let amount = amount * min(max(ratio - 1, 0), 1)
        guard amount > 0 else { return image }
        let input = CIImage(cgImage: image)
        let output = input
            .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: amount, kCIInputRadiusKey: 1])
            .cropped(to: input.extent)
        let format: CIFormat = image.bitsPerComponent > 8 ? .RGBA16 : .RGBA8
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return Self.context.createCGImage(output, from: input.extent, format: format, colorSpace: colorSpace) ?? image
    }
}
