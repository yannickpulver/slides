@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import SlidesCore

struct RenderTests {
    @Test func borderShowsSlideColor() {
        var slide = Slide()
        slide.place([Media(file: "red", kind: .image)], at: nil)
        slide.style.border = 100
        slide.style.color = .black
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: .portrait4x3),
            scale: 1,
            images: ["red": Fixtures.image(width: 300, height: 400, color: RGB(r: 1, g: 0, b: 0))],
            background: nil
        )
        let image = renderer.render(part: 0)!
        #expect(image.width == 768 && image.height == 1024)
        #expect(image.pixel(x: 50, y: 50) == (0, 0, 0))
        #expect(image.pixel(x: 384, y: 512) == (255, 0, 0))
    }

    @Test func scaleMultipliesPixels() {
        let renderer = SlideRenderer(layout: SlideLayout(slide: Slide(), format: .portrait16x9), scale: 2, images: [:], background: nil)
        let image = renderer.render(part: 0)!
        #expect(image.width == 1152 && image.height == 2048)
        #expect(image.pixel(x: 10, y: 10) == (255, 255, 255))
    }

    @Test func panoramaPartsSplitOnePhoto() {
        var slide = Slide()
        slide.choose(.single, span: 2)
        slide.place([Media(file: "halves", kind: .image)], at: nil)
        // Two 4:3 frames make a 1536 × 1024 (3:2) canvas; the 3:2 photo fits exactly.
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: .portrait4x3),
            scale: 1,
            images: ["halves": Fixtures.halves(width: 600, height: 400)],
            background: nil
        )
        let left = renderer.render(part: 0)!
        let right = renderer.render(part: 1)!
        #expect(left.pixel(x: 384, y: 512) == (255, 0, 0))
        #expect(right.pixel(x: 384, y: 512) == (0, 0, 255))
    }

    @Test func backgroundImageBlursWithoutLosingSize() {
        var slide = Slide()
        slide.style.backgroundImage = "bg"
        slide.style.blur = 40
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: .portrait4x3),
            scale: 1,
            images: [:],
            background: Fixtures.halves(width: 400, height: 400)
        )
        let image = renderer.render(part: 0)!
        // Far from the seam stays pure, the seam blends.
        #expect(image.pixel(x: 10, y: 512).r > 240)
        let seam = image.pixel(x: 384, y: 512)
        #expect(seam.r > 60 && seam.b > 60)
    }

    @Test func filmEdgeDraws() {
        var slide = Slide()
        slide.place([Media(file: "red", kind: .image)], at: nil)
        slide.style.filmEdge = .gateBlack
        let renderer = SlideRenderer(
            layout: SlideLayout(slide: slide, format: .portrait4x3),
            scale: 1,
            images: ["red": Fixtures.image(width: 300, height: 400, color: RGB(r: 1, g: 0, b: 0))],
            background: nil
        )
        let image = renderer.render(part: 0)!
        // The black gate edge covers the corner of the red photo, the center stays red.
        #expect(image.pixel(x: 2, y: 2).r < 60)
        #expect(image.pixel(x: 384, y: 512) == (255, 0, 0))
        #expect(FilmEdge.allCases.allSatisfy { $0.url(landscape: true, preview: true) != nil && $0.url(landscape: false, preview: false) != nil })
    }
}

struct ExportTests {
    @Test func namesFollowFrameOrder() {
        var project = Project(name: "Test")
        project.slides[0].choose(.single, span: 2)
        let id = project.insertSlide(after: nil)
        project.updateSlide(id) { $0.place([Media(file: "v.mov", kind: .video)], at: nil) }
        let names = Exporter(project: project, scale: 2) { URL(filePath: "/\($0)") }.fileNames()
        let first = project.slides[0].id.uuidString.prefix(8).lowercased()
        let second = id.uuidString.prefix(8).lowercased()
        #expect(names == ["slide1-\(first)-1@2x.png", "slide2-\(first)-2@2x.png", "slide3-\(second)@2x.mp4"])
    }

