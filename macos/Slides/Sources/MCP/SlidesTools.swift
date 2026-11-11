import AppKit
import Foundation
import SlidesCore

/// The tools an MCP client gets: everything the app can do, on the live app, with undo.
@MainActor
struct SlidesTools {
    let app: AppModel

    static let instructions = """
    Slides is a macOS editor for Instagram-style photo and video carousels. Edits go to the open app live, \
    save automatically, and the user can undo them with ⌘Z (or the undo tool).
    A project is a list of slides in one format (4:3 or 16:9 portrait frames). A slide stacks 1 to 3 photos \
    vertically (layout), or spans 2 to 5 frames as a panorama with one photo (span). Slides and slots are \
    numbered from 1. Text boxes sit on top, positioned in 1x pixels from the slide's top-left \
    (frameSize in get_project; a panorama's canvas is span × frame width wide, so text can cross the cuts). \
    Most tools need an open project: call open_project or create_project first. \
    Use render_slide to see the result.
    """

    // MARK: - Definitions

    static let definitions: [[String: Any]] = [
        tool("list_projects", "Lists all projects, newest first.", readOnly: true),
        tool("open_project", "Opens a project in the editor.", ["project": projectArg], required: ["project"]),
        tool("create_project", "Creates a project with one empty slide and opens it.", [
            "name": string("Project name. Default: \"Project <date>\"."),
        ]),
        tool("close_project", "Saves the open project and goes back to the project list."),
        tool("delete_project", "Moves a project to the Trash.", ["project": projectArg], required: ["project"]),
        tool("get_project", "The open project: name, format, selected slide and every slide with its photos and style.", readOnly: true),
        tool("update_project", "Renames the open project or changes its format.", [
            "name": string("New name."),
            "format": enumeration(["4:3", "16:9"], "Frame format: 4:3 (768 × 1024) or 16:9 (576 × 1024)."),
        ]),
        tool("select_slide", "Selects a slide, so the editor shows it.", ["slide": slideArg], required: ["slide"]),
        tool("add_slide", "Adds an empty slide and selects it.", [
            "after": integer("Slide number to insert after. Default: the selected slide."),
        ]),
        tool("delete_slide", "Deletes a slide. The last slide can't be deleted.", ["slide": slideArg]),
        tool("move_slide", "Moves a slide to a new position.", [
            "slide": slideArg,
            "to": integer("Position the slide ends up at, 1 = first."),
        ], required: ["slide", "to"]),
        tool("update_slide", "Changes a slide's layout and style. Only the given fields change; all in one undo step.", [
            "slide": slideArg,
            "layout": integer("Photos stacked vertically: 1, 2 or 3. Sets span to 1."),
            "span": integer("Frames the slide covers: 1 = normal, 2...5 = panorama with one photo."),
            "fit": enumeration(["fill", "full"], "fill: photos cover their slot (pan and zoom apply). full: whole photo visible."),
            "border": number("Margin around the whole slide in 1x pixels (once, not per photo), 0...\(Int(SlideStyle.maxBorder))."),
            "gap": number("Space between stacked photos in 1x pixels, 0...\(Int(SlideStyle.maxGap))."),
            "color": string("Background color as hex, e.g. #FFFFFF."),
            "background_image": string("Absolute path of a photo for a blurred background, or \"\" to remove it."),
            "blur": number("Blur radius of the background photo in 1x pixels, 0...\(Int(SlideStyle.maxBlur))."),
            "film_edge": enumeration(["none", "white", "black"], "Thin film-gate edge over each photo."),
        ]),
        tool("add_media", "Copies photos or videos into the project and puts them on a slide. Fills empty slots first; until a layout is chosen by hand, the layout grows to fit up to 3.", [
            "paths": ["type": "array", "items": ["type": "string"], "description": "Absolute file paths of photos or videos."],
            "slide": slideArg,
            "slot": integer("Slot to start at, 1 = top. Replaces what's there. Default: the first empty slot."),
        ], required: ["paths"]),
        tool("remove_media", "Empties a slot.", ["slide": slideArg, "slot": slotArg], required: ["slot"]),
        tool("set_crop", "Pans and zooms a photo in its slot (fit: fill). Missing values stay as they are.", [
            "slide": slideArg,
            "slot": slotArg,
            "x": number("Horizontal shift as a share of the slot width, about -0.5...0.5. Positive moves the photo right."),
            "y": number("Vertical shift as a share of the slot height, about -0.5...0.5. Positive moves the photo down."),
            "zoom": number("1 = photo just covers the slot, up to \(Int(Crop.maxZoom))."),
        ], required: ["slot"]),
        tool("render_slide", "Renders a slide as PNG at 1x (768 × 1024 for 4:3), one image per panorama frame. Videos show their first frame.", [
            "slide": slideArg,
        ], readOnly: true),
        tool("export", "Exports all slides into a folder: PNG per frame, MP4 for slides with video. Returns the files.", [
            "folder": string("Absolute folder path. Created if missing."),
            "size": enumeration(["instagram", "large"], "instagram: 2x (1536 × 2048 for 4:3, default). large: 3x."),
        ], required: ["folder"]),
        tool("add_text", "Adds a text box on top of a slide. Without x or y it's centered on the first frame. Without width it grows with the text; with width it wraps.", textProperties.merging(["slide": slideArg]) { a, _ in a }, required: ["text"]),
        tool("update_text", "Changes a text box. Only the given fields change.", textProperties.merging(["slide": slideArg, "box": boxArg]) { a, _ in a }, required: ["box"]),
        tool("remove_text", "Removes a text box.", ["slide": slideArg, "box": boxArg], required: ["box"]),
        tool("list_fonts", "Installed font families, or with family the styles of one family and their PostScript names (for the font field).", [
            "family": string("Family name, e.g. Helvetica Neue."),
        ], readOnly: true),
        tool("undo", "Undoes the last edit in the open project."),
        tool("redo", "Redoes the last undone edit."),
    ]

