import CoreGraphics
import Foundation
import Testing
@testable import SlidesCore

struct TextTests {
    @Test func slideWithoutTextsStillDecodes() throws {
        var slide = Slide()
        slide.addText(TextBox(text: "Hi", x: 1, y: 2))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(slide)) as! [String: Any]
        json.removeValue(forKey: "freeItems")
        let old = try JSONDecoder().decode(Slide.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.texts.isEmpty && old.id == slide.id)

        let roundTrip = try JSONDecoder().decode(Slide.self, from: JSONEncoder().encode(slide))
        #expect(roundTrip == slide)
    }

    @Test func autoWidthGrowsWithTheText() {
        let short = TextRenderer.size(of: TextBox(text: "Hi", x: 0, y: 0))
        let long = TextRenderer.size(of: TextBox(text: "Hello there, world", x: 0, y: 0))
        #expect(long.width > short.width * 3)
        #expect(long.height == short.height)
    }

    @Test func centeredAutoWidthGrowsToBothSides() {
        var box = TextBox(text: "Hi", x: 100, y: 0)
        box.alignment = .center
        let center = TextRenderer.rect(of: box).midX
        box.setText("Hello there, world")
        #expect(abs(TextRenderer.rect(of: box).midX - center) < 0.01)

        box.alignment = .right
        let right = TextRenderer.rect(of: box).maxX
        box.setText("Hi")
        #expect(abs(TextRenderer.rect(of: box).maxX - right) < 0.01)
    }

    @Test func fixedWidthWraps() {
        let box = TextBox(text: "Hello there, world, this wraps", x: 0, y: 0, width: 200)
        let size = TextRenderer.size(of: box)
        let oneLine = TextRenderer.size(of: TextBox(text: "Hello", x: 0, y: 0))
        #expect(size.width == 200)
        #expect(size.height > oneLine.height * 2)
    }

    @Test func emptyTextKeepsOneLine() {
        #expect(TextRenderer.size(of: TextBox(text: "", x: 0, y: 0)).height > 40)
    }

    @Test func lineHeightSetsTheLineDistance() {
        var box = TextBox(text: "a\nb\nc", x: 0, y: 0)
        box.lineHeight = 200
        #expect(abs(TextRenderer.size(of: box).height - 3 * 128) <= 1)
    }

    @Test func rendererDrawsTextOverThePhotos() {
        var slide = Slide()
        var box = TextBox(text: "████", x: 100, y: 400)
        box.size = 120
        box.font = "Menlo-Regular"
        slide.addText(box)
        let rect = TextRenderer.rect(of: box)
        let renderer = SlideRenderer(layout: SlideLayout(slide: slide, format: .portrait4x3), scale: 1, images: [:], background: nil)
        let image = renderer.render(part: 0)!
        #expect(image.pixel(x: Int(rect.midX), y: Int(rect.midY)) == (0, 0, 0))
        #expect(image.pixel(x: Int(rect.midX), y: Int(rect.minY) - 20) == (255, 255, 255))
    }

    @Test func opacityBlendsTheTextWithTheSlide() throws {
        var slide = Slide()
        var box = TextBox(text: "████", x: 100, y: 400)
        box.size = 120
        box.font = "Menlo-Regular"
        box.opacity = 50
        slide.addText(box)
        let rect = TextRenderer.rect(of: box)
        let renderer = SlideRenderer(layout: SlideLayout(slide: slide, format: .portrait4x3), scale: 1, images: [:], background: nil)
        // At the seam between two glyphs, where they overlap: still one layer of 50 %.
        let pixel = renderer.render(part: 0)!.pixel(x: Int(rect.midX), y: Int(rect.midY))
        #expect((120...135).contains(pixel.0) && pixel.0 == pixel.1 && pixel.1 == pixel.2, "\(pixel)")

        // Boxes from before opacity open fully opaque.
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(box)) as! [String: Any]
        json.removeValue(forKey: "opacity")
        #expect(try JSONDecoder().decode(TextBox.self, from: JSONSerialization.data(withJSONObject: json)).opacity == 100)
    }

    @Test func panoramaTextCrossesTheCut() {
        var slide = Slide()
        slide.choose(.single, span: 2)
        var box = TextBox(text: "██████", x: 600, y: 400)
        box.font = "Menlo-Regular"
        box.size = 120
        slide.addText(box)
        let renderer = SlideRenderer(layout: SlideLayout(slide: slide, format: .portrait4x3), scale: 1, images: [:], background: nil)
        let rect = TextRenderer.rect(of: box)
        #expect(rect.maxX > 800)
        #expect(renderer.render(part: 0)!.pixel(x: 760, y: Int(rect.midY)) == (0, 0, 0))
        #expect(renderer.render(part: 1)!.pixel(x: 10, y: Int(rect.midY)) == (0, 0, 0))
    }
}
