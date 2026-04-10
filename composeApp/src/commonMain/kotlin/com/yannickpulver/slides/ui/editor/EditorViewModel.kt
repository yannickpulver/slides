package com.yannickpulver.slides.ui.editor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.openInFinder
import com.yannickpulver.slides.model.ElementBounds
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaFitMode
import com.yannickpulver.slides.model.MediaType
import com.yannickpulver.slides.model.Project
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.model.SlideTemplate
import com.yannickpulver.slides.model.isSpanTemplate
import com.yannickpulver.slides.model.spanSize
import com.yannickpulver.slides.template.boundsForTemplate
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class EditorState(
    val project: Project = Project(),
    val selectedSlideId: String? = null,
    val selectedElementId: String? = null,
    val projectFilePath: String? = null,
    val exportProgress: Float? = null, // null = idle, 0-1 = in progress
) {
    val currentSlide: Slide?
        get() = selectedSlideId?.let { id -> project.slides.find { it.id == id } }
            ?: project.slides.firstOrNull()

    val currentSlideIndex: Int
        get() = project.slides.indexOfFirst { it.id == (selectedSlideId ?: project.slides.firstOrNull()?.id) }

    val currentSpanGroup: List<Slide>?
        get() {
            val gid = currentSlide?.spanGroupId ?: return null
            return project.slides.filter { it.spanGroupId == gid }.sortedBy { it.spanIndex }
        }
}

class EditorViewModel : ViewModel() {

    private val _state = MutableStateFlow(EditorState())
    val state: StateFlow<EditorState> = _state.asStateFlow()

    private val undoStack = ArrayDeque<EditorState>(MAX_UNDO)
    private val redoStack = ArrayDeque<EditorState>(MAX_UNDO)

    init {
        // Select first slide by default
        _state.update { it.copy(selectedSlideId = it.project.slides.firstOrNull()?.id) }
    }

    private fun pushUndo() {
        undoStack.addLast(_state.value)
        if (undoStack.size > MAX_UNDO) undoStack.removeFirst()
        redoStack.clear()
    }

    fun undo() {
        val prev = undoStack.removeLastOrNull() ?: return
        redoStack.addLast(_state.value)
        _state.value = prev
    }

    fun redo() {
        val next = redoStack.removeLastOrNull() ?: return
        undoStack.addLast(_state.value)
        _state.value = next
    }

    fun addSlide() {
        pushUndo()
        _state.update { state ->
            val newSlide = Slide()
            state.copy(
                project = state.project.copy(slides = state.project.slides + newSlide),
                selectedSlideId = newSlide.id,
                selectedElementId = null,
            )
        }
    }

    fun removeSlide(slideId: String) {
        pushUndo()
        _state.update { state ->
            val slide = state.project.slides.find { it.id == slideId }
            val gid = slide?.spanGroupId
            // Remove entire span group if part of one
            val idsToRemove = if (gid != null) {
                state.project.slides.filter { it.spanGroupId == gid }.map { it.id }.toSet()
            } else {
                setOf(slideId)
            }
            val remaining = state.project.slides.filter { it.id !in idsToRemove }
            if (remaining.isEmpty()) return@update state
            state.copy(
                project = state.project.copy(slides = remaining),
                selectedSlideId = if (state.selectedSlideId in idsToRemove) remaining.firstOrNull()?.id else state.selectedSlideId,
                selectedElementId = if (state.selectedSlideId in idsToRemove) null else state.selectedElementId,
            )
        }
    }

    fun selectSlide(slideId: String) {
        _state.update { it.copy(selectedSlideId = slideId, selectedElementId = null) }
    }

    fun selectElement(elementId: String?) {
        _state.update { it.copy(selectedElementId = elementId) }
    }

    fun addElementAtSlot(slotIndex: Int, sourcePath: String) {
        val ext = sourcePath.substringAfterLast('.', "").lowercase()
        val type = if (ext in listOf("mp4", "mov", "avi", "mkv", "webm")) MediaType.VIDEO else MediaType.IMAGE
        addElementAtSlot(slotIndex, sourcePath, type)
    }

    private fun addElementAtSlot(slotIndex: Int, sourcePath: String, type: MediaType) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state

            // Check if this slot already has an element (using current template bounds)
            val currentBounds = boundsForTemplate(slide.template)
            val targetBounds = currentBounds.getOrNull(slotIndex)
            val isReplacing = targetBounds != null && slide.elements.any { it.bounds == targetBounds }

            // Only auto-expand template when adding to a new slot, not replacing
            val autoTemplate = if (!slide.hasChosenTemplate && !isReplacing) {
                val newElementCount = (slide.elements.size + 1).coerceAtMost(3)
                SlideTemplate.entries.find { it.slotCount == newElementCount } ?: slide.template
            } else {
                slide.template
            }
            val templateBounds = boundsForTemplate(autoTemplate)
            val bounds = templateBounds.getOrElse(slotIndex) { ElementBounds() }

