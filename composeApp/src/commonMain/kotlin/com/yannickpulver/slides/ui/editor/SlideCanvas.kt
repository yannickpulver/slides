package com.yannickpulver.slides.ui.editor

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
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
import kotlin.math.roundToInt
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.zIndex
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaType
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.model.SlideTemplate
import com.yannickpulver.slides.template.boundsForTemplate
import compose.icons.TablerIcons
import compose.icons.tablericons.Photo
import compose.icons.tablericons.PlayerPlay
import io.github.kdroidfilter.composemediaplayer.VideoPlayerSurface
import io.github.kdroidfilter.composemediaplayer.rememberVideoPlayerState
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.dialogs.FileKitType
import io.github.vinceglb.filekit.path
import kotlin.math.max

@OptIn(ExperimentalComposeUiApi::class, ExperimentalFoundationApi::class)
@Composable
fun SlideCanvas(
    slide: Slide?,
    aspectRatio: AspectRatio,
    selectedElementId: String?,
    currentTemplate: SlideTemplate?,
    onElementClick: (String) -> Unit,
    onCanvasClick: () -> Unit,
    onAddImageAtSlot: (Int, String) -> Unit,
    onTemplateSelected: (SlideTemplate) -> Unit,
    onElementCropChanged: (String, Float, Float, Float) -> Unit,
    modifier: Modifier = Modifier,
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
                .fillMaxHeight(0.9f)
                .aspectRatio(ratio)
                .background(Color.White)
                .border(1.dp, Color.LightGray)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onCanvasClick() },
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
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
                            )
                            .then(
                                if (slotIndex > 0) Modifier.border(0.5.dp, Color.LightGray)
                                else Modifier
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (element != null) {
                            FilledSlot(
                                element = element,
                                isSelected = element.id == selectedElementId,
                                onClick = { onElementClick(element.id) },
                                onCropChanged = { ox, oy, s ->
                                    onElementCropChanged(element.id, ox, oy, s)
                                },
                            )
                        } else {
                            EmptySlot(
                                onAddImage = { path -> onAddImageAtSlot(slotIndex, path) },
                            )
                        }
                    }
                }
            }

            if (!slide.hasChosenTemplate) {
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    SlideTemplate.entries.forEach { tmpl ->
                        FilledTonalIconButton(
                            onClick = { onTemplateSelected(tmpl) },
                            modifier = Modifier.size(36.dp),
                        ) {
                            TemplateIcon(tmpl, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
        }
    }
}

// ── Filled slot with pan, pinch, handles ────────────────────────────────

@Composable
private fun FilledSlot(
    element: MediaElement,
    isSelected: Boolean,
    onClick: () -> Unit,
    onCropChanged: (Float, Float, Float) -> Unit,
) {
    // Offsets stored normalized (fraction of slot size), work in pixels internally
    var ox by remember(element.id) { mutableStateOf(0f) }
    var oy by remember(element.id) { mutableStateOf(0f) }
    var scale by remember(element.id) { mutableStateOf(element.cropScale) }
    var slotSize by remember { mutableStateOf(IntSize.Zero) }
    var imgSize by remember(element.id) { mutableStateOf(IntSize.Zero) }
    var videoToggle by remember(element.id) { mutableStateOf<(() -> Unit)?>(null) }
    var initialized by remember(element.id) { mutableStateOf(false) }

    // Denormalize offsets when slot size becomes available
    LaunchedEffect(element.id, slotSize) {
        if (slotSize.width > 0 && !initialized) {
            ox = element.cropOffsetX * slotSize.width
            oy = element.cropOffsetY * slotSize.height
            initialized = true
        }
    }

    fun minScale(): Float = 1f

    fun clamp() {
        val sw = slotSize.width.toFloat()
        val sh = slotSize.height.toFloat()
        val iw = imgSize.width.toFloat().coerceAtLeast(1f)
        val ih = imgSize.height.toFloat().coerceAtLeast(1f)
        val cropScale = max(sw / iw, sh / ih)
        val drawW = iw * cropScale * scale
        val drawH = ih * cropScale * scale
        val maxOx = ((drawW - sw) / 2f).coerceAtLeast(0f)
        val maxOy = ((drawH - sh) / 2f).coerceAtLeast(0f)
        ox = ox.coerceIn(-maxOx, maxOx)
        oy = oy.coerceIn(-maxOy, maxOy)
    }

    // Save normalized offsets
    fun saveOffsets() {
        val sw = slotSize.width.toFloat().coerceAtLeast(1f)
        val sh = slotSize.height.toFloat().coerceAtLeast(1f)
        onCropChanged(ox / sw, oy / sh, scale)
    }

    val borderColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clipToBounds()
            .onSizeChanged { slotSize = it }
            .border(if (isSelected) 2.dp else 0.dp, borderColor)
            .pointerInput(element.id) {
                detectTapGestures {
                    onClick()
                    videoToggle?.invoke()
                }
            }
            .pointerInput(element.id) {
                detectTransformGestures { _, pan, zoom, _ ->
                    scale = (scale * zoom).coerceIn(minScale(), 5f)
                    ox += pan.x
                    oy += pan.y
                    clamp()
                    saveOffsets()
                }
            },
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (element.type == MediaType.VIDEO) {
                VideoSlotContent(
                    element = element,
                    offsetX = ox, offsetY = oy, scale = scale,
                    slotSize = slotSize,
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
                    onImageSizeKnown = { w, h ->
                        imgSize = IntSize(w, h)
                        clamp()
                    },
                )
            }
        }

        // Corner resize handles at image corners
        if (isSelected && slotSize.width > 0 && imgSize.width > 0) {
            CornerHandles(
                scale = scale,
                offsetX = ox,
                offsetY = oy,
                slotSize = slotSize,
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
private fun CornerHandles(
    scale: Float,
    offsetX: Float,
    offsetY: Float,
    slotSize: IntSize,
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
    val cropScale = max(sw / iw, sh / ih)
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
    onImageSizeKnown: (Int, Int) -> Unit,
) {
    var bitmap by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    LaunchedEffect(element.sourcePath) {
        if (bitmap == null) {
            bitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
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
            // Crop-fill scale: image fills the slot
            val cropFill = if (sw > 0 && sh > 0) max(sw / iw, sh / ih) else 1f
            val drawW = iw * cropFill * scale
            val drawH = ih * cropFill * scale
            val drawWDp = with(density) { drawW.toDp() }
            val drawHDp = with(density) { drawH.toDp() }
            // Parent Box centers; offset is relative to that
            val cx = offsetX.roundToInt()
            val cy = offsetY.roundToInt()

            Image(
                bitmap = currentBitmap,
                contentDescription = null,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(cx, cy) },
                contentScale = ContentScale.FillBounds,
            )
        }
        else -> {
            Box(Modifier.fillMaxSize().background(Color(0xFFF5F5F5)), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
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
    onImageSizeKnown: (Int, Int) -> Unit,
    onToggleReady: ((() -> Unit)) -> Unit,
) {
    // Don't auto-create the video player — AVFoundation crashes on macOS
    // when multiple players init concurrently. Only create on user action.
    var playerActive by remember { mutableStateOf(false) }

    if (!playerActive) {
        Box(
            modifier = Modifier.fillMaxSize().background(Color(0xFF1A1A1A)),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                FilledTonalIconButton(
                    onClick = { playerActive = true },
                    modifier = Modifier.size(48.dp),
                ) {
                    Icon(TablerIcons.PlayerPlay, contentDescription = "Play video", modifier = Modifier.size(24.dp))
                }
                Text(
                    element.sourcePath.substringAfterLast("/"),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
        LaunchedEffect(Unit) {
            onToggleReady { playerActive = true }
        }
        return
    }

    val playerState = rememberVideoPlayerState()

    // Stop playback before disposal to avoid AVFoundation race condition
    DisposableEffect(element.id) {
        onDispose {
            playerState.pause()
        }
    }

    LaunchedEffect(Unit) {
        onToggleReady { if (playerState.isPlaying) playerState.pause() else playerState.play() }
    }
    val density = LocalDensity.current

    // Get dimensions from player metadata
    val meta = playerState.metadata
    val videoW = meta.width
    val videoH = meta.height

    LaunchedEffect(videoW, videoH) {
        if (videoW != null && videoH != null && videoW > 0 && videoH > 0) {
            onImageSizeKnown(videoW, videoH)
        }
    }

    LaunchedEffect(element.sourcePath) {
        try {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                playerState.openUri(element.sourcePath.toFileUri())
                playerState.loop = true
                playerState.volume = 0f
                playerState.play()
            }
        } catch (e: Exception) {
            println("Video playback failed: ${e.message}")
        }
    }

    val iw = videoW?.toFloat() ?: 0f
    val ih = videoH?.toFloat() ?: 0f

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (iw > 0 && ih > 0 && slotSize.width > 0) {
            val sw = slotSize.width.toFloat()
            val sh = slotSize.height.toFloat()
            val cropFill = max(sw / iw, sh / ih)
            val drawW = iw * cropFill * scale
            val drawH = ih * cropFill * scale
            val drawWDp = with(density) { drawW.toDp() }
            val drawHDp = with(density) { drawH.toDp() }
            val cx = offsetX.roundToInt()
            val cy = offsetY.roundToInt()

            VideoPlayerSurface(
                playerState = playerState,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(cx, cy) },
                contentScale = ContentScale.FillBounds,
            )
        } else {
            // Before metadata is ready, show fill with crop
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

// ── Template icon ───────────────────────────────────────────────────────

@Composable
private fun TemplateIcon(template: SlideTemplate, modifier: Modifier = Modifier) {
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
                .background(Color.White)
                .border(1.dp, Color.LightGray)
                .clipToBounds(),
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                slotBounds.forEachIndexed { _, bounds ->
                    val element = slide.elements.find { it.bounds == bounds }
                    Box(
                        modifier = Modifier.fillMaxWidth().weight(bounds.height).clipToBounds(),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (element != null) {
                            PreviewSlotContent(element)
                        } else {
                            Box(Modifier.fillMaxSize().background(Color(0xFFF5F5F5)))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PreviewSlotContent(element: MediaElement) {
    var bitmap by remember(element.sourcePath) { mutableStateOf(bitmapCache[element.sourcePath]) }
    var slotSize by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    LaunchedEffect(element.sourcePath) {
        if (bitmap == null) {
            bitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                loadCachedBitmap(element.sourcePath)
            }
        }
    }

    val currentBitmap = bitmap
    if (currentBitmap != null && slotSize.width > 0) {
        val iw = currentBitmap.width.toFloat()
        val ih = currentBitmap.height.toFloat()
        val sw = slotSize.width.toFloat()
        val sh = slotSize.height.toFloat()
        val cropFill = if (sw > 0 && sh > 0) max(sw / iw, sh / ih) else 1f
        val drawW = iw * cropFill * element.cropScale
        val drawH = ih * cropFill * element.cropScale
        val drawWDp = with(density) { drawW.toDp() }
        val drawHDp = with(density) { drawH.toDp() }
        // Denormalize offsets from fraction to pixels
        val cx = (element.cropOffsetX * sw).roundToInt()
        val cy = (element.cropOffsetY * sh).roundToInt()

        Box(
            modifier = Modifier.fillMaxSize().onSizeChanged { slotSize = it },
            contentAlignment = Alignment.Center,
        ) {
            Image(
                bitmap = currentBitmap,
                contentDescription = null,
                modifier = Modifier
                    .requiredSize(drawWDp, drawHDp)
                    .offset { IntOffset(cx, cy) },
                contentScale = ContentScale.FillBounds,
            )
        }
    } else {
        Box(
            modifier = Modifier.fillMaxSize().onSizeChanged { slotSize = it }.background(Color(0xFFF5F5F5)),
            contentAlignment = Alignment.Center,
        ) {
            if (currentBitmap == null) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 1.5.dp)
            }
        }
    }
}
