package com.yannickpulver.slides.ui.editor

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.rememberScrollState
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.draw.shadow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.DragData
import androidx.compose.ui.draganddrop.dragData
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.zIndex
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaFitMode
import com.yannickpulver.slides.model.MediaType
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.model.SlideTemplate
import com.yannickpulver.slides.model.spanSize
import com.yannickpulver.slides.template.boundsForTemplate
import compose.icons.TablerIcons
import compose.icons.tablericons.Photo
import compose.icons.tablericons.PlayerPlay
import compose.icons.tablericons.Refresh
import io.github.kdroidfilter.composemediaplayer.VideoPlayerSurface
import io.github.kdroidfilter.composemediaplayer.rememberVideoPlayerState
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.dialogs.FileKitType
import io.github.vinceglb.filekit.path
import kotlin.math.max
import kotlin.math.roundToInt

@OptIn(ExperimentalComposeUiApi::class, ExperimentalFoundationApi::class)
@Composable
fun SlideCanvas(
    slide: Slide?,
    aspectRatio: AspectRatio,
    selectedElementId: String?,
    selectedTextOverlayId: String?,
    currentTemplate: SlideTemplate?,
    onElementClick: (String) -> Unit,
    onCanvasClick: () -> Unit,
    onAddImageAtSlot: (Int, String) -> Unit,
    onTemplateSelected: (SlideTemplate) -> Unit,
    onElementCropChanged: (String, Float, Float, Float) -> Unit,
    onTextOverlayClick: (String) -> Unit,
    onTextOverlayPositionChanged: (String, Float, Float) -> Unit,
    onTextOverlayWidthChanged: (String, Float) -> Unit,
    onTextOverlayTextChanged: (String, String) -> Unit,
    modifier: Modifier = Modifier,
    fillFraction: Float = 0.9f,
) {
    if (slide == null) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("No slide selected", style = MaterialTheme.typography.bodyLarge)
        }
        return
    }

    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
    val slotBounds = boundsForTemplate(slide.template)

    // Canvas-level drop: multiple files → auto-expand template
    val canvasDropTarget = remember(slide.id) {
        fileDropTarget { paths ->
            if (paths.size > 1) {
                paths.forEachIndexed { i, path ->
                    if (i < 3) onAddImageAtSlot(i, path)
                }
            } else {
                // Single file on canvas: add to next empty slot
                val nextSlot = slide.elements.size
                if (nextSlot < slotBounds.size) {
                    paths.firstOrNull()?.let { onAddImageAtSlot(nextSlot, it) }
                }
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .dragAndDropTarget(shouldStartDragAndDrop = { true }, target = canvasDropTarget),
        contentAlignment = Alignment.Center,
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxHeight(fillFraction)
                .aspectRatio(ratio)
                .background(
                    if (slide.gapPx > 0f) slide.backgroundColorArgb.toComposeColor()
                    else Color.White
                )
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onCanvasClick() },
        ) {
            val density = LocalDensity.current
            val displayScale = constraints.maxWidth.toFloat() / aspectRatio.width.toFloat()
            val gapDp = with(density) { (slide.gapPx * displayScale).toDp() }
            Column(
                modifier = Modifier.fillMaxSize().clipToBounds(),
                verticalArrangement = if (slide.gapPx > 0f) Arrangement.spacedBy(gapDp) else Arrangement.Top,
            ) {
                slotBounds.forEachIndexed { slotIndex, bounds ->
                    val element = slide.elements.find { it.bounds == bounds }
                    val slotDropTarget = remember(slide.id, slotIndex) {
                        fileDropTarget { paths ->
                            paths.forEachIndexed { i, path ->
                                onAddImageAtSlot(slotIndex + i, path)
                            }
                        }
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(bounds.height)
                            .dragAndDropTarget(
                                shouldStartDragAndDrop = { true },
                                target = slotDropTarget,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (element != null) {
                            key(element.id) {
                                FilledSlot(
                                    element = element,
                                    logicalSlotWidth = aspectRatio.width * bounds.width,
                                    logicalSlotHeight = aspectRatio.height * bounds.height,
                                    isSelected = element.id == selectedElementId,
                                    onClick = { onElementClick(element.id) },
                                    onCropChanged = { ox, oy, s ->
                                        onElementCropChanged(element.id, ox, oy, s)
                                    },
                                    onReplaceImage = { path -> onAddImageAtSlot(slotIndex, path) },
                                    stackIndex = slotIndex,
                                    stackCount = slotBounds.size,
                                )
                            }
                        } else {
                            EmptySlot(
                                onAddImage = { path -> onAddImageAtSlot(slotIndex, path) },
                            )
                        }
                    }
                }
            }

            // Text overlay layer — on top of everything
            slide.textOverlays.forEach { overlay ->
                TextOverlayBox(
                    overlay = overlay,
                    canvasWidth = constraints.maxWidth.toFloat(),
                    canvasHeight = constraints.maxHeight.toFloat(),
                    isSelected = overlay.id == selectedTextOverlayId,
                    onClick = { onTextOverlayClick(overlay.id) },
                    onPositionChanged = { x, y -> onTextOverlayPositionChanged(overlay.id, x, y) },
                    onWidthChanged = { w -> onTextOverlayWidthChanged(overlay.id, w) },
                    onTextChanged = { t -> onTextOverlayTextChanged(overlay.id, t) },
                )
            }

        }

        if (slide.elements.any { it.type == MediaType.VIDEO }) {
            Text(
                "Click the video to start / stop",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 4.dp),
            )
        }
    }
}

// ── Span canvas preview (multiple slides side-by-side) ────────────────