    private static let projectArg = string("Project id or exact name (see list_projects).")
    private static let slideArg = integer("Slide number, 1 = first. Default: the selected slide.")
    private static let slotArg = integer("Slot number, 1 = top.")
    private static let boxArg = integer("Text box number on the slide, 1 = first (see texts in get_project).")
    private static let textProperties: [String: [String: Any]] = [
        "text": string("The text. Newlines start new lines."),
        "x": number("Left edge in 1x pixels from the slide's left."),
        "y": number("Top edge in 1x pixels from the slide's top."),
        "width": number("Fixed width in 1x pixels; the text wraps inside it. 0 = auto width (grows with the text)."),
        "font": string("PostScript name, e.g. HelveticaNeue-Bold (see list_fonts)."),
        "size": number("Font size in 1x pixels (default 64)."),
        "color": string("Hex color, e.g. #FFFFFF."),
        "align": enumeration(["left", "center", "right"], "Alignment of the lines inside the box."),
        "line_height": number("Line height in % of the font size, e.g. 120. 0 = the font's own."),
        "letter_spacing": number("Letter spacing in % of the font size, e.g. -2."),
    ]

    private static func tool(
        _ name: String,
        _ description: String,
        _ properties: [String: [String: Any]] = [:],
        required: [String] = [],
        readOnly: Bool = false
    ) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties]
        if !required.isEmpty { schema["required"] = required }
        return ["name": name, "description": description, "inputSchema": schema, "annotations": ["readOnlyHint": readOnly]]
    }

    private static func string(_ description: String) -> [String: Any] { ["type": "string", "description": description] }
    private static func integer(_ description: String) -> [String: Any] { ["type": "integer", "description": description] }
    private static func number(_ description: String) -> [String: Any] { ["type": "number", "description": description] }
    private static func enumeration(_ values: [String], _ description: String) -> [String: Any] {
        ["type": "string", "enum": values, "description": description]
    }

    // MARK: - Calls

    /// Runs a tool and returns its MCP content blocks. Each call is one undo step.
    func call(_ name: String, _ args: Arguments) async throws -> [[String: Any]] {
        // AppKit closes the open undo group after each event. Calls come without one, so all of
        // them would undo as one step; a no-op event after each call marks where it ends.
        defer {
            if let event = NSEvent.otherEvent(
                with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0
            ) {
                NSApp.postEvent(event, atStart: false)
            }
        }
        return try await perform(name, args)
    }

    private func perform(_ name: String, _ args: Arguments) async throws -> [[String: Any]] {
        switch name {
        case "list_projects":
            app.refresh()
            let openURL = app.editor?.url
            return json(app.projects.sorted { $0.modified > $1.modified }.map { project in
                [
                    "id": project.id.uuidString,
                    "name": project.name,
                    "frames": project.frameCount,
                    "modified": project.modified.ISO8601Format(),
                    "open": project.url == openURL,
                ] as [String: Any]
            })

        case "open_project":
            let summary = try project(args)
            if app.editor?.url != summary.url {
                app.close()
                app.open(summary)
            }
            return try projectState()

        case "create_project":
            app.newProject()
            if let name = args.string("name"), !name.isEmpty { try editor().rename(name) }
            return try projectState()

        case "close_project":
            app.close()
            return text("Closed.")

        case "delete_project":
            let summary = try project(args)
            if app.editor?.url == summary.url { app.close() }
            app.delete(summary)
            return text("Moved \"\(summary.name)\" to the Trash.")

        case "get_project":
            return try projectState()

        case "update_project":
            let editor = try editor()
            if let name = args.string("name") { editor.rename(name) }
            if let label = args.string("format") {
                guard let format = Format.allCases.first(where: { $0.label == label }) else { throw ToolError("Unknown format \(label).") }
                editor.setFormat(format)
            }
            return try projectState()

        case "select_slide":
            let editor = try editor()
            editor.select(try slideID(args, in: editor))
            return try projectState()

        case "add_slide":
            let editor = try editor()
            if args.has("after") { editor.select(try slideID(args, key: "after", in: editor)) }
            editor.addSlide()
            return try projectState()

        case "delete_slide":
            let editor = try editor()
            guard editor.project.slides.count > 1 else { throw ToolError("The last slide can't be deleted.") }
            editor.removeSlide(try slideID(args, in: editor))
            return try projectState()

        case "move_slide":
            let editor = try editor()
            let id = try slideID(args, in: editor)
            guard let to = args.int("to"), (1...editor.project.slides.count).contains(to) else {
                throw ToolError("to must be 1...\(editor.project.slides.count).")
            }
            let from = editor.currentIndex(of: id)
            // `moveSlide` inserts before the slide now at the destination.
            editor.moveSlide(id, to: to - 1 > from ? to : to - 1)
            return try projectState()

        case "update_slide":
            return try await updateSlide(args)

        case "add_media":
            let editor = try editor()
            let id = try slideID(args, in: editor)
            let urls = try (args.strings("paths") ?? []).map { try existingFile($0) }
            let slot = try args.int("slot").map { try slotIndex($0, in: editor.slide(id)) }
            let placed = await editor.place(urls, slot: slot, in: id)
            var state = try projectState()
            if placed < urls.count {
                state.insert(["type": "text", "text": "Placed \(placed) of \(urls.count) files; the rest didn't fit or aren't photos or videos."], at: 0)
            }
            return state

        case "remove_media":
            let editor = try editor()
            let id = try slideID(args, in: editor)
            editor.removeMedia(slot: try slotIndex(args.int("slot"), in: editor.slide(id)), in: id)
            return try projectState()

        case "set_crop":
            let editor = try editor()
            let id = try slideID(args, in: editor)
            let slot = try slotIndex(args.int("slot"), in: editor.slide(id))
            guard var crop = editor.slide(id).slots[slot]?.crop else { throw ToolError("Slot \(slot + 1) is empty.") }
            if let x = args.double("x") { crop.x = min(max(x, -1), 1) }
            if let y = args.double("y") { crop.y = min(max(y, -1), 1) }
            if let zoom = args.double("zoom") { crop.zoom = min(max(zoom, 1), Crop.maxZoom) }
            editor.setCrop(crop, slot: slot, in: id)
            return try projectState()

        case "render_slide":
            let editor = try editor()
            let id = try slideID(args, in: editor)
            let library = editor.library
            let projectURL = editor.url
            let exporter = Exporter(project: editor.project, scale: 1) { library.mediaURL($0, in: projectURL) }
            let images = await exporter.render(slideAt: editor.currentIndex(of: id))
            return images.compactMap(Exporter.pngData).map {
                ["type": "image", "mimeType": "image/png", "data": $0.base64EncodedString()]
            }

        case "export":
            let editor = try editor()
            guard let path = args.string("folder"), path.hasPrefix("/") else { throw ToolError("folder must be an absolute path.") }
            let folder = URL(filePath: path, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let size: EditorModel.ExportSize = args.string("size") == "large" ? .large : .instagram
            let urls = try await editor.exportFiles(to: folder, size: size)
            return json(urls.map(\.path))

        case "add_text":
            let editor = try editor()
            let slideID = try slideID(args, in: editor)
            guard let text = args.string("text"), !text.isEmpty else { throw ToolError("text must not be empty.") }
            let change = try textChange(args)
            let frame = editor.project.format
            let id = editor.addText(at: .zero, text: text, in: slideID)
            editor.updateText(id, in: slideID) { box in
                change(&box)
                let size = TextRenderer.size(of: box)
                if !args.has("x") { box.x = ((frame.width - size.width) / 2).rounded() }
                if !args.has("y") { box.y = ((frame.height - size.height) / 2).rounded() }
            }
            return try projectState()

        case "update_text":
            let editor = try editor()
            let slideID = try slideID(args, in: editor)
            let id = try textID(args, in: editor.slide(slideID))
            let change = try textChange(args)
            editor.updateText(id, in: slideID) { change(&$0) }
            return try projectState()

        case "remove_text":
            let editor = try editor()
            let slideID = try slideID(args, in: editor)
            editor.removeText(try textID(args, in: editor.slide(slideID)), in: slideID)
            return try projectState()

        case "list_fonts":
            if let family = args.string("family") {
                let members = Fonts.members(of: family)
                guard !members.isEmpty else { throw ToolError("No font family \(family). Call list_fonts without family.") }
                return json(members.map { ["style": $0.style, "font": $0.postScript] })
            }
            return json(Fonts.families)

        case "undo", "redo":
            let editor = try editor()
            guard let manager = editor.undoManager else { throw ToolError("Undo isn't available.") }
            if name == "undo" {
                guard manager.canUndo else { throw ToolError("Nothing to undo.") }
                manager.undo()
            } else {
                guard manager.canRedo else { throw ToolError("Nothing to redo.") }
                manager.redo()
            }
            return try projectState()

        default:
            throw ToolError("Unknown tool \(name).")
        }
    }

    private func updateSlide(_ args: Arguments) async throws -> [[String: Any]] {
        let editor = try editor()
        let id = try slideID(args, in: editor)

        // Check everything first, so a bad value changes nothing.
        let layout = try args.int("layout").map { value in
            guard let layout = Layout(rawValue: value) else { throw ToolError("layout must be 1, 2 or 3.") }
            return layout
        }
        let span = try args.int("span").map { value in
            guard (1...Slide.maxSpan).contains(value) else { throw ToolError("span must be 1...\(Slide.maxSpan).") }
            return value
        }
        let fit = try args.string("fit").map { value in
            guard let fit = Fit(rawValue: value) else { throw ToolError("fit must be fill or full.") }
            return fit
        }
        let color = try args.string("color").map { value in
            guard let color = RGB(hex: value) else { throw ToolError("color must be a hex color like #FFFFFF.") }
            return color
        }
        let filmEdge = try args.string("film_edge").map { value -> FilmEdge? in
            switch value {
            case "none": return nil
            case "white": return .gateWhite
            case "black": return .gateBlack
            default: throw ToolError("film_edge must be none, white or black.")
            }
        }
        var background: String??
        if let path = args.string("background_image") {
            if path.isEmpty {
                background = .some(nil)
            } else {
                let url = try existingFile(path)
                guard let media = await editor.importMedia([url]).first, media.kind == .image else {
                    throw ToolError("\(path) isn't a photo.")
                }
                background = media.file
            }
        }

        editor.editSlide(id) { slide in
            if layout != nil || span != nil {
                // A layout alone ends a panorama; a span above 1 forces one photo.
                slide.choose(layout ?? slide.layout, span: span ?? 1)
            }
            if let fit { slide.style.fit = fit }
            if let border = args.double("border") { slide.style.border = min(max(border, 0), SlideStyle.maxBorder) }
            if let gap = args.double("gap") { slide.style.gap = min(max(gap, 0), SlideStyle.maxGap) }
            if let blur = args.double("blur") { slide.style.blur = min(max(blur, 0), SlideStyle.maxBlur) }
            if let color { slide.style.color = color }
            if let filmEdge { slide.style.filmEdge = filmEdge }
            if let background { slide.style.backgroundImage = background }
        }
        return try projectState()
    }

    // MARK: - Lookups

    private func editor() throws -> EditorModel {
        guard let editor = app.editor else { throw ToolError("No project is open. Call open_project or create_project first.") }
        return editor
    }

    private func project(_ args: Arguments) throws -> ProjectSummary {
        app.refresh()
        guard let key = args.string("project"),
              let summary = app.projects.first(where: { $0.id.uuidString.caseInsensitiveCompare(key) == .orderedSame })
              ?? app.projects.first(where: { $0.name == key }) else {
            throw ToolError("No project \(args.string("project") ?? "") found. Call list_projects.")
        }
        return summary
    }

    private func slideID(_ args: Arguments, key: String = "slide", in editor: EditorModel) throws -> Slide.ID {
        guard let number = args.int(key) else { return editor.selectedSlideID }
        guard editor.project.slides.indices.contains(number - 1) else {
            throw ToolError("\(key) must be 1...\(editor.project.slides.count).")
        }
        return editor.project.slides[number - 1].id
    }

    private func textID(_ args: Arguments, in slide: Slide) throws -> TextBox.ID {
        guard let number = args.int("box"), slide.texts.indices.contains(number - 1) else {
            throw ToolError(slide.texts.isEmpty ? "This slide has no text." : "box must be 1...\(slide.texts.count).")
        }
        return slide.texts[number - 1].id
    }

    /// Checks the text fields of a call and returns the change they make.
    private func textChange(_ args: Arguments) throws -> (inout TextBox) -> Void {
        let alignment = try args.string("align").map { value in
            guard let alignment = TextAlignment(rawValue: value) else { throw ToolError("align must be left, center or right.") }
            return alignment
        }
        let color = try args.string("color").map { value in
            guard let color = RGB(hex: value) else { throw ToolError("color must be a hex color like #FFFFFF.") }
            return color
        }
        if let font = args.string("font"), NSFont(name: font, size: 12) == nil {
            throw ToolError("No font \(font). Use a PostScript name from list_fonts.")
        }
        return { box in
            if let text = args.string("text") { box.text = text }
            if let x = args.double("x") { box.x = x }
            if let y = args.double("y") { box.y = y }
            if let width = args.double("width") { box.width = width > 0 ? width : nil }
            if let font = args.string("font") { box.font = font }
            if let size = args.double("size") { box.size = min(max(size, TextBox.sizeRange.lowerBound), TextBox.sizeRange.upperBound) }
            if let color { box.color = color }
            if let alignment { box.alignment = alignment }
            if let lineHeight = args.double("line_height") { box.lineHeight = lineHeight > 0 ? max(lineHeight, 10) : nil }
            if let spacing = args.double("letter_spacing") { box.letterSpacing = spacing }
        }
    }

    private func slotIndex(_ number: Int?, in slide: Slide) throws -> Int {
        guard let number, slide.slots.indices.contains(number - 1) else {
            throw ToolError("slot must be 1...\(slide.slots.count) for this slide's layout.")
        }
        return number - 1
    }

    private func existingFile(_ path: String) throws -> URL {
        let url = URL(filePath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else { throw ToolError("No file at \(path).") }
        return url
    }

    // MARK: - Output

    private func projectState() throws -> [[String: Any]] {
        let editor = try editor()
        let project = editor.project
        return json([
            "id": project.id.uuidString,
            "name": project.name,
            "folder": editor.url.path,
            "format": project.format.label,
            "frameSize": ["width": project.format.width, "height": project.format.height],
            "frames": project.frameCount,
            "selectedSlide": editor.currentIndex + 1,
            "slides": project.slides.enumerated().map { index, slide in
                [
                    "slide": index + 1,
                    "layout": slide.layout.rawValue,
                    "span": slide.span,
                    "slots": slide.slots.map { media -> Any in
                        guard let media else { return NSNull() }
                        return [
                            "file": media.file,
                            "kind": media.kind.rawValue,
                            "crop": ["x": media.crop.x, "y": media.crop.y, "zoom": media.crop.zoom],
                        ] as [String: Any]
                    },
                    "style": [
                        "fit": slide.style.fit.rawValue,
                        "border": slide.style.border,
                        "gap": slide.style.gap,
                        "color": slide.style.color.hex,
                        "backgroundImage": slide.style.backgroundImage ?? NSNull(),
                        "blur": slide.style.blur,
                        "filmEdge": slide.style.filmEdge.map { $0 == .gateWhite ? "white" : "black" } ?? "none",
                    ] as [String: Any],
                    "texts": slide.texts.enumerated().map { index, box in
                        let size = TextRenderer.size(of: box)
                        return [
                            "box": index + 1,
                            "text": box.text,
                            "x": box.x,
                            "y": box.y,
                            "width": box.width ?? NSNull(),
                            "measured": ["width": size.width, "height": size.height],
                            "font": box.font,
                            "size": box.size,
                            "color": box.color.hex,
                            "align": box.alignment.rawValue,
                            "lineHeight": box.lineHeight ?? NSNull(),
                            "letterSpacing": box.letterSpacing,
                        ] as [String: Any]
                    },
                ] as [String: Any]
            },
        ] as [String: Any])
    }

    private func json(_ value: Any) -> [[String: Any]] {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return text(String(decoding: data, as: UTF8.self))
    }

    private func text(_ string: String) -> [[String: Any]] {
        [["type": "text", "text": string]]
    }
}

private extension EditorModel {
    func slide(_ id: Slide.ID) -> Slide { project.slides[project.index(of: id) ?? 0] }
    func currentIndex(of id: Slide.ID) -> Int { project.index(of: id) ?? 0 }
}

private extension RGB {
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(r: Double(value >> 16 & 0xFF) / 255, g: Double(value >> 8 & 0xFF) / 255, b: Double(value & 0xFF) / 255)
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
