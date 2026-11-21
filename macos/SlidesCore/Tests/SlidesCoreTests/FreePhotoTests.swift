import CoreGraphics
import Foundation
import Testing
@testable import SlidesCore

struct FreePhotoTests {
    @Test func projectWithTextsOpensAsFreeItems() throws {
        var slide = Slide()
        slide.addText(TextBox(text: "Hi", x: 1, y: 2))
        slide.addFreePhoto(FreePhoto(file: "a.jpg", x: 100, y: 100, width: 200, aspect: 1.5))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(slide)) as! [String: Any]
        // Before free photos a slide kept only `texts`.
        json.removeValue(forKey: "freeItems")
        json["texts"] = [try JSONSerialization.jsonObject(with: JSONEncoder().encode(TextBox(text: "Old", x: 5, y: 6)))]
        let old = try JSONDecoder().decode(Slide.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.texts.map(\.text) == ["Old"])
        #expect(old.freePhotos.isEmpty)

        let roundTrip = try JSONDecoder().decode(Slide.self, from: JSONEncoder().encode(slide))
        #expect(roundTrip == slide)
    }

    @Test func freePhotoDrawsWholeWithItsFrameAboveTheSlots() {
        var slide = Slide()
        slide.place([Media(file: "blue", kind: .image)], at: nil)
        var photo = FreePhoto(file: "red", x: 384, y: 512, width: 200, aspect: 1)
        photo.frame = PhotoFrame(width: 20, color: .white)
        slide.addFreePhoto(photo)
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: .portrait4x3),
            scale: 1,
            images: [
                "blue": Fixtures.image(width: 300, height: 400, color: RGB(r: 0, g: 0, b: 1)),
                "red": Fixtures.image(width: 100, height: 100, color: RGB(r: 1, g: 0, b: 0)),
            ],
            background: nil
        )
        let image = renderer.render(part: 0)!
        #expect(image.pixel(x: 384, y: 512) == (255, 0, 0))
        // The frame: 20 px of white around the 200 px photo.
        #expect(image.pixel(x: 384 - 110, y: 512) == (255, 255, 255))
        #expect(image.pixel(x: 384 - 125, y: 512) == (0, 0, 255))
    }

    @Test func textAboveAPhotoCoversIt() {
        var slide = Slide()
        slide.addFreePhoto(FreePhoto(file: "red", x: 384, y: 512, width: 600, aspect: 1))
        var box = TextBox(text: "█████", x: 100, y: 450)
        box.color = .black
        box.size = 120
        slide.addText(box)
        let images = ["red": Fixtures.image(width: 100, height: 100, color: RGB(r: 1, g: 0, b: 0))]
        let renderer = SlideRenderer(layout: SlideLayout(slide: slide, format: .portrait4x3), scale: 1, images: images, background: nil)
        let rect = TextRenderer.rect(of: box)
        let point = (x: Int(rect.minX + 30), y: Int(rect.midY))
        #expect(renderer.render(part: 0)!.pixel(x: point.x, y: point.y) == (0, 0, 0))

        slide.arrangeFreeItem(box.id, by: -1)
        let behind = SlideRenderer(layout: SlideLayout(slide: slide, format: .portrait4x3), scale: 1, images: images, background: nil)
        #expect(behind.render(part: 0)!.pixel(x: point.x, y: point.y) == (255, 0, 0))
    }

    @Test func turnedPhotoContainsItsCornersOnly() {
        var photo = FreePhoto(file: "a", x: 100, y: 100, width: 100, aspect: 1)
        photo.frame = nil
        photo.angle = 45
        #expect(photo.contains(CGPoint(x: 100, y: 165)))
        #expect(!photo.contains(CGPoint(x: 148, y: 148)))
        #expect(photo.corners[0].y < 30)
    }

    @Test func mediaFilesKeepFreePhotos() {
        var project = Project(name: "Test")
        project.slides[0].addFreePhoto(FreePhoto(file: "free.jpg", x: 0, y: 0, width: 100, aspect: 1))
        #expect(project.mediaFiles.contains("free.jpg"))
    }

    @Test func shorterPanoramaKeepsFreeItemsOnTheCanvas() {
        var project = Project(name: "Test")
        project.slides[0].choose(.single, span: 3)
        let id = project.slides[0].addFreePhoto(FreePhoto(file: "a", x: 2000, y: 500, width: 200, aspect: 1))
        project.slides[0].choose(.single, span: 2)
        project.keepFreeItemsOnCanvas()
        let photo = project.slides[0].freePhotos.first { $0.id == id }!
        #expect(photo.x == project.format.width * 2)
        #expect(photo.y == 500)
    }

    @Test func duplicatedSlideGetsNewFreeItemIDs() {
        var project = Project(name: "Test")
        project.slides[0].addFreePhoto(FreePhoto(file: "a", x: 0, y: 0, width: 100, aspect: 1))
        let copy = project.duplicateSlide(project.slides[0].id)!
        let original = project.slides[0].freeItems[0].id
        #expect(project.slides[project.index(of: copy)!].freeItems[0].id != original)
    }
}
