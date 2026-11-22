# Slides

A native macOS editor for Instagram-style photo and video carousels.

![Slides](screenshot.png)

## Install

```sh
brew install --cask yannickpulver/tap/slides
```

Slides updates itself through Sparkle. It needs macOS 26 or later.

## Features

- Drop photos and videos onto a slide, or click a slot to pick files
- Photos in a grid of 1 to 6 rows and 1 to 5 columns per slide, or a panorama across 2 to 6 slides
- Pan and zoom each photo; it always covers its slot
- Background color or blurred background image, gap and border
- Thin film-gate edge in white or black
- Free text like in Figma: press T and click (or drag for a wrapping width), move with snapping, double-click to edit, ⌥-drag or ⌘C / ⌘V to copy, set opacity; any installed font, recent ones on top
- Free photos anywhere on a slide, shown whole: move, resize from the corners, rotate, add a photo frame; stack them with the text (⌥⌘[ / ⌥⌘])
- Start screen as a grid of covers or as a filmstrip: one row per project with all its slides; click a slide to open the project there
- Export as PNG (1x, 2x, 3x) or MP4 with the audio of the first video
- Exported files are dated one second apart, so apps keep the order
- Output sharpening (off, low, standard, high) for photos exported smaller than their file

## MCP

While Slides runs, agents like Claude Code can control it over MCP: open and create projects, add photos and text, change layouts and styles, render slides and export. Edits show up live and undo with ⌘Z.

```sh
claude mcp add --transport http slides http://127.0.0.1:47100/mcp
```

The command is also under Slides › Copy MCP Setup Command. The server only listens on this Mac. Debug builds use port 47101.

## Development

```sh
cd macos
tuist install && tuist generate
```

`SlidesCore` holds the model, layout, renderer and export. Its tests run with `swift test` in `macos/SlidesCore`.

A release builds when `VERSION` changes on `main`.

## License

MIT
