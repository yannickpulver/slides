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

    init {
        // Select first slide by default
        _state.update { it.copy(selectedSlideId = it.project.slides.firstOrNull()?.id) }
    }

    fun addSlide() {
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

            // Re-apply bounds for all elements when template changed
            val finalElements = if (autoTemplate != slide.template) {
                val newBounds = boundsForTemplate(autoTemplate)
                elements.mapIndexed { i, el ->
                    el.copy(bounds = newBounds.getOrElse(i) { el.bounds })
                }
            } else {
                elements
            }

            val updatedSlide = slide.copy(template = autoTemplate, elements = finalElements)
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
            val idx = state.currentSlideIndex
            if (idx > 0) state.copy(selectedSlideId = slides[idx - 1].id, selectedElementId = null)
            else state
        }
    }

    fun selectNextSlide() {
        _state.update { state ->
            val slides = state.project.slides
            val idx = state.currentSlideIndex
            if (idx < slides.size - 1) state.copy(selectedSlideId = slides[idx + 1].id, selectedElementId = null)
            else state
        }
    }

    @OptIn(ExperimentalUuidApi::class)
    fun applyTemplate(template: SlideTemplate) {
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
                // Build or resize span group
                val existingGroupId = slide.spanGroupId
                val groupId = existingGroupId ?: Uuid.random().toString()
                val existingCount = if (existingGroupId != null) slide.spanCount else 1
                val sourceElement = slide.elements.firstOrNull()
                val bounds = ElementBounds(0f, 0f, 1f, 1f)

                val slideIdx = slidesAfterTeardown.indexOfFirst { it.id == slide.id }
                val updatedFirst = slide.copy(
                    template = template,
                    hasChosenTemplate = true,
                    spanGroupId = groupId,
                    spanIndex = 0,
                    spanCount = spanSize,
                    elements = slide.elements.map { it.copy(bounds = bounds) }.ifEmpty { slide.elements },
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
                            sourceElement.copy(id = Uuid.random().toString(), bounds = bounds)
                        ) else emptyList(),
                    )
                }

                // Update existing group slides' spanCount if resizing
                val updatedSlides = slidesAfterTeardown.toMutableList()
                updatedSlides[slideIdx] = updatedFirst
                // Update any existing group members (for resize case)
                for (j in updatedSlides.indices) {
                    val s = updatedSlides[j]
                    if (s.spanGroupId == groupId && s.id != slide.id) {
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
                val updatedElements = currentSlide.elements.mapIndexed { index, element ->
                    val b = templateBounds.getOrElse(index) { element.bounds }
                    element.copy(bounds = b)
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
}
