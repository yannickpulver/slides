package com.yannickpulver.slides.ui.editor

import com.yannickpulver.slides.model.ElementBounds
import com.yannickpulver.slides.model.MediaElement
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.unit.dp
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.model.SlideTemplate
import com.yannickpulver.slides.model.isSpanTemplate
import com.yannickpulver.slides.ui.filmstrip.Filmstrip
import compose.icons.TablerIcons
import compose.icons.tablericons.ChevronLeft
import compose.icons.tablericons.Download
import compose.icons.tablericons.Plus
import io.github.vinceglb.filekit.dialogs.compose.rememberDirectoryPickerLauncher
import io.github.vinceglb.filekit.path

@Composable
fun EditorScreen(viewModel: EditorViewModel, onBack: (() -> Unit)? = null) {
    val state by viewModel.state.collectAsState()
    val focusRequester = remember { FocusRequester() }
    val currentSlide = state.currentSlide
    val spanGroup = state.currentSpanGroup
    val isSpanActive = spanGroup != null && spanGroup.size > 1
    val representativeElement = currentSlide?.elements?.firstOrNull()
    val showControls = currentSlide != null && currentSlide.hasChosenTemplate
    val showTemplatePicker = currentSlide != null && !currentSlide.hasChosenTemplate

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .focusRequester(focusRequester)
            .focusable()
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown) {
                    when {
                        event.key == Key.Z && event.isMetaPressed && event.isShiftPressed -> {
                            viewModel.redo(); true
                        }
                        event.key == Key.Z && event.isMetaPressed -> {
                            viewModel.undo(); true
                        }
                        event.key == Key.DirectionLeft -> { viewModel.selectPreviousSlide(); true }
                        event.key == Key.DirectionRight -> { viewModel.selectNextSlide(); true }
                        event.key == Key.Escape && onBack != null -> { onBack(); true }
                        else -> false
                    }
                } else false
            },
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            val slides = state.project.slides
            val currentIdx = state.currentSlideIndex
            val aspectRatio = state.project.aspectRatio

            // For span groups, prev/next should skip to outside the group
            val prevSlide: Slide?
            val nextSlide: Slide?
            if (isSpanActive && spanGroup != null) {
                val firstIdx = slides.indexOf(spanGroup.first())
                val lastIdx = slides.indexOf(spanGroup.last())
                prevSlide = slides.getOrNull(firstIdx - 1)
                nextSlide = slides.getOrNull(lastIdx + 1)
            } else {
                prevSlide = slides.getOrNull(currentIdx - 1)
                nextSlide = slides.getOrNull(currentIdx + 1)
            }

            BoxWithConstraints(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceContainerLow)
                    .padding(top = 74.dp),
            ) {
                val density = LocalDensity.current
                val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
                val slideWidth = maxHeight * 0.9f * ratio
                val shiftPx = with(density) { (slideWidth + 24.dp).toPx() }
                val edgeWidth = (maxWidth - slideWidth) / 2

                // Current slide (full size) or span preview
                if (isSpanActive && spanGroup != null) {
                    SpanCanvasPreview(
                        slides = spanGroup,
                        aspectRatio = aspectRatio,
                        onElementCropChanged = { id, ox, oy, s -> viewModel.updateElementCrop(id, ox, oy, s) },
                        onAddImageAtSlot = { slotIndex, path -> viewModel.addElementAtSlot(slotIndex, path) },
                        onTemplateSelected = { viewModel.applyTemplate(it) },
                        modifier = Modifier.fillMaxSize(),
                    )
                } else {
                    SlideCanvas(
                        slide = state.currentSlide,
                        aspectRatio = aspectRatio,
                        selectedElementId = state.selectedElementId,
                        selectedTextOverlayId = state.selectedTextOverlayId,
                        currentTemplate = state.currentSlide?.template,
                        onElementClick = viewModel::selectElement,
                        onCanvasClick = { viewModel.selectElement(null); viewModel.selectTextOverlay(null) },
                        onAddImageAtSlot = { slotIndex, path -> viewModel.addElementAtSlot(slotIndex, path) },
                        onTemplateSelected = { viewModel.applyTemplate(it) },
                        onElementCropChanged = { id, ox, oy, s -> viewModel.updateElementCrop(id, ox, oy, s) },
                        onTextOverlayClick = { viewModel.selectTextOverlay(it) },
                        onTextOverlayPositionChanged = { id, x, y -> viewModel.updateTextOverlayPosition(id, x, y) },
                        onTextOverlayWidthChanged = { id, w -> viewModel.updateTextOverlayWidth(id, w) },
                        onTextOverlayTextChanged = { id, t -> viewModel.updateTextOverlayText(id, t) },
                        modifier = Modifier.fillMaxSize(),
                    )
                }

                // Hide neighbor previews when span is active (they'd overlap the wide canvas)
                if (!isSpanActive) {
                    // Previous slide visual
                    if (prevSlide != null) {
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .graphicsLayer { translationX = -shiftPx }
                                .alpha(0.3f),
                        ) {
                            SlidePreview(slide = prevSlide, aspectRatio = aspectRatio)
                        }
                    }

                    // Next slide visual
                    if (nextSlide != null) {
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .graphicsLayer { translationX = shiftPx }
                                .alpha(0.3f),
                        ) {
                            SlidePreview(slide = nextSlide, aspectRatio = aspectRatio)
                        }
                    }
                }

                // Left edge click area
                if (prevSlide != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .fillMaxHeight()
                            .width(edgeWidth.coerceAtLeast(40.dp))
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) { viewModel.selectPreviousSlide() },
                    )
                }

                // Right edge click area (nav or add)
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .fillMaxHeight()
                        .width(edgeWidth.coerceAtLeast(40.dp))
                        .pointerHoverIcon(PointerIcon.Hand)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) {
                            if (nextSlide != null) viewModel.selectNextSlide()
                            else viewModel.addSlide()
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    if (nextSlide == null) {
                        Icon(
                            TablerIcons.Plus,
                            contentDescription = "Add slide",
                            modifier = Modifier.size(32.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                        )
                    }
                }
            }

            Filmstrip(
                slides = slides,
                selectedSlideId = state.selectedSlideId ?: slides.firstOrNull()?.id,
                selectedSpanGroupId = currentSlide?.spanGroupId,
                aspectRatio = aspectRatio,
                onSlideSelect = viewModel::selectSlide,
                onAddSlide = viewModel::addSlide,
                onRemoveSlide = viewModel::removeSlide,
                onMoveSlide = viewModel::moveSlide,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // Back button + project name top-left
        if (onBack != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.align(Alignment.TopStart).padding(start = 8.dp, top = 36.dp),
            ) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                ) {
                    Icon(
                        TablerIcons.ChevronLeft,
                        contentDescription = "Back to slides",
                        modifier = Modifier.size(20.dp),
                    )
                }
                BasicTextField(
                    value = state.project.name,
                    onValueChange = { viewModel.updateProjectName(it) },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.titleSmall.copy(
                        color = MaterialTheme.colorScheme.onSurface,
                    ),
                    modifier = Modifier.width(200.dp),
                )
            }
        }

        if (showTemplatePicker) {
            TemplatePickerBar(
                onTemplateSelected = { viewModel.applyTemplate(it) },
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 38.dp),
            )
        } else if (state.selectedTextOverlayId != null) {
            val selectedOverlay = currentSlide?.textOverlays?.find { it.id == state.selectedTextOverlayId }
            if (selectedOverlay != null) {
                TextOverlayControls(
                    overlay = selectedOverlay,
                    onStyleChanged = { fontFamily, fontSize, color, alignment ->
                        viewModel.updateTextOverlayStyle(
                            id = selectedOverlay.id,
                            fontFamily = fontFamily,
                            fontSizePx = fontSize,
                            colorArgb = color,
                            alignment = alignment,
                        )
                    },
                    onDelete = { viewModel.removeTextOverlay(selectedOverlay.id) },
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 38.dp),
                )
            }
        } else if (showControls) {
            SlideControls(
                slide = currentSlide,
                representativeElement = representativeElement ?: MediaElement(sourcePath = "", bounds = ElementBounds()),
                onFitModeChanged = { mode ->
                    viewModel.updateSlideStyle(fitMode = mode)
                },
                onFrameBorderPxChanged = { borderPx ->
                    viewModel.updateSlideStyle(frameBorderPx = borderPx)
                },
                onBackgroundColorChanged = { color ->
                    viewModel.updateSlideStyle(backgroundColorArgb = color)
                },
                onGapChanged = { gapPx ->
                    viewModel.updateSlideGap(gapPx)
                },
                onTemplateSelected = { viewModel.applyTemplate(it) },
                onAddText = { viewModel.addTextOverlay() },
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 38.dp),
            )
        }

        // Export buttons top-right
        run {
            var exportScale by remember { mutableStateOf(1) }
            val dirLauncher = rememberDirectoryPickerLauncher { dir ->
                dir?.path?.let { viewModel.exportAllSlides(it, exportScale) }
            }
            val controlHeight = 28.dp

            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = 8.dp, top = 38.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(
                    modifier = Modifier
                        .height(controlHeight)
                        .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                        .clip(RoundedCornerShape(6.dp)),
                ) {
                    AspectRatio.entries.forEachIndexed { index, ratio ->
                        val selected = state.project.aspectRatio == ratio
                        Box(
                            modifier = Modifier
                                .fillMaxHeight()
                                .pointerHoverIcon(PointerIcon.Hand)
                                .then(if (selected) Modifier.background(Color.White) else Modifier)
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null,
                                ) { viewModel.setAspectRatio(ratio) }
                                .padding(horizontal = 10.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                ratio.label,
                                style = MaterialTheme.typography.labelSmall,
                                color = if (selected) Color.Black else MaterialTheme.colorScheme.onSurface,
                            )
                        }
                        if (index < AspectRatio.entries.lastIndex) {
                            Box(Modifier.fillMaxHeight().width(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)))
                        }
                    }
                }
                Text("Export:", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(
                modifier = Modifier
                    .height(controlHeight)
                    .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                    .clip(RoundedCornerShape(6.dp)),
            ) {
                listOf(1, 2).forEachIndexed { index, scale ->
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) {
                                exportScale = scale
                                dirLauncher.launch()
                            }
                            .padding(horizontal = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            Icon(TablerIcons.Download, contentDescription = null, modifier = Modifier.size(12.dp))
                            Text("${scale}x", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                    if (index == 0) {
                        Box(Modifier.fillMaxHeight().width(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)))
                    }
                }
            }
            }
        }

        // Export progress overlay
        val progress = state.exportProgress
        if (progress != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.5f)),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("Exporting...", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(12.dp))
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier.width(240.dp),
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${(progress * 100).toInt()}%",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

expect fun exportSlideAsImage(
    slide: com.yannickpulver.slides.model.Slide,
    aspectRatio: com.yannickpulver.slides.model.AspectRatio,
    outputDir: String,
    scaleFactor: Int = 1,
    slideIndex: Int = 1,
    onProgress: (Float) -> Unit = {},
)
