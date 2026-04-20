package com.yannickpulver.slides.ui.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.ui.filmstrip.Filmstrip
import io.github.vinceglb.filekit.dialogs.compose.rememberDirectoryPickerLauncher
import io.github.vinceglb.filekit.path

@Composable
fun EditorScreen(viewModel: EditorViewModel, onBack: (() -> Unit)? = null) {
    val state by viewModel.state.collectAsState()
    val focusRequester = remember { FocusRequester() }
    val project = state.project
    val slides = project.slides
    val currentSlide = state.currentSlide
    val spanGroup = state.currentSpanGroup
    val selectedElement = currentSlide?.elements?.find { it.id == state.selectedElementId }
        ?: currentSlide?.elements?.firstOrNull()
    val selectedTextOverlay = currentSlide?.textOverlays?.find { it.id == state.selectedTextOverlayId }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    LaunchedEffect(state.selectedSlideId) { focusRequester.requestFocus() }

    var exportScale by remember { mutableStateOf(2) }
    val dirLauncher = rememberDirectoryPickerLauncher { dir ->
        dir?.path?.let { viewModel.exportAllSlides(it, exportScale) }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
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
            EditorTopBar(
                projectName = project.name,
                slideCount = slides.size,
                aspectRatio = project.aspectRatio,
                onNameChanged = viewModel::updateProjectName,
                onAspectRatio = viewModel::setAspectRatio,
                onBack = onBack,
            )

            Row(modifier = Modifier.weight(1f).fillMaxWidth()) {
                SlidesRowCanvas(
                    slides = slides,
                    aspectRatio = project.aspectRatio,
                    selectedSlideId = state.selectedSlideId,
                    selectedElementId = state.selectedElementId,
                    selectedTextOverlayId = state.selectedTextOverlayId,
                    spanGroup = spanGroup,
                    onSelectSlide = viewModel::selectSlide,
                    onSelectElement = viewModel::selectElement,
                    onCanvasClick = {
                        viewModel.selectElement(null); viewModel.selectTextOverlay(null)
                        focusRequester.requestFocus()
                    },
                    onAddImageAtSlot = viewModel::addElementAtSlot,
                    onTemplateSelected = viewModel::applyTemplate,
                    onElementCropChanged = viewModel::updateElementCrop,
                    onTextOverlayClick = viewModel::selectTextOverlay,
                    onTextOverlayPositionChanged = viewModel::updateTextOverlayPosition,
                    onTextOverlayWidthChanged = viewModel::updateTextOverlayWidth,
                    onTextOverlayTextChanged = viewModel::updateTextOverlayText,
                    modifier = Modifier.weight(1f).fillMaxHeight(),
                )

                EditorSidebar(
                    slide = currentSlide,
                    slideIndex = state.currentSlideIndex.coerceAtLeast(0),
                    canDeleteSlide = slides.size > 1 && currentSlide != null,
                    selectedElement = selectedElement,
                    selectedTextOverlay = selectedTextOverlay,
                    onTemplateSelected = viewModel::applyTemplate,
                    onBackgroundColor = { argb -> viewModel.updateSlideStyle(backgroundColorArgb = argb) },
                    onGapChanged = viewModel::updateSlideGap,
                    onFitMode = { mode -> viewModel.updateSlideStyle(fitMode = mode) },
                    onBorderChanged = { border -> viewModel.updateSlideStyle(frameBorderPx = border) },
                    onAddText = viewModel::addTextOverlay,
                    onTextStyle = { fontFamily, size, color, alignment ->
                        val id = selectedTextOverlay?.id ?: return@EditorSidebar
                        viewModel.updateTextOverlayStyle(id, fontFamily, size, color, alignment)
                    },
                    onTextDelete = {
                        selectedTextOverlay?.id?.let { viewModel.removeTextOverlay(it) }
                    },
                    onDeleteSlide = {
                        currentSlide?.id?.let { viewModel.removeSlide(it) }
                    },
                    onExport = { scale ->
                        exportScale = scale
                        dirLauncher.launch()
                    },
                )
            }

            Filmstrip(
                slides = slides,
                selectedSlideId = state.selectedSlideId ?: slides.firstOrNull()?.id,
                selectedSpanGroupId = currentSlide?.spanGroupId,
                aspectRatio = project.aspectRatio,
                onSlideSelect = viewModel::selectSlide,
                onAddSlide = viewModel::addSlide,
                onRemoveSlide = viewModel::removeSlide,
                onMoveSlide = viewModel::moveSlide,
                modifier = Modifier.fillMaxWidth(),
            )
        }

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
                        .background(MaterialTheme.colorScheme.surfaceContainer)
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

@Composable
private fun SlidesRowCanvas(
    slides: List<Slide>,
    aspectRatio: AspectRatio,
    selectedSlideId: String?,
    selectedElementId: String?,
    selectedTextOverlayId: String?,
    spanGroup: List<Slide>?,
    onSelectSlide: (String) -> Unit,
    onSelectElement: (String?) -> Unit,
    onCanvasClick: () -> Unit,
    onAddImageAtSlot: (Int, String) -> Unit,
    onTemplateSelected: (com.yannickpulver.slides.model.SlideTemplate) -> Unit,
    onElementCropChanged: (String, Float, Float, Float) -> Unit,
    onTextOverlayClick: (String) -> Unit,
    onTextOverlayPositionChanged: (String, Float, Float) -> Unit,
    onTextOverlayWidthChanged: (String, Float) -> Unit,
    onTextOverlayTextChanged: (String, String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val groups = remember(slides) { groupSlides(slides) }
    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()

    BoxWithConstraints(
        modifier = modifier.background(MaterialTheme.colorScheme.surfaceContainerLowest),
    ) {
        val canvasW = maxWidth
        val canvasH = maxHeight
        val padding = 40.dp
        val gap = 20.dp
        val density = LocalDensity.current
        val slideHeight = (canvasH - padding * 2).coerceAtLeast(160.dp)
        val slideWidth = slideHeight * ratio
        val viewportPx = with(density) { canvasW.toPx() }
        val gapPxF = with(density) { gap.toPx() }
        val paddingPxF = with(density) { padding.toPx() }
        val slideWidthPx = with(density) { slideWidth.toPx() }

        val scrollState = rememberScrollState()
        val selectedGroupIdx = groups.indexOfFirst { g -> g.any { it.id == selectedSlideId } }

        LaunchedEffect(selectedGroupIdx, viewportPx, slides.size) {
            if (selectedGroupIdx < 0) return@LaunchedEffect
            var offset = paddingPxF
            for (i in 0 until selectedGroupIdx) {
                offset += slideWidthPx * groups[i].size + gapPxF
            }
            val selectedWidthPx = slideWidthPx * groups[selectedGroupIdx].size
            val selectedCenter = offset + selectedWidthPx / 2f
            val target = (selectedCenter - viewportPx / 2f).coerceAtLeast(0f).toInt()
            scrollState.animateScrollTo(target)
        }

        Row(
            modifier = Modifier
                .horizontalScroll(scrollState)
                .fillMaxHeight()
                .widthIn(min = canvasW)
                .padding(horizontal = padding, vertical = padding),
            horizontalArrangement = Arrangement.spacedBy(gap, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            groups.forEach { group ->
                val groupSelected = group.any { it.id == selectedSlideId }
                val isSpanSelected = groupSelected && group.size > 1 && spanGroup != null

                Box(
                    modifier = Modifier
                        .width(slideWidth * group.size)
                        .height(slideHeight)
                        .shadow(
                            elevation = if (groupSelected) 16.dp else 8.dp,
                            shape = RoundedCornerShape(2.dp),
                        )
                        .background(Color.Transparent),
                ) {
                    if (isSpanSelected && spanGroup != null) {
                        SpanCanvasPreview(
                            slides = spanGroup,
                            aspectRatio = aspectRatio,
                            onElementCropChanged = onElementCropChanged,
                            onAddImageAtSlot = onAddImageAtSlot,
                            onTemplateSelected = onTemplateSelected,
                            modifier = Modifier.fillMaxSize(),
                            fillFraction = 1f,
                        )
                    } else {
                        Row(modifier = Modifier.fillMaxSize()) {
                            group.forEach { slide ->
                                val slideSelected = slide.id == selectedSlideId
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .then(
                                            if (!slideSelected) Modifier
                                                .pointerHoverIcon(PointerIcon.Hand)
                                                .clickable(
                                                    interactionSource = remember(slide.id) { MutableInteractionSource() },
                                                    indication = null,
                                                ) { onSelectSlide(slide.id) }
                                            else Modifier,
                                        ),
                                ) {
                                    if (slideSelected) {
                                        SlideCanvas(
                                            slide = slide,
                                            aspectRatio = aspectRatio,
                                            selectedElementId = selectedElementId,
                                            selectedTextOverlayId = selectedTextOverlayId,
                                            currentTemplate = slide.template,
                                            onElementClick = onSelectElement,
                                            onCanvasClick = onCanvasClick,
                                            onAddImageAtSlot = onAddImageAtSlot,
                                            onTemplateSelected = onTemplateSelected,
                                            onElementCropChanged = onElementCropChanged,
                                            onTextOverlayClick = onTextOverlayClick,
                                            onTextOverlayPositionChanged = onTextOverlayPositionChanged,
                                            onTextOverlayWidthChanged = onTextOverlayWidthChanged,
                                            onTextOverlayTextChanged = onTextOverlayTextChanged,
                                            modifier = Modifier.fillMaxSize(),
                                            fillFraction = 1f,
                                        )
                                    } else {
                                        SlidePreview(
                                            slide = slide,
                                            aspectRatio = aspectRatio,
                                            fillFraction = 1f,
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if (groupSelected) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .border(1.5.dp, MaterialTheme.colorScheme.primary),
                        )
                    }

                    if (group.size > 1) {
                        Box(
                            modifier = Modifier
                                .align(Alignment.TopStart)
                                .padding(10.dp)
                                .background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(10.dp))
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                        ) {
                            Text(
                                "PAN · ${group.size} PANELS",
                                fontSize = 9.sp,
                                color = Color.White.copy(alpha = 0.9f),
                                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                            )
                        }
                    }
                }
            }
        }
    }
}

internal fun groupSlides(slides: List<Slide>): List<List<Slide>> {
    val out = mutableListOf<MutableList<Slide>>()
    var cur: MutableList<Slide>? = null
    for (s in slides) {
        val gid = s.spanGroupId
        val last = cur
        if (gid != null && last != null && last.first().spanGroupId == gid) {
            last.add(s)
        } else {
            val fresh = mutableListOf(s)
            cur = fresh
            out.add(fresh)
        }
    }
    return out
}

expect fun exportSlideAsImage(
    slide: com.yannickpulver.slides.model.Slide,
    aspectRatio: com.yannickpulver.slides.model.AspectRatio,
    outputDir: String,
    scaleFactor: Int = 1,
    slideIndex: Int = 1,
    onProgress: (Float) -> Unit = {},
)
