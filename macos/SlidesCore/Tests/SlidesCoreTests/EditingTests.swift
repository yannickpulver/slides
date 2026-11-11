import Foundation
import Testing
@testable import SlidesCore

struct EditingTests {
    let a = Media(file: "a.jpg", kind: .image)
    let b = Media(file: "b.jpg", kind: .image)
    let c = Media(file: "c.jpg", kind: .image)
    let d = Media(file: "d.jpg", kind: .image)

    @Test func dropGrowsLayoutUpToThree() {
        var slide = Slide()
        #expect(slide.place([a], at: nil) == 1)
        #expect(slide.layout == .single)
        slide.place([b], at: nil)
        #expect(slide.layout == .two)
        #expect(slide.place([c, d], at: nil) == 1)
        #expect(slide.layout == .three)
        #expect(slide.slots.map { $0?.file } == ["a.jpg", "b.jpg", "c.jpg"])
    }

    @Test func dropOnSlotReplacesAndFillsFollowing() {
        var slide = Slide()
        slide.place([a, b], at: nil)
        slide.place([c, d], at: 0)
        #expect(slide.slots.map { $0?.file } == ["c.jpg", "d.jpg"])
        #expect(slide.layout == .two)
    }

    @Test func chosenLayoutStopsGrowing() {
        var slide = Slide()
        slide.choose(.single)
        slide.place([a], at: nil)
        #expect(slide.place([b], at: nil) == 0)
        #expect(slide.layout == .single)
    }

    @Test func chooseKeepsPhotosInOrderAndResetsCrop() {
        var slide = Slide()
        slide.choose(.three)
        slide.place([a], at: 2)
        slide.slots[2]?.crop = Crop(x: 0.2, zoom: 2)
        slide.choose(.single)
        #expect(slide.slots.map { $0?.file } == ["a.jpg"])
        #expect(slide.slots[0]?.crop == Crop())
    }

    @Test func panoramaTakesOnePhoto() {
        var slide = Slide()
        slide.choose(.two, span: 4)
        #expect(slide.layout == .single)
        #expect(slide.span == 4)
        #expect(slide.place([a, b], at: nil) == 1)
    }

    @Test func moveSlide() {
        var project = Project(name: "Test")
        let first = project.slides[0].id
        let second = project.insertSlide(after: first)
        let third = project.insertSlide(after: second)
        project.moveSlide(first, to: 3)
        #expect(project.slides.map(\.id) == [second, third, first])
        project.moveSlide(first, to: 0)
        #expect(project.slides.map(\.id) == [first, second, third])
        project.moveSlide(third, to: 1)
        #expect(project.slides.map(\.id) == [first, third, second])
    }

    @Test func duplicateSlideCopiesRightAfter() throws {
        var project = Project(name: "Test")
        let first = project.slides[0].id
        let last = project.insertSlide(after: first)
        project.updateSlide(first) {
            $0.place([Media(file: "a", kind: .image)], at: nil)
            $0.style.filmEdge = .gateBlack
            $0.texts = [TextBox(text: "Arolla", x: 0, y: 18)]
        }
        let duplicated = project.duplicateSlide(first)
        let copy = try #require(duplicated)
        #expect(project.slides.map(\.id) == [first, copy, last])
        let original = project.slides[0], duplicate = project.slides[1]
        #expect(duplicate.slots == original.slots)
        #expect(duplicate.style == original.style)
        #expect(duplicate.texts.map(\.text) == ["Arolla"])
        #expect(duplicate.texts[0].id != original.texts[0].id)
    }

    @Test func removeKeepsOneSlide() {
        var project = Project(name: "Test")
        let only = project.slides[0].id
        #expect(project.removeSlide(only) == nil)
        let second = project.insertSlide(after: only)
        #expect(project.removeSlide(second) == only)
        #expect(project.slides.count == 1)
    }

    @Test func unknownFilmEdgeStillDecodes() throws {
        let json = #"{"fit":"fill","border":10,"gap":0,"color":{"r":1,"g":1,"b":1},"blur":0,"filmEdge":"white_thin_1"}"#
        let style = try JSONDecoder().decode(SlideStyle.self, from: Data(json.utf8))
        #expect(style.filmEdge == nil)
        #expect(style.border == 10)
    }

    @Test func frameCountCountsPanoramaParts() {
        var project = Project(name: "Test")
        project.slides[0].choose(.single, span: 3)
        project.insertSlide(after: nil)
        #expect(project.frameCount == 4)
    }
}