@OptIn(ExperimentalComposeUiApi::class, ExperimentalFoundationApi::class)
@Composable
fun SpanCanvasPreview(
    slides: List<Slide>,
    aspectRatio: AspectRatio,
    selectedTextOverlayId: String?,
    onElementCropChanged: (String, Float, Float, Float) -> Unit,
    onAddImageAtSlot: (Int, String) -> Unit,
    onTemplateSelected: (SlideTemplate) -> Unit,
    onTextOverlayClick: (String) -> Unit,
    onTextOverlayMove: (String, String, Float, Float) -> Unit,
    onTextOverlayWidthChanged: (String, Float) -> Unit,
    onTextOverlayTextChanged: (String, String) -> Unit,
    modifier: Modifier = Modifier,
    fillFraction: Float = 0.9f,
) {
    val spanCount = slides.size
    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
    val element = slides.firstOrNull()?.elements?.firstOrNull()
    val density = LocalDensity.current

    // Shared crop state
    var ox by remember(slides.firstOrNull()?.spanGroupId) { mutableStateOf(0f) }
    var oy by remember(slides.firstOrNull()?.spanGroupId) { mutableStateOf(0f) }
    var scale by remember(slides.firstOrNull()?.spanGroupId) { mutableStateOf(element?.cropScale ?: 1f) }
    var singleSlotSize by remember { mutableStateOf(IntSize.Zero) }
    var imgSize by remember(element?.sourcePath) { mutableStateOf(IntSize.Zero) }
    var initialized by remember(slides.firstOrNull()?.spanGroupId) { mutableStateOf(false) }
    val cropEnabled = element?.fitMode == MediaFitMode.FILL

    // Denormalize offsets
    LaunchedEffect(slides.firstOrNull()?.spanGroupId, singleSlotSize) {
        if (singleSlotSize.width > 0 && !initialized && element != null) {
            ox = element.cropOffsetX * singleSlotSize.width
            oy = element.cropOffsetY * singleSlotSize.height
            initialized = true
        }
    }

    fun clamp() {
        if (!cropEnabled || element == null) return
        val sw = singleSlotSize.width.toFloat()
        val sh = singleSlotSize.height.toFloat()
        val iw = imgSize.width.toFloat().coerceAtLeast(1f)
        val ih = imgSize.height.toFloat().coerceAtLeast(1f)
        val virtualWidth = sw * spanCount
        val logicalW = aspectRatio.width.toFloat()
        val logicalH = aspectRatio.height.toFloat()
        val inset = computeFrameInsetPx(
            slotWidth = virtualWidth,
            slotHeight = sh,
            logicalSlotWidth = logicalW * spanCount,
            logicalSlotHeight = logicalH,
            frameBorderPx = element.frameBorderPx,
        )
        val availW = (virtualWidth - inset * 2f).coerceAtLeast(1f)
        val availH = (sh - inset * 2f).coerceAtLeast(1f)
        val fillScale = max(availW / iw, availH / ih)
        val drawW = iw * fillScale * scale
        val drawH = ih * fillScale * scale
        val maxOx = ((drawW - availW) / 2f).coerceAtLeast(0f)
        val maxOy = ((drawH - availH) / 2f).coerceAtLeast(0f)
        ox = ox.coerceIn(-maxOx, maxOx)
        oy = oy.coerceIn(-maxOy, maxOy)
    }

    fun saveOffsets() {
        val sw = singleSlotSize.width.toFloat().coerceAtLeast(1f)
        val sh = singleSlotSize.height.toFloat().coerceAtLeast(1f)
        val firstEl = slides.firstOrNull()?.elements?.firstOrNull() ?: return
        onElementCropChanged(firstEl.id, ox / sw, oy / sh, scale)
    }

    // File picker for adding images to empty span
    val filePicker = rememberFilePickerLauncher(type = FileKitType.Image) { file ->
        file?.path?.let { onAddImageAtSlot(0, it) }
    }

    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth(fillFraction)
                .fillMaxHeight(fillFraction)
                .aspectRatio(ratio * spanCount, matchHeightConstraintsFirst = true)
                .clipToBounds()
                .then(
                    if (cropEnabled && element != null) {
                        Modifier.pointerInput(slides.firstOrNull()?.spanGroupId) {
                            detectTransformGestures { _, pan, zoom, _ ->
                                scale = (scale * zoom).coerceIn(1f, 5f)
                                ox += pan.x
                                oy += pan.y
                                clamp()
                                saveOffsets()
                            }
                        }
                    } else Modifier
                ),
        ) {
            if (element != null) {
                // Render each slide's slice side-by-side
                Row(modifier = Modifier.fillMaxSize()) {
                    slides.forEachIndexed { i, slide ->
                        val el = slide.elements.firstOrNull() ?: return@forEachIndexed
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .clipToBounds()
                                .background(el.backgroundColorArgb.toComposeColor())
                                .onSizeChanged { if (i == 0) singleSlotSize = it },
                            contentAlignment = Alignment.Center,
                        ) {
                            SpanSliceContent(
                                element = el,
                                singleSlotSize = singleSlotSize,
                                spanCount = spanCount,
                                spanIndex = i,
                                offsetX = ox,
                                offsetY = oy,
                                scale = scale,
                                logicalSlotWidth = aspectRatio.width.toFloat(),
                                logicalSlotHeight = aspectRatio.height.toFloat(),
                                onImageSizeKnown = { w, h ->
                                    imgSize = IntSize(w, h)
                                    clamp()
                                },
                            )
                            val frameInsetPx = computeFrameInsetPx(
                                slotWidth = singleSlotSize.width.toFloat() * spanCount,
                                slotHeight = singleSlotSize.height.toFloat(),
                                logicalSlotWidth = aspectRatio.width.toFloat() * spanCount,
                                logicalSlotHeight = aspectRatio.height.toFloat(),
                                frameBorderPx = el.frameBorderPx,
                            )
                            BorderMaskOverlay(
                                insetPx = frameInsetPx,
                                color = el.backgroundColorArgb.toComposeColor(),
                                drawLeft = i == 0,
                                drawRight = i == spanCount - 1,
                            )
                        }
                    }
                }
            } else {
                // Empty span — show drop target / file picker
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.White)
                        .clickable { filePicker.launch() }
                        .pointerHoverIcon(PointerIcon.Hand),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        TablerIcons.Photo,
                        contentDescription = "Add image",
                        modifier = Modifier.size(48.dp),
                        tint = Color.LightGray,
                    )
                }
            }

            if (element != null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.55f))
                        .pointerHoverIcon(PointerIcon.Hand)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { filePicker.launch() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        TablerIcons.Refresh,
                        contentDescription = "Change image",
                        tint = Color.White,
                        modifier = Modifier.size(13.dp),
                    )
                }
            }

            // Text overlays — span-level layer. Overlay.x/width are normalized per slide;
            // rebase into virtual span coords so user can drag across slices.
            val virtualWidth = constraints.maxWidth.toFloat()
            val virtualHeight = constraints.maxHeight.toFloat()
            val sliceWidthPx = if (spanCount > 0) virtualWidth / spanCount else virtualWidth
            slides.forEachIndexed { sliceIdx, slide ->
                slide.textOverlays.forEach { overlay ->
                    key(overlay.id) {
                        val virtualX = (sliceIdx + overlay.x) * sliceWidthPx / virtualWidth
                        val virtualWidthFrac = overlay.width / spanCount
                        TextOverlayBox(
                            overlay = overlay.copy(x = virtualX, width = virtualWidthFrac),
                            canvasWidth = virtualWidth,
                            canvasHeight = virtualHeight,
                            isSelected = overlay.id == selectedTextOverlayId,
                            onClick = { onTextOverlayClick(overlay.id) },
                            onPositionChanged = { newX, newY ->
                                val absPx = newX * virtualWidth
                                val targetIdx = (absPx / sliceWidthPx).toInt().coerceIn(0, spanCount - 1)
                                val localX = ((absPx - targetIdx * sliceWidthPx) / sliceWidthPx).coerceIn(0f, 1f)
                                onTextOverlayMove(overlay.id, slides[targetIdx].id, localX, newY)
                            },
                            onWidthChanged = { newVirtualFrac ->
                                onTextOverlayWidthChanged(overlay.id, newVirtualFrac * spanCount)
                            },
                            onTextChanged = { t -> onTextOverlayTextChanged(overlay.id, t) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SpanSliceContent(
    element: MediaElement,
    singleSlotSize: IntSize,
    spanCount: Int,
    spanIndex: Int,
    offsetX: Float,
    offsetY: Float,
    scale: Float,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    onImageSizeKnown: (Int, Int) -> Unit,
) {
    var bitmap by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    var loading by remember(element.sourcePath) { mutableStateOf(bitmap == null) }
    LaunchedEffect(element.sourcePath) {
        if (bitmap == null) {
            bitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
            loading = false
        }
    }
    val density = LocalDensity.current

    LaunchedEffect(bitmap) {
        bitmap?.let { onImageSizeKnown(it.width, it.height) }
    }

    val currentBitmap = bitmap
    when {
        currentBitmap != null -> {
            val iw = currentBitmap.width.toFloat()
            val ih = currentBitmap.height.toFloat()
            val sw = singleSlotSize.width.toFloat()
            val sh = singleSlotSize.height.toFloat()
            val virtualWidth = sw * spanCount
            val virtualLogicalWidth = logicalSlotWidth * spanCount

            // Compute frame for full virtual canvas
            val frame = computeMediaFrame(
                slotWidth = virtualWidth,
                slotHeight = sh,
                mediaWidth = iw,
                mediaHeight = ih,
                fitMode = element.fitMode,
                cropOffsetX = offsetX * spanCount, // scale pixel offset to virtual width
                cropOffsetY = offsetY,
                cropScale = scale,
                frameBorderPx = element.frameBorderPx,
                logicalSlotWidth = virtualLogicalWidth,
                logicalSlotHeight = logicalSlotHeight,
            )

            // Shift to show only this slice — compensate for per-slot centering vs virtual centering
            val sliceShiftX = frame.shiftX + (virtualWidth - sw) / 2f - (spanIndex * sw)
            val drawWDp = with(density) { frame.drawWidth.toDp() }
            val drawHDp = with(density) { frame.drawHeight.toDp() }

            Image(
                bitmap = currentBitmap,
                contentDescription = null,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(sliceShiftX.roundToInt(), frame.shiftY.roundToInt()) },
                contentScale = ContentScale.FillBounds,
            )
        }
        else -> {
            Box(Modifier.fillMaxSize().background(Color(0xFFF5F5F5)), contentAlignment = Alignment.Center) {
                if (loading) CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            }
        }
    }
}

// ── Filled slot with pan, pinch, handles ────────────────────────────────

@Composable
private fun FilledSlot(
    element: MediaElement,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    isSelected: Boolean,
    onClick: () -> Unit,
    onCropChanged: (Float, Float, Float) -> Unit,
    onReplaceImage: (String) -> Unit,
    stackIndex: Int = 0,
    stackCount: Int = 1,
) {
    // Offsets stored normalized (fraction of slot size), work in pixels internally
    var ox by remember(element.id) { mutableStateOf(0f) }
    var oy by remember(element.id) { mutableStateOf(0f) }
    var scale by remember(element.id) { mutableStateOf(element.cropScale) }
    var slotSize by remember { mutableStateOf(IntSize.Zero) }
    var imgSize by remember(element.id) { mutableStateOf(IntSize.Zero) }
    var videoToggle by remember(element.id) { mutableStateOf<(() -> Unit)?>(null) }
    var initialized by remember(element.id) { mutableStateOf(false) }
    val cropEnabled = element.fitMode == MediaFitMode.FILL

    // Denormalize offsets when slot size becomes available
    LaunchedEffect(element.id, slotSize) {
        if (slotSize.width > 0 && !initialized) {
            ox = element.cropOffsetX * slotSize.width
            oy = element.cropOffsetY * slotSize.height
            initialized = true
        }
    }

    // Reset local state when model crop is zeroed (e.g. layout switch)
    LaunchedEffect(element.cropOffsetX, element.cropOffsetY, element.cropScale) {
        if (element.cropOffsetX == 0f && element.cropOffsetY == 0f && element.cropScale == 1f && initialized) {
            ox = 0f
            oy = 0f
            scale = 1f
        }
    }

    fun minScale(): Float = 1f

    fun clamp() {
        if (!cropEnabled) return
        val sw = slotSize.width.toFloat()
        val sh = slotSize.height.toFloat()
        val iw = imgSize.width.toFloat().coerceAtLeast(1f)
        val ih = imgSize.height.toFloat().coerceAtLeast(1f)
        val inset = computeFrameInsetPx(
            slotWidth = sw,
            slotHeight = sh,
            logicalSlotWidth = logicalSlotWidth,
            logicalSlotHeight = logicalSlotHeight,
            frameBorderPx = element.frameBorderPx,
        )
        val availableWidth = (sw - inset * 2f).coerceAtLeast(1f)
        val availableHeight = (sh - inset * 2f).coerceAtLeast(1f)
        val cropScale = max(availableWidth / iw, availableHeight / ih)
        val drawW = iw * cropScale * scale
        val drawH = ih * cropScale * scale
        val maxOx = ((drawW - availableWidth) / 2f).coerceAtLeast(0f)
        val maxOy = ((drawH - availableHeight) / 2f).coerceAtLeast(0f)
        ox = ox.coerceIn(-maxOx, maxOx)
        oy = oy.coerceIn(-maxOy, maxOy)
    }

    // Save normalized offsets
    fun saveOffsets() {
        val sw = slotSize.width.toFloat().coerceAtLeast(1f)
        val sh = slotSize.height.toFloat().coerceAtLeast(1f)
        onCropChanged(ox / sw, oy / sh, scale)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(element.backgroundColorArgb.toComposeColor())
            .clipToBounds()
            .onSizeChanged { slotSize = it }
            .pointerInput(element.id) {
                detectTapGestures {
                    onClick()
                    videoToggle?.invoke()
                }
            }
            .then(
                if (cropEnabled) {
                    Modifier.pointerInput(element.id) {
                        detectTransformGestures { _, pan, zoom, _ ->
                            scale = (scale * zoom).coerceIn(minScale(), 5f)
                            ox += pan.x
                            oy += pan.y
                            clamp()
                            saveOffsets()
                        }
                    }
                } else {
                    Modifier
                }
            ),
    ) {
        val drawTop = stackIndex == 0
        val drawBottom = stackIndex == stackCount - 1
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (element.type == MediaType.VIDEO) {
                VideoSlotContent(
                    element = element,
                    offsetX = ox, offsetY = oy, scale = scale,
                    slotSize = slotSize,
                    logicalSlotWidth = logicalSlotWidth,
                    logicalSlotHeight = logicalSlotHeight,
                    drawTop = drawTop,
                    drawBottom = drawBottom,
                    onImageSizeKnown = { w, h ->
                        imgSize = IntSize(w, h)
                        clamp()
                    },
                    onToggleReady = { videoToggle = it },
                )
            } else {
                ImageSlotContent(
                    element = element,
                    offsetX = ox, offsetY = oy, scale = scale,
                    slotSize = slotSize,
                    logicalSlotWidth = logicalSlotWidth,
                    logicalSlotHeight = logicalSlotHeight,
                    drawTop = drawTop,
                    drawBottom = drawBottom,
                    onImageSizeKnown = { w, h ->
                        imgSize = IntSize(w, h)
                        clamp()
                    },
                )
            }
        }

        val frameInsetPx = computeFrameInsetPx(
            slotWidth = slotSize.width.toFloat(),
            slotHeight = slotSize.height.toFloat(),
            logicalSlotWidth = logicalSlotWidth,
            logicalSlotHeight = logicalSlotHeight,
            frameBorderPx = element.frameBorderPx,
        )
        BorderMaskOverlay(
            insetPx = frameInsetPx,
            color = element.backgroundColorArgb.toComposeColor(),
            drawTop = stackIndex == 0,
            drawBottom = stackIndex == stackCount - 1,
        )

        val replacePicker = rememberFilePickerLauncher(type = FileKitType.Image) { file ->
            file?.path?.let { onReplaceImage(it) }
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp)
                .size(26.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.55f))
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { replacePicker.launch() },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                TablerIcons.Refresh,
                contentDescription = "Change image",
                tint = Color.White,
                modifier = Modifier.size(13.dp),
            )
        }

        // Corner resize handles at image corners
        if (isSelected && cropEnabled && slotSize.width > 0 && imgSize.width > 0) {
            CornerHandles(
                scale = scale,
                offsetX = ox,
                offsetY = oy,
                slotSize = slotSize,
                logicalSlotWidth = logicalSlotWidth,
                logicalSlotHeight = logicalSlotHeight,
                frameBorderPx = element.frameBorderPx,
                imgSize = imgSize,
                onScaleChange = { newScale ->
                    scale = newScale.coerceIn(minScale(), 5f)
                    clamp()
                    saveOffsets()
                },
                onScaleEnd = {},
            )
        }
    }
}

