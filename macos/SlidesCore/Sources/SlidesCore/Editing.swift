import Foundation

extension Slide {
    /// Most photos a drop can stack before the layout is chosen by hand.
    static let maxAutoSlots = 3

    /// Puts `media` into slots, starting at `slot` (or the first empty slot when `nil`).
    ///
    /// Until the layout is chosen by hand, the layout grows to fit up to three photos.
    /// Media that doesn't fit is left out. Returns how many were placed.
    @discardableResult
    public mutating func place(_ media: [Media], at slot: Int?) -> Int {
        let capacity = isPanorama ? 1 : (layoutChosen ? layout.slotCount : Self.maxAutoSlots)
        var targets: [Int]
        if let slot {
            targets = Array(slot..<capacity)
        } else {
            let empty = slots.indices.filter { slots[$0] == nil }
            targets = empty + Array(slots.count..<max(capacity, slots.count))
        }
        targets = Array(targets.prefix(media.count))
        guard let last = targets.max() else { return 0 }

        if last >= slots.count, let grown = Layout(rawValue: last + 1) {
            resize(to: grown)
        }
        for (item, target) in zip(media, targets) {
            slots[target] = item
        }
        return targets.count
    }

    /// Picks a layout by hand. A span above 1 makes a panorama with one photo.
    public mutating func choose(_ layout: Layout, span: Int = 1) {
        let span = min(max(span, 1), Self.maxSpan)
        let layout = span > 1 ? .single : layout
        let changed = layout != self.layout || span != self.span
        // Keep the photos in order, without the gaps.
        let kept = slots.compactMap(\.self)
        self.layout = layout
        self.span = span
        slots = (0..<layout.slotCount).map { $0 < kept.count ? kept[$0] : nil }
        if changed { resetCrops() }
        layoutChosen = true
    }

    public mutating func removeMedia(at slot: Int) {
        guard slots.indices.contains(slot) else { return }
        slots[slot] = nil
    }

    private mutating func resize(to layout: Layout) {
        self.layout = layout
        slots += Array(repeating: nil, count: max(layout.slotCount - slots.count, 0))
        slots = Array(slots.prefix(layout.slotCount))
        resetCrops()
    }

    /// Resets pan and zoom; the rotation stays, it belongs to the photo, not the slot.
    private mutating func resetCrops() {
        slots = slots.map { media in
            media.map { var copy = $0; copy.crop = Crop(angle: copy.crop.angle); return copy }
        }
    }
}

extension Project {
    public func index(of id: Slide.ID) -> Int? {
        slides.firstIndex { $0.id == id }
    }

    /// Adds an empty slide after `id` (or at the end) and returns its id.
    @discardableResult
    public mutating func insertSlide(after id: Slide.ID?) -> Slide.ID {
        let slide = Slide()
        let position = id.flatMap(index(of:)).map { $0 + 1 } ?? slides.count
        slides.insert(slide, at: position)
        return slide.id
    }

    /// Puts a copy of a slide right after it and returns the copy's id.
    @discardableResult
    public mutating func duplicateSlide(_ id: Slide.ID) -> Slide.ID? {
        guard let index = index(of: id) else { return nil }
        var copy = slides[index]
        copy.id = UUID()
        copy.texts = copy.texts.map { var box = $0; box.id = UUID(); return box }
        slides.insert(copy, at: index + 1)
        return copy.id
    }

    /// Removes a slide, keeping at least one. Returns the id to select next.
    public mutating func removeSlide(_ id: Slide.ID) -> Slide.ID? {
        guard slides.count > 1, let index = index(of: id) else { return nil }
        slides.remove(at: index)
        return slides[min(index, slides.count - 1)].id
    }

    /// Moves a slide so it ends up before the slide now at `destination` (or last when past the end).
    public mutating func moveSlide(_ id: Slide.ID, to destination: Int) {
        guard let from = index(of: id) else { return }
        let slide = slides.remove(at: from)
        // The destination counted the moved slide while it was still in place.
        let target = destination > from ? destination - 1 : destination
        slides.insert(slide, at: min(max(target, 0), slides.count))
    }

    public mutating func updateSlide(_ id: Slide.ID, _ change: (inout Slide) -> Void) {
        guard let index = index(of: id) else { return }
        change(&slides[index])
    }

    /// Every media file the project uses, for cleanup and export.
    public var mediaFiles: Set<String> {
        Set(slides.flatMap { slide in slide.slots.compactMap { $0?.file } + [slide.style.backgroundImage].compactMap(\.self) })
    }
}
