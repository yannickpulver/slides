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
- [x] Frames are 768 × 1024 (4:3) and 576 × 1024 (16:9) at 1x; Export writes 2× (1536 × 2048), "Other Size" offers Large (3×)

## 7. Switch over
- [x] Rendering checked in the running app (editor, start screen, export contact sheet)
- [ ] Click through drag & drop, pan/zoom, reorder, undo, video play by hand (not automated)
- [x] Delete Kotlin, Conveyor, iosApp, fastlane leftovers
- [x] README, VERSION 2.0.0, homebrew workflow
- [x] `SPARKLE_PRIVATE_KEY` secret on the repo
- [ ] New `screenshot.png` for the README