@Composable
private fun BorderMaskOverlay(
    insetPx: Float,
    color: Color,
    drawTop: Boolean = true,
    drawBottom: Boolean = true,
    drawLeft: Boolean = true,
    drawRight: Boolean = true,
) {
    if (insetPx <= 0f) return
    val density = LocalDensity.current
    val insetDp = with(density) { insetPx.toDp() }
    Box(modifier = Modifier.fillMaxSize()) {
        if (drawTop) Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .height(insetDp)
                .background(color),
        )
        if (drawBottom) Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(insetDp)
                .background(color),
        )
        if (drawLeft) Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .fillMaxHeight()
                .width(insetDp)
                .background(color),
        )
        if (drawRight) Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .fillMaxHeight()
                .width(insetDp)
                .background(color),
        )
    }
}

@Composable
private fun CornerHandles(
    scale: Float,
    offsetX: Float,
    offsetY: Float,
    slotSize: IntSize,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    frameBorderPx: Float,
    imgSize: IntSize,
    onScaleChange: (Float) -> Unit,
    onScaleEnd: () -> Unit,
) {
    val armLen = 20.dp
    val hitArea = 28.dp
    val strokeW = 2.5.dp
    val density = LocalDensity.current
    val sw = slotSize.width.toFloat()
    val sh = slotSize.height.toFloat()
    val hitPx = with(density) { hitArea.toPx().toInt() }
    val halfHit = hitPx / 2

    // Compute actual image rect within the slot
    val iw = imgSize.width.toFloat().coerceAtLeast(1f)
    val ih = imgSize.height.toFloat().coerceAtLeast(1f)
    val inset = computeFrameInsetPx(
        slotWidth = sw,
        slotHeight = sh,
        logicalSlotWidth = logicalSlotWidth,
        logicalSlotHeight = logicalSlotHeight,
        frameBorderPx = frameBorderPx,
    )
    val availableWidth = (sw - inset * 2f).coerceAtLeast(1f)
    val availableHeight = (sh - inset * 2f).coerceAtLeast(1f)
    val cropScale = max(availableWidth / iw, availableHeight / ih)
    val drawW = iw * cropScale * scale
    val drawH = ih * cropScale * scale
    // Image is centered in slot, then offset
    val imgLeft = ((sw - drawW) / 2f + offsetX).toInt()
    val imgTop = ((sh - drawH) / 2f + offsetY).toInt()
    val imgRight = imgLeft + drawW.toInt()
    val imgBottom = imgTop + drawH.toInt()

    data class Corner(val x: Int, val y: Int, val sign: Float, val flipX: Boolean, val flipY: Boolean)
    val corners = listOf(
        Corner(imgLeft - halfHit, imgTop - halfHit, -1f, false, false),
        Corner(imgRight - halfHit, imgTop - halfHit, 1f, true, false),
        Corner(imgLeft - halfHit, imgBottom - halfHit, 1f, false, true),
        Corner(imgRight - halfHit, imgBottom - halfHit, 1f, true, true),
    )

    corners.forEach { corner ->
        Box(
            modifier = Modifier
                .zIndex(10f)
                .offset { IntOffset(corner.x, corner.y) }
                .size(hitArea)
                .pointerInput(scale) {
                    detectDragGestures(
                        onDragEnd = { onScaleEnd() },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            val delta = (dragAmount.x + dragAmount.y) * corner.sign / 2f
                            val factor = 1f + delta / with(density) { 200.dp.toPx() }
                            onScaleChange(scale * factor)
                        },
                    )
                },
        ) {
            androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
                val arm = armLen.toPx()
                val stroke = strokeW.toPx()
                val startX = if (corner.flipX) size.width else 0f
                val startY = if (corner.flipY) size.height else 0f
                val dirX = if (corner.flipX) -1f else 1f
                val dirY = if (corner.flipY) -1f else 1f

                // Shadow
                drawLine(Color.Black.copy(alpha = 0.3f),
                    Offset(startX + 1f, startY + 1f),
                    Offset(startX + arm * dirX + 1f, startY + 1f),
                    strokeWidth = stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
                drawLine(Color.Black.copy(alpha = 0.3f),
                    Offset(startX + 1f, startY + 1f),
                    Offset(startX + 1f, startY + arm * dirY + 1f),
                    strokeWidth = stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
                // White L-bracket
                drawLine(Color.White, Offset(startX, startY), Offset(startX + arm * dirX, startY),
                    strokeWidth = stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
                drawLine(Color.White, Offset(startX, startY), Offset(startX, startY + arm * dirY),
                    strokeWidth = stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
            }
        }
    }
}

// ── Image content with async loading ────────────────────────────────────

@Composable
private fun ImageSlotContent(
    element: MediaElement,
    offsetX: Float,
    offsetY: Float,
    scale: Float,
    slotSize: IntSize,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    onImageSizeKnown: (Int, Int) -> Unit,
    drawTop: Boolean = true,
    drawBottom: Boolean = true,
    drawLeft: Boolean = true,
    drawRight: Boolean = true,
) {
    var bitmap by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    var loading by remember(element.sourcePath) { mutableStateOf(bitmap == null) }
    LaunchedEffect(element.sourcePath) {
        if (bitmap == null) {
            bitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
            loading = false
        }
    }
    val density = LocalDensity.current

    LaunchedEffect(bitmap) {
        bitmap?.let { onImageSizeKnown(it.width, it.height) }
    }

    val currentBitmap = bitmap
    when {
        currentBitmap != null -> {
            val iw = currentBitmap.width.toFloat()
            val ih = currentBitmap.height.toFloat()
            val sw = slotSize.width.toFloat()
            val sh = slotSize.height.toFloat()
            val frame = computeMediaFrame(
                slotWidth = sw,
                slotHeight = sh,
                mediaWidth = iw,
                mediaHeight = ih,
                fitMode = element.fitMode,
                cropOffsetX = offsetX,
                cropOffsetY = offsetY,
                cropScale = scale,
                frameBorderPx = element.frameBorderPx,
                logicalSlotWidth = logicalSlotWidth,
                logicalSlotHeight = logicalSlotHeight,
                drawTop = drawTop,
                drawBottom = drawBottom,
                drawLeft = drawLeft,
                drawRight = drawRight,
            )
            val drawWDp = with(density) { frame.drawWidth.toDp() }
            val drawHDp = with(density) { frame.drawHeight.toDp() }

            Image(
                bitmap = currentBitmap,
                contentDescription = null,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(frame.shiftX.roundToInt(), frame.shiftY.roundToInt()) },
                contentScale = ContentScale.FillBounds,
            )
        }
        else -> {
            Box(Modifier.fillMaxSize().background(Color(0xFFF5F5F5)), contentAlignment = Alignment.Center) {
                if (loading) CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            }
        }
    }
}

// ── Video content ───────────────────────────────────────────────────────

@Composable
private fun VideoSlotContent(
    element: MediaElement,
    offsetX: Float,
    offsetY: Float,
    scale: Float,
    slotSize: IntSize,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    onImageSizeKnown: (Int, Int) -> Unit,
    onToggleReady: ((() -> Unit)) -> Unit,
    drawTop: Boolean = true,
    drawBottom: Boolean = true,
    drawLeft: Boolean = true,
    drawRight: Boolean = true,
) {
    var playerActive by remember { mutableStateOf(false) }

    // Show thumbnail when player is not active
    var thumbnail by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    LaunchedEffect(element.sourcePath) {
        if (thumbnail == null) {
            thumbnail = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
        }
    }

    // Report FFmpeg dimensions immediately from thumbnail or video info
    val videoInfo = remember(element.sourcePath) { getVideoInfo(element.sourcePath) }
    val rotation = videoInfo.rotation
    val swapDimensions = rotation == 90 || rotation == 270
    LaunchedEffect(Unit) {
        if (videoInfo.codedWidth > 0 && videoInfo.codedHeight > 0) {
            val w = if (swapDimensions) videoInfo.codedHeight else videoInfo.codedWidth
            val h = if (swapDimensions) videoInfo.codedWidth else videoInfo.codedHeight
            onImageSizeKnown(w, h)
        }
    }

    if (!playerActive) {
        Box(
            modifier = Modifier.fillMaxSize().background(Color(0xFF1A1A1A)),
            contentAlignment = Alignment.TopStart,
        ) {
            thumbnail?.let {
                Image(
                    bitmap = it,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
            IconButton(
                onClick = { playerActive = true },
                modifier = Modifier.padding(4.dp).size(32.dp).pointerHoverIcon(PointerIcon.Hand),
            ) {
                Icon(TablerIcons.PlayerPlay, contentDescription = "Play video", tint = Color.White, modifier = Modifier.size(20.dp))
            }
        }
        LaunchedEffect(Unit) {
            onToggleReady { playerActive = true }
        }
        return
    }

    val playerState = rememberVideoPlayerState()
    val playerStopped = remember { java.util.concurrent.atomic.AtomicBoolean(false) }

    DisposableEffect(element.id) {
        playerStopped.set(false)
        onDispose {
            playerStopped.set(true)
            try { playerState.stop() } catch (_: Exception) {}
        }
    }

    LaunchedEffect(Unit) {
        onToggleReady {
            if (!playerStopped.get()) {
                try {
                    if (playerState.isPlaying) playerState.pause() else playerState.play()
                } catch (_: Exception) {}
            }
        }
    }
    val density = LocalDensity.current

    val meta = playerState.metadata
    val iw = (meta.width ?: if (swapDimensions) videoInfo.codedHeight else videoInfo.codedWidth).toFloat()
    val ih = (meta.height ?: if (swapDimensions) videoInfo.codedWidth else videoInfo.codedHeight).toFloat()

    LaunchedEffect(meta.width, meta.height) {
        val w = meta.width; val h = meta.height
        if (w != null && h != null && w > 0 && h > 0) {
            onImageSizeKnown(w, h)
        }
    }

    LaunchedEffect(element.sourcePath) {
        try {
            // Give AVFoundation time to fully release previous player resources
            kotlinx.coroutines.delay(300)
            if (playerStopped.get()) return@LaunchedEffect
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                if (playerStopped.get()) return@withContext
                playerState.openUri(element.sourcePath.toFileUri())
                playerState.loop = true
                playerState.volume = 0f
                playerState.play()
            }
        } catch (_: kotlinx.coroutines.CancellationException) {
            // Coroutine cancelled during slide switch — expected
        } catch (e: Exception) {
            println("Video playback failed: ${e.message}")
        }
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (iw > 0 && ih > 0 && slotSize.width > 0) {
            val sw = slotSize.width.toFloat()
            val sh = slotSize.height.toFloat()
            val frame = computeMediaFrame(
                slotWidth = sw,
                slotHeight = sh,
                mediaWidth = iw,
                mediaHeight = ih,
                fitMode = element.fitMode,
                cropOffsetX = offsetX,
                cropOffsetY = offsetY,
                cropScale = scale,
                frameBorderPx = element.frameBorderPx,
                logicalSlotWidth = logicalSlotWidth,
                logicalSlotHeight = logicalSlotHeight,
                drawTop = drawTop,
                drawBottom = drawBottom,
                drawLeft = drawLeft,
                drawRight = drawRight,
            )
            val drawWDp = with(density) { frame.drawWidth.toDp() }
            val drawHDp = with(density) { frame.drawHeight.toDp() }
            // Swap surface dimensions for 90/270° so FillBounds preserves coded aspect ratio
            val surfaceW = if (swapDimensions) drawHDp else drawWDp
            val surfaceH = if (swapDimensions) drawWDp else drawHDp

            VideoPlayerSurface(
                playerState = playerState,
                modifier = Modifier
                    .requiredSize(surfaceW, surfaceH)
                    .offset { IntOffset(frame.shiftX.roundToInt(), frame.shiftY.roundToInt()) }
                    .graphicsLayer { rotationZ = rotation.toFloat() },
                contentScale = ContentScale.FillBounds,
            )
        } else {
            // Before dimensions are ready, show fill with crop
            VideoPlayerSurface(
                playerState = playerState,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

// ── Empty slot ──────────────────────────────────────────────────────────

@Composable
private fun EmptySlot(onAddImage: (String) -> Unit) {
    val launcher = rememberFilePickerLauncher(
        type = FileKitType.ImageAndVideo,
    ) { file -> file?.path?.let(onAddImage) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF5F5F5))
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) { launcher.launch() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            TablerIcons.Photo,
            contentDescription = "Add image",
            modifier = Modifier.size(32.dp),
            tint = Color.Gray,
        )
    }
}

@Composable
fun TemplatePickerBar(
    onTemplateSelected: (SlideTemplate) -> Unit,
    modifier: Modifier = Modifier,
) {
    val controlHeight = 28.dp
    val separatorColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)

    Row(
        modifier = modifier
            .shadow(4.dp, RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SlideTemplate.entries.filter { it.spanSize() == null }.forEach { tmpl ->
            FilledTonalIconButton(
                onClick = { onTemplateSelected(tmpl) },
                modifier = Modifier.size(controlHeight).pointerHoverIcon(PointerIcon.Hand),
            ) {
                TemplateIcon(tmpl, modifier = Modifier.size(14.dp))
            }
        }

        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        SlideTemplate.entries.filter { it.spanSize() != null }.forEach { tmpl ->
            FilledTonalIconButton(
                onClick = { onTemplateSelected(tmpl) },
                modifier = Modifier.size(controlHeight).pointerHoverIcon(PointerIcon.Hand),
            ) {
                TemplateIcon(tmpl, modifier = Modifier.size(14.dp))
            }
        }
    }
}

@Composable
fun SlideControls(
    slide: Slide,
    representativeElement: MediaElement,
    onFitModeChanged: (MediaFitMode) -> Unit,
    onFrameBorderPxChanged: (Float) -> Unit,
    onBackgroundColorChanged: (Long) -> Unit,
    onGapChanged: (Float) -> Unit,
    onTemplateSelected: (SlideTemplate) -> Unit,
    onAddText: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val currentColor = slide.backgroundColorArgb.toComposeColor()
    val usesCustomColor = slide.backgroundColorArgb != WHITE_BACKGROUND && slide.backgroundColorArgb != BLACK_BACKGROUND
    val launchSystemColorPicker = rememberSystemColorPickerLauncher(onBackgroundColorChanged)
    var borderInput by remember(slide.id) {
        mutableStateOf(representativeElement.frameBorderPx.roundToInt().toString())
    }
    val showGap = slide.template.slotCount > 1
    var gapInput by remember(slide.id) {
        mutableStateOf(slide.gapPx.roundToInt().toString())
    }
    var layoutExpanded by remember { mutableStateOf(false) }

    val controlHeight = 28.dp
    val separatorColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)

    Row(
        modifier = modifier
            .shadow(4.dp, RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (!showGap) {
            // Segmented Fill/Full toggle (single/span only)
            Row(
                modifier = Modifier
                    .height(controlHeight)
                    .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                    .clip(RoundedCornerShape(6.dp)),
            ) {
                val modes = listOf("Fill" to MediaFitMode.FILL, "Full" to MediaFitMode.FIT)
                modes.forEachIndexed { index, (label, mode) ->
                    val selected = representativeElement.fitMode == mode
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .background(if (selected) Color.White else Color.Transparent)
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) { onFitModeChanged(mode) }
                            .padding(horizontal = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            label,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (selected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (index == 0) {
                        Box(Modifier.fillMaxHeight().width(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)))
                    }
                }
            }

            // Separator
            Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

            // Border controls (single/span only)
            Text("Border", style = MaterialTheme.typography.labelMedium)
            PxInputField(
                value = borderInput,
                onValueChange = { value ->
                    val filtered = value.filter { it.isDigit() }.take(3)
                    borderInput = filtered
                    val px = if (filtered.isEmpty()) 0f else filtered.toFloatOrNull() ?: 0f
                    onFrameBorderPxChanged(px.coerceIn(0f, MAX_FRAME_BORDER_PX))
                },
                controlHeight = controlHeight,
            )
        }

        // Gap controls (multi-image only)
        if (showGap) {
            Text("Gap", style = MaterialTheme.typography.labelMedium)
            PxInputField(
                value = gapInput,
                onValueChange = { value ->
                    val filtered = value.filter { it.isDigit() }.take(3)
                    gapInput = filtered
                    val px = if (filtered.isEmpty()) 0f else filtered.toFloatOrNull() ?: 0f
                    onGapChanged(px.coerceIn(0f, MAX_GAP_PX))
                },
                controlHeight = controlHeight,
            )
        }

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Color bubbles
        ColorBubble(
            color = WHITE_BACKGROUND.toComposeColor(),
            selected = slide.backgroundColorArgb == WHITE_BACKGROUND,
            onClick = { onBackgroundColorChanged(WHITE_BACKGROUND) },
            size = controlHeight,
        )
        ColorBubble(
            color = BLACK_BACKGROUND.toComposeColor(),
            selected = slide.backgroundColorArgb == BLACK_BACKGROUND,
            onClick = { onBackgroundColorChanged(BLACK_BACKGROUND) },
            size = controlHeight,
        )
        ColorBubble(
            color = currentColor,
            selected = usesCustomColor,
            onClick = { launchSystemColorPicker(slide.backgroundColorArgb) },
            label = "+",
            size = controlHeight,
        )

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Layout re-selector
        Box {
            FilledTonalIconButton(
                onClick = { layoutExpanded = !layoutExpanded },
                modifier = Modifier.size(controlHeight).pointerHoverIcon(PointerIcon.Hand),
            ) {
                TemplateIcon(slide.template, modifier = Modifier.size(14.dp))
            }
            DropdownMenu(
                expanded = layoutExpanded,
                onDismissRequest = { layoutExpanded = false },
            ) {
                Text(
                    "Layout",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                )
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    SlideTemplate.entries.filter { it.spanSize() == null }.forEach { tmpl ->
                        FilledTonalIconButton(
                            onClick = { onTemplateSelected(tmpl); layoutExpanded = false },
                            modifier = Modifier.size(36.dp).pointerHoverIcon(PointerIcon.Hand),
                        ) {
                            TemplateIcon(tmpl, modifier = Modifier.size(18.dp))
                        }
                    }
                }
                Text(
                    "Panorama",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                )
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 0.dp).padding(bottom = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    SlideTemplate.entries.filter { it.spanSize() != null }.forEach { tmpl ->
                        FilledTonalIconButton(
                            onClick = { onTemplateSelected(tmpl); layoutExpanded = false },
                            modifier = Modifier.size(36.dp).pointerHoverIcon(PointerIcon.Hand),
                        ) {
                            TemplateIcon(tmpl, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
        }

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Add text overlay
        FilledTonalIconButton(
            onClick = onAddText,
            modifier = Modifier.size(controlHeight).pointerHoverIcon(PointerIcon.Hand),
        ) {
            Text("T", style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
fun TextOverlayControls(
    overlay: com.yannickpulver.slides.model.TextOverlay,
    onStyleChanged: (fontFamily: String?, fontSize: Float?, color: Long?, alignment: com.yannickpulver.slides.model.TextAlignment?) -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val controlHeight = 28.dp
    val separatorColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
    var fontExpanded by remember { mutableStateOf(false) }
    var sizeInput by remember(overlay.id) { mutableStateOf(overlay.fontSizePx.roundToInt().toString()) }
    val launchColorPicker = rememberSystemColorPickerLauncher { color ->
        onStyleChanged(null, null, color, null)
    }
    var fontSearch by remember { mutableStateOf("") }
    var fontNames by remember { mutableStateOf(getAvailableFontFamiliesOrNull()) }
    LaunchedEffect(fontExpanded) {
        if (fontExpanded && fontNames == null) {
            // Poll until the background thread finishes
            while (getAvailableFontFamiliesOrNull() == null) {
                kotlinx.coroutines.delay(100)
            }
            fontNames = getAvailableFontFamiliesOrNull()
        }
    }

    Row(
        modifier = modifier
            .shadow(4.dp, RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Font selector
        Box {
            Box(
                modifier = Modifier
                    .height(controlHeight)
                    .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                    .clip(RoundedCornerShape(6.dp))
                    .pointerHoverIcon(PointerIcon.Hand)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { fontExpanded = true }
                    .padding(horizontal = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    overlay.fontFamily.ifEmpty { "Default" },
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                )
            }
            DropdownMenu(
                expanded = fontExpanded,
                onDismissRequest = { fontExpanded = false; fontSearch = "" },
                modifier = Modifier.width(240.dp).background(MaterialTheme.colorScheme.surfaceContainer),
            ) {
                // Search field
                val searchFocusRequester = remember { FocusRequester() }
                BasicTextField(
                    value = fontSearch,
                    onValueChange = { fontSearch = it },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurface),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .focusRequester(searchFocusRequester),
                    decorationBox = { inner ->
                        Box {
                            if (fontSearch.isEmpty()) {
                                Text("Search fonts…", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            inner()
                        }
                    },
                )
                LaunchedEffect(fontExpanded) { if (fontExpanded) searchFocusRequester.requestFocus() }
                Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)))

                // Font list
                if (fontNames == null) {
                    Box(Modifier.fillMaxWidth().height(60.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    }
                } else {
                    val filtered = if (fontSearch.isBlank()) fontNames!! else fontNames!!.filter {
                        it.contains(fontSearch, ignoreCase = true)
                    }
                    Box(modifier = Modifier.height(280.dp)) {
                        val scrollState = androidx.compose.foundation.rememberScrollState()
                        Column(modifier = Modifier.fillMaxWidth().verticalScroll(scrollState)) {
                            if (fontSearch.isBlank()) {
                                // Default option
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(28.dp)
                                        .clickable { onStyleChanged("", null, null, null); fontExpanded = false; fontSearch = "" }
                                        .padding(horizontal = 12.dp),
                                    contentAlignment = Alignment.CenterStart,
                                ) {
                                    Text("Default", style = MaterialTheme.typography.bodySmall)
                                }
                            }
                            filtered.forEach { name ->
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(28.dp)
                                        .clickable { onStyleChanged(name, null, null, null); fontExpanded = false; fontSearch = "" }
                                        .padding(horizontal = 12.dp),
                                    contentAlignment = Alignment.CenterStart,
                                ) {
                                    Text(
                                        name,
                                        style = MaterialTheme.typography.bodySmall,
                                        fontFamily = fontFamilyFromName(name),
                                        maxLines = 1,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Font size
        Text("Size", style = MaterialTheme.typography.labelMedium)
        PxInputField(
            value = sizeInput,
            onValueChange = { value ->
                val filtered = value.filter { it.isDigit() }.take(3)
                sizeInput = filtered
                val px = if (filtered.isEmpty()) 16f else filtered.toFloatOrNull() ?: 16f
                onStyleChanged(null, px.coerceIn(8f, 200f), null, null)
            },
            controlHeight = controlHeight,
        )

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Alignment toggle
        Row(
            modifier = Modifier
                .height(controlHeight)
                .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                .clip(RoundedCornerShape(6.dp)),
        ) {
            val alignments = listOf(
                "L" to com.yannickpulver.slides.model.TextAlignment.LEFT,
                "C" to com.yannickpulver.slides.model.TextAlignment.CENTER,
                "R" to com.yannickpulver.slides.model.TextAlignment.RIGHT,
            )
            alignments.forEachIndexed { index, (label, align) ->
                val selected = overlay.alignment == align
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .background(if (selected) MaterialTheme.colorScheme.primary else Color.Transparent)
                        .pointerHoverIcon(PointerIcon.Hand)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onStyleChanged(null, null, null, align) }
                        .padding(horizontal = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (index < alignments.lastIndex) {
                    Box(Modifier.fillMaxHeight().width(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)))
                }
            }
        }

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Color
        ColorBubble(
            color = WHITE_BACKGROUND.toComposeColor(),
            selected = overlay.colorArgb == WHITE_BACKGROUND,
            onClick = { onStyleChanged(null, null, WHITE_BACKGROUND, null) },
            size = controlHeight,
        )
        ColorBubble(
            color = BLACK_BACKGROUND.toComposeColor(),
            selected = overlay.colorArgb == BLACK_BACKGROUND,
            onClick = { onStyleChanged(null, null, BLACK_BACKGROUND, null) },
            size = controlHeight,
        )
        ColorBubble(
            color = Color(overlay.colorArgb.toInt()),
            selected = overlay.colorArgb != WHITE_BACKGROUND && overlay.colorArgb != BLACK_BACKGROUND,
            onClick = { launchColorPicker(overlay.colorArgb) },
            label = "+",
            size = controlHeight,
        )

        // Separator
        Box(Modifier.height(controlHeight * 0.6f).width(1.dp).background(separatorColor))

        // Delete
        FilledTonalIconButton(
            onClick = onDelete,
            modifier = Modifier.size(controlHeight).pointerHoverIcon(PointerIcon.Hand),
        ) {
            Text("✕", style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun PxInputField(
    value: String,
    onValueChange: (String) -> Unit,
    controlHeight: Dp,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        modifier = Modifier
            .width(64.dp)
            .height(controlHeight)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(6.dp))
            .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp),
        textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.colorScheme.onSurface),
        decorationBox = { innerTextField ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxHeight(),
            ) {
                Box(Modifier.weight(1f)) { innerTextField() }
                Text("px", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
    )
}

@Composable
private fun BubbleToggle(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val background = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
    val content = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
    Box(
        modifier = Modifier
            .size(52.dp)
            .clip(CircleShape)
            .background(background)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
                shape = CircleShape,
            )
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, color = content, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun ColorBubble(
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
    label: String? = null,
    size: Dp = 32.dp,
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(color)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.55f),
                shape = CircleShape,
            )
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (label != null) {
            Text(
                label,
                color = if (perceivedBrightness(color) > 0.6f) Color.Black else Color.White,
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

private data class MediaFrame(
    val drawWidth: Float,
    val drawHeight: Float,
    val shiftX: Float,
    val shiftY: Float,
)

private fun computeFrameInsetPx(
    slotWidth: Float,
    slotHeight: Float,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    frameBorderPx: Float,
): Float {
    val insetScale = minOf(
        slotWidth.coerceAtLeast(1f) / logicalSlotWidth.coerceAtLeast(1f),
        slotHeight.coerceAtLeast(1f) / logicalSlotHeight.coerceAtLeast(1f),
    )
    return frameBorderPx.coerceIn(0f, MAX_FRAME_BORDER_PX) * insetScale
}

private fun computeMediaFrame(
    slotWidth: Float,
    slotHeight: Float,
    mediaWidth: Float,
    mediaHeight: Float,
    fitMode: MediaFitMode,
    cropOffsetX: Float,
    cropOffsetY: Float,
    cropScale: Float,
    frameBorderPx: Float,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    drawTop: Boolean = true,
    drawBottom: Boolean = true,
    drawLeft: Boolean = true,
    drawRight: Boolean = true,
): MediaFrame {
    val safeMediaWidth = mediaWidth.coerceAtLeast(1f)
    val safeMediaHeight = mediaHeight.coerceAtLeast(1f)
    val safeSlotWidth = slotWidth.coerceAtLeast(1f)
    val safeSlotHeight = slotHeight.coerceAtLeast(1f)
    val inset = computeFrameInsetPx(
        slotWidth = safeSlotWidth,
        slotHeight = safeSlotHeight,
        logicalSlotWidth = logicalSlotWidth,
        logicalSlotHeight = logicalSlotHeight,
        frameBorderPx = frameBorderPx,
    )
    val tI = if (drawTop) 1f else 0f
    val bI = if (drawBottom) 1f else 0f
    val lI = if (drawLeft) 1f else 0f
    val rI = if (drawRight) 1f else 0f
    val availableWidth = (safeSlotWidth - inset * (lI + rI)).coerceAtLeast(1f)
    val availableHeight = (safeSlotHeight - inset * (tI + bI)).coerceAtLeast(1f)
    val centerShiftX = (lI - rI) * inset / 2f
    val centerShiftY = (tI - bI) * inset / 2f

    return if (fitMode == MediaFitMode.FIT) {
        val fitScale = minOf(availableWidth / safeMediaWidth, availableHeight / safeMediaHeight)
        MediaFrame(
            drawWidth = safeMediaWidth * fitScale,
            drawHeight = safeMediaHeight * fitScale,
            shiftX = centerShiftX,
            shiftY = centerShiftY,
        )
    } else {
        val fillScale = max(availableWidth / safeMediaWidth, availableHeight / safeMediaHeight)
        MediaFrame(
            drawWidth = safeMediaWidth * fillScale * cropScale,
            drawHeight = safeMediaHeight * fillScale * cropScale,
            shiftX = cropOffsetX + centerShiftX,
            shiftY = cropOffsetY + centerShiftY,
        )
    }
}

private fun Long.toComposeColor(): Color = Color(toInt())

private fun perceivedBrightness(color: Color): Float =
    (color.red * 0.299f) + (color.green * 0.587f) + (color.blue * 0.114f)

private const val MAX_FRAME_BORDER_PX = 240f
private val MAX_GAP_PX = EditorViewModel.MAX_GAP_PX
private const val WHITE_BACKGROUND = 0xFFFFFFFFL
private const val BLACK_BACKGROUND = 0xFF000000L

// ── Template icon ───────────────────────────────────────────────────────

@Composable
fun TemplateIcon(template: SlideTemplate, modifier: Modifier = Modifier) {
    val spanSize = template.spanSize()
    if (spanSize != null) {
        Row(
            modifier = modifier,
            horizontalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            repeat(spanSize) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clip(RoundedCornerShape(1.dp))
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)),
                )
            }
        }
    } else {
        Column(
            modifier = modifier,
            verticalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            repeat(template.slotCount) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clip(RoundedCornerShape(1.dp))
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)),
                )
            }
        }
    }
}

// ── Text overlay composable ────────────────────────────────────────────

@Composable
private fun TextOverlayBox(
    overlay: com.yannickpulver.slides.model.TextOverlay,
    canvasWidth: Float,
    canvasHeight: Float,
    isSelected: Boolean,
    onClick: () -> Unit,
    onPositionChanged: (Float, Float) -> Unit,
    onWidthChanged: (Float) -> Unit,
    onTextChanged: (String) -> Unit,
) {
    val density = LocalDensity.current
    var offsetX by remember(overlay.id) { mutableStateOf(overlay.x * canvasWidth) }
    var offsetY by remember(overlay.id) { mutableStateOf(overlay.y * canvasHeight) }
    var boxWidth by remember(overlay.id) { mutableStateOf(overlay.width * canvasWidth) }
    var isEditing by remember(overlay.id) { mutableStateOf(false) }

    // Exit editing when deselected
    LaunchedEffect(isSelected) { if (!isSelected) isEditing = false }

    // Sync from model
    LaunchedEffect(overlay.x, overlay.y, canvasWidth, canvasHeight) {
        offsetX = overlay.x * canvasWidth
        offsetY = overlay.y * canvasHeight
    }
    LaunchedEffect(overlay.width, canvasWidth) {
        boxWidth = overlay.width * canvasWidth
    }

    val fontSize = with(density) { (overlay.fontSizePx * (canvasHeight / 1080f)).toSp() }
    val fontFamily = if (overlay.fontFamily.isNotEmpty()) fontFamilyFromName(overlay.fontFamily) else androidx.compose.ui.text.font.FontFamily.Default
    val textAlign = when (overlay.alignment) {
        com.yannickpulver.slides.model.TextAlignment.LEFT -> androidx.compose.ui.text.style.TextAlign.Start
        com.yannickpulver.slides.model.TextAlignment.CENTER -> androidx.compose.ui.text.style.TextAlign.Center
        com.yannickpulver.slides.model.TextAlignment.RIGHT -> androidx.compose.ui.text.style.TextAlign.End
    }
    val textColor = Color(overlay.colorArgb.toInt())
    val textStyle = androidx.compose.ui.text.TextStyle(
        color = textColor,
        fontSize = fontSize,
        fontFamily = fontFamily,
        textAlign = textAlign,
    )

    Box(
        modifier = Modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .width(with(density) { boxWidth.toDp() })
            .then(
                if (isSelected) Modifier.border(1.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(2.dp))
                else Modifier
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) {
                if (!isSelected) onClick()
                else if (!isEditing) isEditing = true
            }
            .then(
                if (isSelected && !isEditing) {
                    Modifier.pointerInput(overlay.id) {
                        detectDragGestures(
                            onDrag = { _, dragAmount ->
                                offsetX = (offsetX + dragAmount.x).coerceIn(0f, canvasWidth - boxWidth)
                                offsetY = (offsetY + dragAmount.y).coerceIn(0f, canvasHeight - 20f)
                                onPositionChanged(offsetX / canvasWidth, offsetY / canvasHeight)
                            },
                        )
                    }
                } else Modifier
            )
            .padding(4.dp),
    ) {
        if (isEditing) {
            BasicTextField(
                value = overlay.text,
                onValueChange = onTextChanged,
                textStyle = textStyle,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            Text(
                text = overlay.text,
                style = textStyle,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // Right edge resize handle
        if (isSelected) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .offset(x = 6.dp)
                    .size(8.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape)
                    .pointerHoverIcon(PointerIcon(java.awt.Cursor(java.awt.Cursor.E_RESIZE_CURSOR)))
                    .pointerInput(overlay.id) {
                        detectDragGestures(
                            onDrag = { _, dragAmount ->
                                boxWidth = (boxWidth + dragAmount.x).coerceIn(canvasWidth * 0.05f, canvasWidth - offsetX)
                                onWidthChanged(boxWidth / canvasWidth)
                            },
                        )
                    },
            )
        }
    }
}

// ── Bitmap cache ───────────────────────────────────────────────────────

private val bitmapCache = java.util.concurrent.ConcurrentHashMap<String, ImageBitmap>()

private fun loadCachedBitmap(path: String): ImageBitmap? {
    return bitmapCache.getOrPut(path) { loadImageBitmap(path) ?: return null }
}

// ── Drag-and-drop helper ────────────────────────────────────────────────

@OptIn(ExperimentalComposeUiApi::class)
private fun fileDropTarget(onFiles: (List<String>) -> Unit): DragAndDropTarget {
    return object : DragAndDropTarget {
        override fun onDrop(event: DragAndDropEvent): Boolean {
            when (val dragData = event.dragData()) {
                is DragData.FilesList -> {
                    val paths = dragData.readFiles().map { uri ->
                        if (uri.startsWith("file")) uri.drop(5).replace("%20", " ")
                        else uri
                    }
                    onFiles(paths)
                    return true
                }
                else -> return false
            }
        }
    }
}

expect fun loadImageBitmap(path: String): ImageBitmap?

data class VideoInfo(val rotation: Int, val codedWidth: Int, val codedHeight: Int)

expect fun getVideoInfo(path: String): VideoInfo

private fun String.toFileUri(): String =
    "file://" + replace(" ", "%20")

// ── Static slide preview (faded neighbor slides) ───────────────────────

@Composable
fun SlidePreview(
    slide: Slide,
    aspectRatio: AspectRatio,
    modifier: Modifier = Modifier,
    fillFraction: Float = 0.9f,
) {
    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
    val slotBounds = boundsForTemplate(slide.template)

    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxHeight(fillFraction)
                .aspectRatio(ratio)
                .background(
                    if (slide.gapPx > 0f) slide.backgroundColorArgb.toComposeColor()
                    else Color.White
                )
                .clipToBounds(),
        ) {
            val density = LocalDensity.current
            val displayScale = constraints.maxWidth.toFloat() / aspectRatio.width.toFloat()
            val gapDp = with(density) { (slide.gapPx * displayScale).toDp() }
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = if (slide.gapPx > 0f) Arrangement.spacedBy(gapDp) else Arrangement.Top,
            ) {
                slotBounds.forEachIndexed { slotIdx, bounds ->
                    val element = slide.elements.find { it.bounds == bounds }
                    Box(
                        modifier = Modifier.fillMaxWidth().weight(bounds.height).clipToBounds(),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (element != null) {
                            PreviewSlotContent(
                                element = element,
                                logicalSlotWidth = aspectRatio.width * bounds.width,
                                logicalSlotHeight = aspectRatio.height * bounds.height,
                                spanIndex = slide.spanIndex,
                                spanCount = slide.spanCount,
                                stackIndex = slotIdx,
                                stackCount = slotBounds.size,
                            )
                        } else {
                            Box(
                                Modifier.fillMaxSize().background(Color(0xFFF5F5F5)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    TablerIcons.Photo,
                                    contentDescription = null,
                                    modifier = Modifier.size(24.dp),
                                    tint = Color.LightGray,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PreviewSlotContent(
    element: MediaElement,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    spanIndex: Int = 0,
    spanCount: Int = 1,
    stackIndex: Int = 0,
    stackCount: Int = 1,
) {
    var bitmap by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    var loading by remember(element.sourcePath) { mutableStateOf(bitmap == null) }
    var slotSize by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    LaunchedEffect(element.sourcePath) {
        if (bitmap == null) {
            bitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
            loading = false
        }
    }

    val currentBitmap = bitmap
    if (currentBitmap != null && slotSize.width > 0) {
        val iw = currentBitmap.width.toFloat()
        val ih = currentBitmap.height.toFloat()
        val sw = slotSize.width.toFloat()
        val sh = slotSize.height.toFloat()

        val effectiveSlotWidth = sw * spanCount
        val effectiveLogicalWidth = logicalSlotWidth * spanCount
        val useCrop = spanCount == 1
        val frame = computeMediaFrame(
            slotWidth = effectiveSlotWidth,
            slotHeight = sh,
            mediaWidth = iw,
            mediaHeight = ih,
            fitMode = element.fitMode,
            cropOffsetX = if (useCrop) element.cropOffsetX * sw else 0f,
            cropOffsetY = if (useCrop) element.cropOffsetY * sh else 0f,
            cropScale = if (useCrop) element.cropScale else 1f,
            frameBorderPx = element.frameBorderPx,
            logicalSlotWidth = effectiveLogicalWidth,
            logicalSlotHeight = logicalSlotHeight,
            drawTop = stackIndex == 0,
            drawBottom = stackIndex == stackCount - 1,
            drawLeft = spanIndex == 0,
            drawRight = spanIndex == spanCount - 1,
        )
        val sliceShiftX = frame.shiftX + (effectiveSlotWidth - sw) / 2f - (spanIndex * sw)
        val drawWDp = with(density) { frame.drawWidth.toDp() }
        val drawHDp = with(density) { frame.drawHeight.toDp() }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(element.backgroundColorArgb.toComposeColor())
                .onSizeChanged { slotSize = it },
            contentAlignment = Alignment.Center,
        ) {
            Image(
                bitmap = currentBitmap,
                contentDescription = null,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(sliceShiftX.roundToInt(), frame.shiftY.roundToInt()) },
                contentScale = ContentScale.FillBounds,
            )
            BorderMaskOverlay(
                insetPx = computeFrameInsetPx(
                    slotWidth = effectiveSlotWidth,
                    slotHeight = sh,
                    logicalSlotWidth = effectiveLogicalWidth,
                    logicalSlotHeight = logicalSlotHeight,
                    frameBorderPx = element.frameBorderPx,
                ),
                color = element.backgroundColorArgb.toComposeColor(),
                drawTop = stackIndex == 0,
                drawBottom = stackIndex == stackCount - 1,
                drawLeft = spanIndex == 0,
                drawRight = spanIndex == spanCount - 1,
            )
        }
    } else {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .onSizeChanged { slotSize = it }
                .background(element.backgroundColorArgb.toComposeColor()),
            contentAlignment = Alignment.Center,
        ) {
            if (currentBitmap == null && loading) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 1.5.dp)
            }
        }
    }
}