    @Test func renderGivesOneImagePerPanoramaPart() async throws {
        let folder = Fixtures.tempFolder()
        let photo = Fixtures.writePNG(Fixtures.image(width: 100, height: 100, color: .black), named: "p.png", in: folder)
        var project = Project(name: "Test")
        project.slides[0].choose(.single, span: 3)
        project.slides[0].place([Media(file: "p.png", kind: .image)], at: nil)

        let images = await Exporter(project: project, scale: 1) { _ in photo }.render(slideAt: 0)
        #expect(images.count == 3)
        #expect(images[1].width == 768 && images[1].pixel(x: 384, y: 512) == (0, 0, 0))
        let png = try #require(Exporter.pngData(images[0]))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func exportWritesDatedPNGs() async throws {
        let folder = Fixtures.tempFolder()
        let photo = Fixtures.writePNG(Fixtures.image(width: 100, height: 100, color: .black), named: "p.png", in: folder)
        var project = Project(name: "Test")
        project.slides[0].place([Media(file: "p.png", kind: .image)], at: nil)
        project.insertSlide(after: nil)
        project.insertSlide(after: nil)
        let out = folder.appending(path: "out", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let urls = try await Exporter(project: project, scale: 1) { _ in photo }.export(to: out) { _ in }
        #expect(urls.count == 3)
        let dates = urls.map { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast }
        #expect(dates[0] < dates[1] && dates[1] < dates[2])
        let exported = try #require(MediaLoader.image(at: urls[0]))
        #expect(exported.pixel(x: 384, y: 512) == (0, 0, 0))
    }

    @Test(.timeLimit(.minutes(1))) func exportWritesVideoOfShortestClip() async throws {
        let folder = Fixtures.tempFolder()
        let long = try await Fixtures.video(seconds: 2, audio: true, in: folder)
        let short = try await Fixtures.video(seconds: 1, width: 240, height: 320, in: folder)
        var project = Project(name: "Test")
        project.slides[0].place([
            Media(file: long.lastPathComponent, kind: .video),
            Media(file: short.lastPathComponent, kind: .video),
        ], at: nil)
        let out = Fixtures.tempFolder()

        // Scale 2 with audio: the writer interleaves both tracks.
        let urls = try await Exporter(project: project, scale: 2) { folder.appending(path: $0) }.export(to: out) { _ in }
        let asset = AVURLAsset(url: urls[0])
        #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1) < 0.1)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalSize) == CGSize(width: 1536, height: 2048))
        let frame = try #require(await MediaLoader.videoPoster(at: urls[0]))
        let top = frame.pixel(x: 768, y: 500)
        #expect(top.g > 150 && top.r < 60)
    }
}

struct LibraryTests {
    @Test func createSaveListTrash() throws {
        let library = ProjectLibrary(root: Fixtures.tempFolder())
        var (project, url) = try library.create(name: "Trip")
        project.name = "Trip 2"
        try library.save(project, at: url, cover: Fixtures.image(width: 10, height: 10, color: .white))
        let listed = library.list()
        #expect(listed.map(\.name) == ["Trip 2"])
        #expect(FileManager.default.fileExists(atPath: listed[0].coverURL.path))
        #expect(try library.load(url) == project)
        try library.trash(url)
        #expect(library.list().isEmpty)
    }

    @Test func importReusesSameFile() throws {
        let folder = Fixtures.tempFolder()
        let library = ProjectLibrary(root: folder.appending(path: "lib"))
        let (_, url) = try library.create(name: "P")
        let photo = Fixtures.writePNG(Fixtures.image(width: 10, height: 10, color: .black), named: "a.png", in: folder)
        #expect(try library.importMedia(photo, into: url) == "a.png")
        #expect(try library.importMedia(photo, into: url) == "a.png")
        // Same name, other content → new name.
        let other = Fixtures.tempFolder()
        let different = Fixtures.writePNG(Fixtures.image(width: 50, height: 50, color: .white), named: "a.png", in: other)
        #expect(try library.importMedia(different, into: url) == "a-1.png")
    }
}
