import CoreGraphics
import Testing
@testable import SlidesCore

struct SharpeningTests {
    /// Dark gray left, light gray right: sharpening darkens the dark side next to the edge and brightens the light side.
    private let edge: CGImage = {
        let context = SlideRenderer.makeContext(width: 100, height: 20)!
        context.setFillColor(RGB(r: 0.3, g: 0.3, b: 0.3).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 50, height: 20))
        context.setFillColor(RGB(r: 0.7, g: 0.7, b: 0.7).cgColor)
        context.fill(CGRect(x: 50, y: 0, width: 50, height: 20))
        return context.makeImage()!
    }()

    /// How far the pixels beside the edge move away from the flat areas.
    private func overshoot(_ image: CGImage) -> Int {
        let dark = Int(edge.pixel(x: 10, y: 10).r) - Int(image.pixel(x: 49, y: 10).r)
        let light = Int(image.pixel(x: 50, y: 10).r) - Int(edge.pixel(x: 90, y: 10).r)
        return dark + light
    }

    @Test func shrunkPhotoGetsSharperWithEachLevel() {
        let levels = [Sharpening.low, .standard, .high].map { overshoot($0.apply(to: edge, fullLongSide: 400)) }
        #expect(levels[0] > 0)
        #expect(levels[0] < levels[1] && levels[1] < levels[2])
    }

    @Test func offOrFullSizeStaysUntouched() {
        #expect(Sharpening.off.apply(to: edge, fullLongSide: 400) === edge)
        #expect(Sharpening.high.apply(to: edge, fullLongSide: 100) === edge)
    }

    @Test func barelyShrunkGetsLess() {
        let barely = overshoot(Sharpening.standard.apply(to: edge, fullLongSide: 120))
        let half = overshoot(Sharpening.standard.apply(to: edge, fullLongSide: 200))
        #expect(barely < half)
    }

    @Test func exportSharpensShrunkPhotos() async throws {
        let folder = Fixtures.tempFolder()
        // 4× the slide's pixels, so the export shrinks it.
        let big = Fixtures.writePNG(Fixtures.halves(width: 3072, height: 4096), named: "big.png", in: folder)
        var project = Project(name: "Test")
        project.slides[0].place([Media(file: "big.png", kind: .image)], at: nil)

        let soft = await Exporter(project: project, scale: 1, sharpening: .off) { _ in big }.render(slideAt: 0)[0]
        let sharp = await Exporter(project: project, scale: 1, sharpening: .high) { _ in big }.render(slideAt: 0)[0]
        let row = 512
        let differs = (370...398).contains { soft.pixel(x: $0, y: row) != sharp.pixel(x: $0, y: row) }
        #expect(differs)
        #expect(sharp.pixel(x: 100, y: row) == (255, 0, 0))
    }
}
