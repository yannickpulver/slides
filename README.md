# Slides

A desktop slide editor built with Compose Multiplatform for creating Instagram-style image and video carousels.

![Slides](screenshot.png)

## Features

- Drag & drop images and videos into slides
- Pan, zoom, and crop media to fit your layout
- Choose from single, two, or three-slot templates
- Native video playback with hardware acceleration (AVPlayer on macOS)
- Export slides as PNG (1x/2x) or MP4 with audio
- Save and load projects
- Arrow key navigation between slides
- Multi-file drop to auto-fill templates

## Tech Stack

- Kotlin Multiplatform
- Jetpack Compose Multiplatform
- ComposeMediaPlayer (native video playback)
- JavaCV/FFmpeg (video export)
- FileKit (native file dialogs)

## Running

```
./gradlew run
```

## License

MIT
