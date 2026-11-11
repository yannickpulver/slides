# Swift rewrite

Breaking rewrite of the Compose desktop app as a native SwiftUI macOS app (`macos/`).
No migration of old projects.

## 1. Skeleton
- [x] Tuist project (`macos/Project.swift`), app target, `SlidesCore` package, Sparkle
- [x] Updater + "Check for Updates…" menu
- [x] Release workflow (copier style), PRs as rehearsal
- [x] Local dry run of the CI archive: universal, 13 MB app, 8.3 MB zip

## 2. Core (`SlidesCore`)
- [x] Model (Project, Slide, Media, Crop, SlideStyle, Format, Layout, FilmEdge)
- [x] `SlideLayout` geometry (slots, gap, border, fit/fill, crop clamp, panorama parts, film-edge rect)
- [x] Media loading (ImageIO oriented images, video posters)
- [x] `SlideRenderer` (color, blurred background image, photos, film edge)
- [x] PNG export (1x/2x/3x, one file per panorama part, dates 1 s apart)
- [x] `ProjectLibrary` (packages, scan, trash, media import dedupe, cover)
- [x] Editing operations (drop with auto layout, layout/span, move, remove, crop, styles)
- [x] Tests (25, incl. MP4 with audio at 2x)

## 3. Start screen
- [x] Grid with covers, search, sort, new, delete (context menu: Show in Finder)

## 4. Editor
- [x] Top bar (back, name, format switch)
- [x] Slide row (all slides, selected centered, panorama shrinks to fit)
- [x] Sidebar (layout, canvas, image, export), system color panel
- [x] Filmstrip (thumbs, drag to reorder, add, remove)
- [x] Keys (← → Esc, ⌘[ ⌘]), undo/redo via Edit menu, autosave 1 s after a change

## 5. Canvas
- [x] Drop files on canvas/slot, pick file, replace, remove
- [x] Pan / pinch zoom / corner handles
- [x] Panorama editing with cut lines

## 6. Video
- [x] Poster + play/pause in slot
- [x] MP4 export (30 fps, audio of first video, shortest length, Rec. 709)

## Native UI (like Print Lab)
- [x] Horizontal filmstrip below the canvas (drag to reorder, drop files, context menu)
- [x] Selected slide centered on the canvas, inspector with cards (Tabler icons)
- [x] Native toolbar: back, export, inspector toggle; title + subtitle. Format (4:3 / 16:9) as the first inspector card
- [x] Start screen: toolbar search, sort menu, new; ContentUnavailableView
- [x] System font and appearance (light/dark), system accent color
- [x] Rename via File › Rename Project…, Add Photos ⌘O, Export ⌘E

## Export size
- [x] Frames are 768 × 1024 (4:3) and 576 × 1024 (16:9) at 1x; Export size dropdown: Instagram (2×, 1536 × 2048, default) or Large (3×)

## Film edges
- [x] Only the thin gate masks from Figma ("Film mask/thin"): white and black; landscape = rotated portrait
- [x] Older projects with removed edge names still open (edge dropped)

## 7. Switch over
- [x] Rendering checked in the running app (editor, start screen, export contact sheet)
- [ ] Click through drag & drop, pan/zoom, reorder, undo, video play by hand (not automated)
- [x] Delete Kotlin, Conveyor, iosApp, fastlane leftovers
- [x] README, VERSION 2.0.0, homebrew workflow
- [x] `SPARKLE_PRIVATE_KEY` secret on the repo
- [x] New `screenshot.png` for the README

## MCP server (`macos/Slides/Sources/MCP/`)
- [x] HTTP server on 127.0.0.1 (Streamable HTTP, JSON replies), Origin check
- [x] JSON-RPC: initialize, ping, tools/list, tools/call
- [x] Tools: projects (list, open, create, close, delete), project (get, update), slides (select, add, delete, move, update), media (add, remove, crop), render, export, undo/redo
- [x] Async import + export in `EditorModel` for the tools
- [x] `Exporter.render(slideAt:)` + test
- [x] Menu: copy the `claude mcp add` command; README section
- [x] Verified against the running app with curl + Claude Code

## Text (free-flowing, like Figma)
- [x] Model: `TextBox` (text, x/y, auto or fixed width, font, size, color, align, line height, letter spacing) on `Slide`, old projects still open
- [x] `TextRenderer` (CoreText): measure + draw; renderer draws text over photos (PNG, MP4, cover, thumbnails)
- [x] Editor: T / toolbar text tool, click to place, drag for fixed width
- [x] Select, move (snap to centers), left/right handles for width, double-click to edit in place
- [x] Keys: ⌫ deletes text, arrows nudge, Esc deselects, Enter edits
- [x] Inspector Text card: font family + style, size, color, align, width mode, line height, letter spacing
- [x] MCP: add_text, update_text, remove_text, list_fonts; texts in get_project
- [x] Tests (decode old project, measure, render)
- [x] Verified via MCP + renders + editor screenshot
- [x] Clicked through the canvas with the real cursor: place, drag for width, select, move + snap, width handle, inline edit, Esc, ⌫, arrows
- [x] Edit › Undo/Redo menu reaches the project (the focus proxy has no undo manager)
- [ ] ⌘Z keystroke still doesn't undo (also on main): needs a check with a real keypress