            val element = MediaElement(
                sourcePath = sourcePath,
                type = type,
                bounds = bounds,
                zIndex = slotIndex,
            )

            // Replace existing element with same bounds, or append
            val elements = slide.elements.toMutableList()
            val existingIndex = elements.indexOfFirst { it.bounds == bounds }
            if (existingIndex >= 0) {
                elements[existingIndex] = element
            } else {
                elements.add(element)
            }

            // Re-apply bounds for all elements when template changed, reset crops
            val finalElements = if (autoTemplate != slide.template) {
                val newBounds = boundsForTemplate(autoTemplate)
                elements.mapIndexed { i, el ->
                    el.copy(bounds = newBounds.getOrElse(i) { el.bounds }, cropOffsetX = 0f, cropOffsetY = 0f, cropScale = 1f)
                }
            } else {
                elements
            }

            // Auto-select template when all slots are filled
            val autoChosen = slide.hasChosenTemplate ||
                finalElements.size >= autoTemplate.slotCount

            val updatedSlide = slide.copy(template = autoTemplate, elements = finalElements, hasChosenTemplate = autoChosen)
            val gid = slide.spanGroupId
            val updatedSlides = state.project.slides.map { s ->
                when {
                    s.id == slide.id -> updatedSlide
                    // Clone element to other slides in span group
                    gid != null && s.spanGroupId == gid -> {
                        s.copy(elements = listOf(element.copy(id = s.id + "_el", bounds = bounds)))
                    }
                    else -> s
                }
            }
            state.copy(
                project = state.project.copy(slides = updatedSlides),
                selectedElementId = element.id,
            )
        }
    }

    fun removeElement(elementId: String) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val updatedSlide = slide.copy(elements = slide.elements.filter { it.id != elementId })
            state.copy(
                project = state.project.copy(
                    slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                ),
                selectedElementId = if (state.selectedElementId == elementId) null else state.selectedElementId,
            )
        }
    }

    fun updateElementBounds(elementId: String, bounds: ElementBounds) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val updatedSlide = slide.copy(
                elements = slide.elements.map {
                    if (it.id == elementId) it.copy(bounds = bounds) else it
                }
            )
            state.copy(
                project = state.project.copy(
                    slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                ),
            )
        }
    }

    fun updateElementCrop(elementId: String, offsetX: Float, offsetY: Float, scale: Float) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val gid = slide.spanGroupId

            if (gid != null) {
                // Sync crop to all elements in the span group
                val updatedSlides = state.project.slides.map { s ->
                    if (s.spanGroupId == gid) {
                        s.copy(elements = s.elements.map { it.copy(cropOffsetX = offsetX, cropOffsetY = offsetY, cropScale = scale) })
                    } else s
                }
                state.copy(project = state.project.copy(slides = updatedSlides))
            } else {
                val updatedSlide = slide.copy(
                    elements = slide.elements.map {
                        if (it.id == elementId) it.copy(cropOffsetX = offsetX, cropOffsetY = offsetY, cropScale = scale) else it
                    }
                )
                state.copy(
                    project = state.project.copy(
                        slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                    ),
                )
            }
        }
    }

    fun updateElementStyle(
        elementId: String,
        fitMode: MediaFitMode? = null,
        frameBorderPx: Float? = null,
        backgroundColorArgb: Long? = null,
    ) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val gid = slide.spanGroupId

            fun applyStyle(el: MediaElement) = el.copy(
                fitMode = fitMode ?: el.fitMode,
                frameBorderPx = frameBorderPx ?: el.frameBorderPx,
                backgroundColorArgb = backgroundColorArgb ?: el.backgroundColorArgb,
            )

            if (gid != null) {
                val updatedSlides = state.project.slides.map { s ->
                    if (s.spanGroupId == gid) {
                        s.copy(elements = s.elements.map { applyStyle(it) })
                    } else s
                }
                state.copy(project = state.project.copy(slides = updatedSlides))
            } else {
                val updatedSlide = slide.copy(
                    elements = slide.elements.map {
                        if (it.id == elementId) applyStyle(it) else it
                    }
                )
                state.copy(
                    project = state.project.copy(
                        slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                    ),
                )
            }
        }
    }

    fun newProject() {
        _state.value = EditorState()
        _state.update { it.copy(selectedSlideId = it.project.slides.firstOrNull()?.id) }
    }

    fun loadProject(project: Project, filePath: String) {
        _state.value = EditorState(
            project = project,
            selectedSlideId = project.slides.firstOrNull()?.id,
            projectFilePath = filePath,
        )
    }

    fun setProjectFilePath(path: String) {
        _state.update { it.copy(projectFilePath = path) }
    }

    fun updateProjectName(name: String) {
        _state.update { it.copy(project = it.project.copy(name = name)) }
    }

    fun exportAllSlides(outputDir: String, scaleFactor: Int = 1) {
        val slides = _state.value.project.slides
        val aspectRatio = _state.value.project.aspectRatio
        if (_state.value.exportProgress != null || slides.isEmpty()) return

        viewModelScope.launch {
            _state.update { it.copy(exportProgress = 0f) }
            withContext(Dispatchers.Default) {
                slides.forEachIndexed { idx, slide ->
                    val baseProgress = idx.toFloat() / slides.size
                    exportSlideAsImage(slide, aspectRatio, outputDir, scaleFactor, idx + 1) { slideProgress ->
                        val total = (baseProgress + slideProgress / slides.size).coerceIn(0f, 1f)
                        _state.update { it.copy(exportProgress = total) }
                    }
                }
            }
            _state.update { it.copy(exportProgress = null) }
            openInFinder(outputDir)
        }
    }

    fun selectPreviousSlide() {
        _state.update { state ->
            val slides = state.project.slides
            val current = state.currentSlide ?: return@update state
            // Jump before the current span group (or just idx-1 for non-span)
            val targetIdx = if (current.spanGroupId != null) {
                val groupFirst = slides.indexOfFirst { it.spanGroupId == current.spanGroupId }
                groupFirst - 1
            } else {
                state.currentSlideIndex - 1
            }
            if (targetIdx < 0) return@update state
            // If landing on a span group, select its first slide
            val target = slides[targetIdx]
            val selectId = if (target.spanGroupId != null) {
                slides.first { it.spanGroupId == target.spanGroupId }.id
            } else target.id
            state.copy(selectedSlideId = selectId, selectedElementId = null)
        }
    }

    fun selectNextSlide() {
        _state.update { state ->
            val slides = state.project.slides
            val current = state.currentSlide ?: return@update state
            // Jump past the current span group (or just idx+1 for non-span)
            val targetIdx = if (current.spanGroupId != null) {
                val groupLast = slides.indexOfLast { it.spanGroupId == current.spanGroupId }
                groupLast + 1
            } else {
                state.currentSlideIndex + 1
            }
            if (targetIdx >= slides.size) return@update state
            val target = slides[targetIdx]
            val selectId = if (target.spanGroupId != null) {
                slides.first { it.spanGroupId == target.spanGroupId }.id
            } else target.id
            state.copy(selectedSlideId = selectId, selectedElementId = null)
        }
    }

    @OptIn(ExperimentalUuidApi::class)
    fun moveSlide(slideId: String, targetIndex: Int) {
        pushUndo()
        _state.update { state ->
            val slides = state.project.slides
            val slide = slides.find { it.id == slideId } ?: return@update state
            val gid = slide.spanGroupId

            val slidesToMove = if (gid != null) {
                slides.filter { it.spanGroupId == gid }.sortedBy { it.spanIndex }
            } else {
                listOf(slide)
            }

            val remaining = slides.toMutableList().apply { removeAll(slidesToMove.toSet()) }
            var insertAt = targetIndex.coerceIn(0, remaining.size)

            // Don't insert inside a span group — snap to nearest edge
            val targetSlide = remaining.getOrNull(insertAt)
            if (targetSlide != null && targetSlide.spanGroupId != null && targetSlide.spanGroupId != gid) {
                val spanGid = targetSlide.spanGroupId
                val spanFirst = remaining.indexOfFirst { it.spanGroupId == spanGid }
                val spanLast = remaining.indexOfLast { it.spanGroupId == spanGid }
                val distToStart = (insertAt - spanFirst).let { if (it < 0) Int.MAX_VALUE else it }
                val distToEnd = (spanLast + 1 - insertAt).let { if (it < 0) Int.MAX_VALUE else it }
                insertAt = if (distToStart <= distToEnd) spanFirst else spanLast + 1
                insertAt = insertAt.coerceIn(0, remaining.size)
            }

            remaining.addAll(insertAt, slidesToMove)

            state.copy(project = state.project.copy(slides = remaining))
        }
    }

    @OptIn(ExperimentalUuidApi::class)
    fun applyTemplate(template: SlideTemplate) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val spanSize = template.spanSize()

            // Tear down existing span group if switching away
            val slidesAfterTeardown = if (slide.isSpan && (spanSize == null || template != slide.template)) {
                val gid = slide.spanGroupId!!
                state.project.slides.filter { it.spanGroupId != gid || it.spanIndex == 0 }.map {
                    if (it.spanGroupId == gid) it.copy(spanGroupId = null, spanIndex = 0, spanCount = 1) else it
                }
            } else {
                state.project.slides
            }

            if (spanSize != null) {
                // Build or resize span group — use post-teardown slide
                val currentSlide = slidesAfterTeardown.find { it.id == slide.id } ?: slide
                val existingGroupId = currentSlide.spanGroupId
                val groupId = existingGroupId ?: Uuid.random().toString()
                val existingCount = if (existingGroupId != null) currentSlide.spanCount else 1
                val sourceElement = currentSlide.elements.firstOrNull()
                val bounds = ElementBounds(0f, 0f, 1f, 1f)

                val slideIdx = slidesAfterTeardown.indexOfFirst { it.id == currentSlide.id }
                if (slideIdx < 0) return@update state
                val updatedFirst = currentSlide.copy(
                    template = template,
                    hasChosenTemplate = true,
                    spanGroupId = groupId,
                    spanIndex = 0,
                    spanCount = spanSize,
                    elements = currentSlide.elements.map { it.copy(bounds = bounds, cropOffsetX = 0f, cropOffsetY = 0f, cropScale = 1f) }.ifEmpty { currentSlide.elements },
                )

                // Create new slides to reach spanSize
                val newSlides = (existingCount until spanSize).map { i ->
                    Slide(
                        template = template,
                        hasChosenTemplate = true,
                        spanGroupId = groupId,
                        spanIndex = i,
                        spanCount = spanSize,
                        elements = if (sourceElement != null) listOf(
                            sourceElement.copy(id = Uuid.random().toString(), bounds = bounds, cropOffsetX = 0f, cropOffsetY = 0f, cropScale = 1f)
                        ) else emptyList(),
                    )
                }

                // Update existing group slides' spanCount if resizing
                val updatedSlides = slidesAfterTeardown.toMutableList()
                updatedSlides[slideIdx] = updatedFirst
                // Update any existing group members (for resize case)
                for (j in updatedSlides.indices) {
                    val s = updatedSlides[j]
                    if (s.spanGroupId == groupId && s.id != currentSlide.id) {
                        updatedSlides[j] = s.copy(template = template, spanCount = spanSize)
                    }
                }
                // If shrinking, remove excess slides
                if (existingGroupId != null && spanSize < existingCount) {
                    updatedSlides.removeAll { it.spanGroupId == groupId && it.spanIndex >= spanSize }
                }
                // Insert new slides after the last group member
                val insertIdx = updatedSlides.indexOfLast { it.spanGroupId == groupId } + 1
                updatedSlides.addAll(insertIdx, newSlides)

                state.copy(
                    project = state.project.copy(slides = updatedSlides),
                    selectedSlideId = updatedFirst.id,
                )
            } else {
                // Non-span template
                val templateBounds = boundsForTemplate(template)
                val currentSlide = slidesAfterTeardown.find { it.id == slide.id } ?: slide
                val resetBorder = template.slotCount > 1
                val updatedElements = currentSlide.elements.mapIndexed { index, element ->
                    val b = templateBounds.getOrElse(index) { element.bounds }
                    element.copy(
                        bounds = b,
                        cropOffsetX = 0f,
                        cropOffsetY = 0f,
                        cropScale = 1f,
                        frameBorderPx = if (resetBorder) 0f else element.frameBorderPx,
                    )
                }
                val updatedSlide = currentSlide.copy(
                    template = template,
                    elements = updatedElements,
                    hasChosenTemplate = true,
                    spanGroupId = null,
                    spanIndex = 0,
                    spanCount = 1,
                )
                state.copy(
                    project = state.project.copy(
                        slides = slidesAfterTeardown.map { if (it.id == slide.id) updatedSlide else it }
                    ),
                )
            }
        }
    }

    fun updateSlideStyle(
        fitMode: MediaFitMode? = null,
        frameBorderPx: Float? = null,
        backgroundColorArgb: Long? = null,
    ) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            fun applyStyle(el: MediaElement) = el.copy(
                fitMode = fitMode ?: el.fitMode,
                frameBorderPx = frameBorderPx ?: el.frameBorderPx,
                backgroundColorArgb = backgroundColorArgb ?: el.backgroundColorArgb,
            )
            val updatedSlide = slide.copy(elements = slide.elements.map { applyStyle(it) })
            state.copy(
                project = state.project.copy(
                    slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                ),
            )
        }
    }

    fun updateSlideGap(gapPx: Float) {
        pushUndo()
        _state.update { state ->
            val slide = state.currentSlide ?: return@update state
            val updatedSlide = slide.copy(gapPx = gapPx.coerceIn(0f, MAX_GAP_PX))
            state.copy(
                project = state.project.copy(
                    slides = state.project.slides.map { if (it.id == slide.id) updatedSlide else it }
                ),
            )
        }
    }

    companion object {
        private const val MAX_UNDO = 50
        const val MAX_GAP_PX = 120f
    }
}
