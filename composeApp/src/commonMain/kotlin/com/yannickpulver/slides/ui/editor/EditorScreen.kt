package com.yannickpulver.slides.ui.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.yannickpulver.slides.ui.filmstrip.Filmstrip
import compose.icons.TablerIcons
import compose.icons.tablericons.ArrowLeft
import compose.icons.tablericons.Plus

@Composable
fun EditorScreen(viewModel: EditorViewModel, onBack: (() -> Unit)? = null) {
    val state by viewModel.state.collectAsState()
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .focusRequester(focusRequester)
            .focusable()
            .onPreviewKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown) {
                    when (event.key) {
                        Key.DirectionLeft -> { viewModel.selectPreviousSlide(); true }
                        Key.DirectionRight -> { viewModel.selectNextSlide(); true }
                        else -> false
                    }
                } else false
            },
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            val slides = state.project.slides
            val currentIdx = state.currentSlideIndex
            val prevSlide = slides.getOrNull(currentIdx - 1)
            val nextSlide = slides.getOrNull(currentIdx + 1)
            val aspectRatio = state.project.aspectRatio

            BoxWithConstraints(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceContainerLow),
            ) {
                val density = LocalDensity.current
                val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
                val slideWidth = maxHeight * 0.9f * ratio
                val shiftPx = with(density) { (slideWidth + 24.dp).toPx() }
                val edgeWidth = (maxWidth - slideWidth) / 2

                // Current slide (full size)
                SlideCanvas(
                    slide = state.currentSlide,
                    aspectRatio = aspectRatio,
                    selectedElementId = state.selectedElementId,
                    currentTemplate = state.currentSlide?.template,
                    onElementClick = viewModel::selectElement,
                    onCanvasClick = { viewModel.selectElement(null) },
                    onAddImageAtSlot = { slotIndex, path -> viewModel.addElementAtSlot(slotIndex, path) },
                    onTemplateSelected = { viewModel.applyTemplate(it) },
                    onElementCropChanged = { id, ox, oy, s -> viewModel.updateElementCrop(id, ox, oy, s) },
                    modifier = Modifier.fillMaxSize(),
                )

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
                // Left edge click area
                if (prevSlide != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .fillMaxHeight()
                            .width(edgeWidth.coerceAtLeast(40.dp))
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) { viewModel.selectPreviousSlide() },
                    )
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
                // Right edge click area (nav or add)
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .fillMaxHeight()
                        .width(edgeWidth.coerceAtLeast(40.dp))
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
                aspectRatio = aspectRatio,
                onSlideSelect = viewModel::selectSlide,
                onAddSlide = viewModel::addSlide,
                onRemoveSlide = viewModel::removeSlide,
                onExportSlide = { outputDir, scale -> viewModel.exportAllSlides(outputDir, scale) },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // Back button
        if (onBack != null) {
            androidx.compose.material3.IconButton(
                onClick = onBack,
                modifier = Modifier.align(Alignment.TopStart).padding(8.dp),
            ) {
                Icon(
                    TablerIcons.ArrowLeft,
                    contentDescription = "Back to projects",
                    modifier = Modifier.size(20.dp),
                )
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
