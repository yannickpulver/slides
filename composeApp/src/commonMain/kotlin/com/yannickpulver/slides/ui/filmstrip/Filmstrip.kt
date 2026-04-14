package com.yannickpulver.slides.ui.filmstrip

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.ui.editor.SlidePreview
import compose.icons.TablerIcons
import compose.icons.tablericons.Plus
import compose.icons.tablericons.X
import kotlin.math.roundToInt

@Composable
fun Filmstrip(
    slides: List<Slide>,
    selectedSlideId: String?,
    selectedSpanGroupId: String? = null,
    aspectRatio: AspectRatio,
    onSlideSelect: (String) -> Unit,
    onAddSlide: () -> Unit,
    onRemoveSlide: (String) -> Unit,
    onMoveSlide: (slideId: String, targetIndex: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
    val density = LocalDensity.current
    val itemWidthPx = with(density) { (60.dp + 8.dp).toPx() }

    var draggingSlideId by remember { mutableStateOf<String?>(null) }
    var dragOffsetX by remember { mutableStateOf(0f) }
    var originalGroupFirstIdx by remember { mutableStateOf(0) }
    var accumulatedMoveCount by remember { mutableStateOf(0) }

    val slidesState = rememberUpdatedState(slides)
    val onMoveSlideState = rememberUpdatedState(onMoveSlide)

    val dragGroupIds = remember(draggingSlideId, slides) {
        val dId = draggingSlideId ?: return@remember emptySet<String>()
        val slide = slides.find { it.id == dId } ?: return@remember emptySet<String>()
        if (slide.spanGroupId != null) {
            slides.filter { it.spanGroupId == slide.spanGroupId }.map { it.id }.toSet()
        } else {
            setOf(dId)
        }
    }

    Surface(modifier = modifier, tonalElevation = 2.dp) {
        Row(
            modifier = Modifier.height(100.dp).padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            LazyRow(
                modifier = Modifier.weight(1f).fillMaxHeight(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                items(slides, key = { it.id }) { slide ->
                    val isInGroup = selectedSpanGroupId != null && slide.spanGroupId == selectedSpanGroupId
                    val isDragging = slide.id in dragGroupIds

                    // Tighten spacing between dragged panorama slides
                    val isFirstInDragGroup = isDragging && (slide.spanGroupId == null || slide.spanIndex == 0)
                    val dragGroupGapReduce = if (isDragging && !isFirstInDragGroup) 6.dp else 0.dp

                    SlideThumbnail(
                        slide = slide,
                        ratio = ratio,
                        isSelected = slide.id == selectedSlideId,
                        isInSelectedGroup = isInGroup && slide.id != selectedSlideId,
                        onClick = { onSlideSelect(slide.id) },
                        onRemove = { onRemoveSlide(slide.id) },
                        modifier = Modifier
                            .then(if (!isDragging) Modifier.animateItem() else Modifier)
                            .zIndex(if (isDragging) 1f else 0f)
                            .graphicsLayer {
                                if (isDragging) {
                                    translationX = dragOffsetX - accumulatedMoveCount * itemWidthPx -
                                        with(density) { dragGroupGapReduce.toPx() } * (slide.spanIndex.coerceAtLeast(0))
                                    alpha = 0.9f
                                    scaleX = 1.05f
                                    scaleY = 1.05f
                                }
                            }
                            .pointerInput(slide.id) {
                                detectDragGestures(
                                    onDragStart = {
                                        draggingSlideId = slide.id
                                        dragOffsetX = 0f
                                        accumulatedMoveCount = 0
                                        val cs = slidesState.value
                                        val gid = cs.find { it.id == slide.id }?.spanGroupId
                                        originalGroupFirstIdx = if (gid != null) {
                                            cs.indexOfFirst { it.spanGroupId == gid }
                                        } else {
                                            cs.indexOfFirst { it.id == slide.id }
                                        }
                                    },
                                    onDrag = { change, dragAmount ->
                                        change.consume()
                                        dragOffsetX += dragAmount.x
                                        val desiredMoveCount = (dragOffsetX / itemWidthPx).roundToInt()
                                        if (desiredMoveCount != accumulatedMoveCount) {
                                            val cs = slidesState.value
                                            val dId = draggingSlideId ?: return@detectDragGestures
                                            val dSlide = cs.find { it.id == dId } ?: return@detectDragGestures
                                            val gid = dSlide.spanGroupId
                                            val groupSize = if (gid != null) cs.count { it.spanGroupId == gid } else 1
                                            var targetIdx = (originalGroupFirstIdx + desiredMoveCount).coerceIn(0, cs.size - groupSize)
                                            // Skip over span groups — don't insert inside them
                                            val targetSlide = cs.getOrNull(targetIdx)
                                            if (targetSlide != null && targetSlide.spanGroupId != null && targetSlide.spanGroupId != gid) {
                                                val spanGid = targetSlide.spanGroupId
                                                val spanFirst = cs.indexOfFirst { it.spanGroupId == spanGid }
                                                val spanLast = cs.indexOfLast { it.spanGroupId == spanGid }
                                                targetIdx = if (desiredMoveCount > accumulatedMoveCount) spanLast + 1 else spanFirst
                                                targetIdx = targetIdx.coerceIn(0, cs.size - groupSize)
                                            }
                                            onMoveSlideState.value(dId, targetIdx)
                                            accumulatedMoveCount = desiredMoveCount
                                        }
                                    },
                                    onDragEnd = {
                                        draggingSlideId = null
                                        dragOffsetX = 0f
                                        accumulatedMoveCount = 0
                                    },
                                    onDragCancel = {
                                        draggingSlideId = null
                                        dragOffsetX = 0f
                                        accumulatedMoveCount = 0
                                    },
                                )
                            },
                    )
                }

                item {
                    IconButton(onClick = onAddSlide, modifier = Modifier.pointerHoverIcon(PointerIcon.Hand)) {
                        Icon(TablerIcons.Plus, contentDescription = "Add slide", modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun SlideThumbnail(
    slide: Slide,
    ratio: Float,
    isSelected: Boolean,
    isInSelectedGroup: Boolean = false,
    onClick: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isInSelectedGroup -> MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
        else -> Color.LightGray
    }
    val borderWidth = if (isSelected || isInSelectedGroup) 2.dp else 1.dp

    Box(modifier = modifier) {
        Column(
            modifier = Modifier
                .width(60.dp)
                .clip(RoundedCornerShape(4.dp))
                .border(borderWidth, borderColor, RoundedCornerShape(4.dp))
                .clickable { onClick() }
                .pointerHoverIcon(PointerIcon.Hand),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(ratio)
                    .clip(RoundedCornerShape(4.dp))
                    .clipToBounds()
                    .background(Color.White),
            ) {
                if (slide.elements.isNotEmpty()) {
                    SlidePreview(
                        slide = slide,
                        aspectRatio = AspectRatio.PORTRAIT_4_3,
                        fillFraction = 1f,
                    )
                }
            }
        }

        IconButton(
            onClick = onRemove,
            modifier = Modifier.align(Alignment.TopEnd).size(18.dp).pointerHoverIcon(PointerIcon.Hand),
        ) {
            Icon(
                TablerIcons.X,
                contentDescription = "Remove slide",
                tint = Color.Gray,
                modifier = Modifier.size(10.dp),
            )
        }
    }
}
