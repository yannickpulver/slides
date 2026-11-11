import CoreGraphics
import Testing
@testable import SlidesCore

struct SlideLayoutTests {
    @Test func stackedSlotsShareHeightMinusGaps() {
        var slide = Slide()
        slide.choose(.three)
        slide.style.gap = 32
        let slots = SlideLayout(slide: slide, format: .portrait4x3).slots
        #expect(slots.count == 3)
        #expect(slots[0].height == 320)
        #expect(slots[1].minY == 352)
        #expect(slots[2].maxY == 1024)
    }

    @Test func borderShrinksVisibleArea() {
        var slide = Slide()
        slide.style.border = 40
        let area = SlideLayout(slide: slide, format: .portrait4x3).visibleArea(slot: 0)
        #expect(area == CGRect(x: 40, y: 40, width: 688, height: 944))
    }

    @Test func borderRunsOnceAroundStackedPhotos() {
        var slide = Slide()
        slide.choose(.two)
        slide.style.border = 40
        slide.style.gap = 20
        let slots = SlideLayout(slide: slide, format: .portrait4x3).slots
        #expect(slots[0] == CGRect(x: 40, y: 40, width: 688, height: 462))
        #expect(slots[1] == CGRect(x: 40, y: 522, width: 688, height: 462))
    }

    @Test func panoramaCanvasCoversAllParts() {
        var slide = Slide()
        slide.choose(.single, span: 3)
        let layout = SlideLayout(slide: slide, format: .portrait4x3)
        #expect(layout.canvas.width == 2304)
        #expect(layout.part(2) == CGRect(x: 1536, y: 0, width: 768, height: 1024))
    }

    @Test func fillCoversAndFullFits() {
        let area = CGRect(x: 0, y: 0, width: 100, height: 100)
        let wide = CGSize(width: 200, height: 100)
        let fill = SlideLayout.mediaRect(in: area, mediaSize: wide, fit: .fill, crop: Crop())
        #expect(fill == CGRect(x: -50, y: 0, width: 200, height: 100))
        let full = SlideLayout.mediaRect(in: area, mediaSize: wide, fit: .full, crop: Crop())
        #expect(full == CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    @Test func cropShiftsByShareOfArea() {
        let area = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = SlideLayout.mediaRect(in: area, mediaSize: CGSize(width: 200, height: 100), fit: .fill, crop: Crop(x: 0.25))
        #expect(rect.minX == -25)
    }

    @Test func clampKeepsPhotoCovering() {
        let area = CGRect(x: 0, y: 0, width: 100, height: 100)
        let size = CGSize(width: 200, height: 100)
        let crop = SlideLayout.clampedCrop(Crop(x: 9, y: -9, zoom: 9), in: area, mediaSize: size)
        #expect(crop.zoom == Crop.maxZoom)
        // At zoom 5 the photo is 1000 × 500: 450 overhang each side horizontally, 200 vertically.
        #expect(crop.x == 4.5)
        #expect(crop.y == -2)
        let rect = SlideLayout.mediaRect(in: area, mediaSize: size, fit: .fill, crop: crop)
        #expect(rect.contains(area))
    }

    @Test func storedCropBeyondOverhangStillCovers() {
        let area = CGRect(x: 0, y: 0, width: 100, height: 50)
        let rect = SlideLayout.mediaRect(in: area, mediaSize: CGSize(width: 150, height: 100), fit: .fill, crop: Crop(x: 0.4, y: -3))
        #expect(rect.contains(area))
        // Shifted up as far as it goes: the bottom edges line up.
        #expect(abs(rect.maxY - area.maxY) < 0.001)
    }

    @Test func filmEdgeCoversOnlyVisiblePhoto() {
        var slide = Slide()
        slide.place([Media(file: "a", kind: .image)], at: nil)
        slide.style.fit = .full
        slide.style.border = 40
        let layout = SlideLayout(slide: slide, format: .portrait4x3)
        let rect = layout.filmEdgeRect(mediaSizes: [0: CGSize(width: 2000, height: 1000)])
        #expect(rect.width == 688)
        #expect(rect.height == 344)
    }

    @Test func filmEdgeRunsOnceAroundStackedPhotos() {
        var slide = Slide()
        slide.choose(.two)
        slide.place([Media(file: "a", kind: .image), Media(file: "b", kind: .image)], at: nil)
        slide.style.border = 40
        slide.style.gap = 20
        let size = CGSize(width: 1000, height: 1000)
        let rect = SlideLayout(slide: slide, format: .portrait4x3).filmEdgeRect(mediaSizes: [0: size, 1: size])
        #expect(rect == CGRect(x: 40, y: 40, width: 688, height: 944))
    }
}
