# Slides

A macOS editor for Instagram-style photo carousels.

## Language

**Project**:
A carousel: an ordered list of slides in one format.
_Avoid_: Document, deck

**Slide**:
One item of the carousel. Covers one frame, or several when it is a panorama.
_Avoid_: Page, post

**Frame** (of a slide):
One exported image, the size of the format. A panorama of 3 exports 3 frames.
_Avoid_: Part, tile

**Panorama**:
A slide that spans 2 to 6 frames with one wide canvas, cut into frames on export.

**Slot**:
One cell in a slide's grid of rows and columns.
_Avoid_: Cell, box

**Slot photo**:
A photo or video that fills a slot. It always covers the slot and can be panned, zoomed and rotated inside it.
_Avoid_: Grid image

**Free photo**:
A still image placed anywhere on a slide's canvas, like free text. Always shown whole, keeps its aspect ratio, and can be moved, resized, rotated and given a photo frame. Shares one back-to-front order with free text, above the slot photos.
_Avoid_: Sticker, floating image, layer

**Free text**:
Text placed anywhere on a slide's canvas.
_Avoid_: Caption, label

**Border**:
The slide-wide inset around each slot photo, where the background shows through.
_Avoid_: Padding, margin

**Photo frame**:
The colored edge around one free photo, even on all sides.
_Avoid_: Border (that's the slide's inset), outline, stroke
