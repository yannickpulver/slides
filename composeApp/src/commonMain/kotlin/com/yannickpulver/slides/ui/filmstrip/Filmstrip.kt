package com.yannickpulver.slides.ui.filmstrip

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
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
    val thumbHeight = 54.dp
    val thumbWidth = thumbHeight * ratio
    val itemWidthPx = with(density) { (thumbWidth + 8.dp).toPx() }

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

    val groups = remember(slides) { groupByPano(slides) }

    Surface(modifier = modifier, color = MaterialTheme.colorScheme.background) {
        Row(
            modifier = Modifier
                .height(86.dp)
                .fillMaxWidth()
                .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            groups.forEach { group ->
                val isSpan = group.size > 1
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val groupSelectId = group.first().id
                    val groupSelected = group.any { it.id == selectedSlideId }
                    group.forEachIndexed { indexInGroup, slide ->
                        val isDragging = slide.id in dragGroupIds
                        val isFirstInDragGroup = isDragging && (slide.spanGroupId == null || slide.spanIndex == 0)
                        val dragGroupGapReduce = if (isDragging && !isFirstInDragGroup) 6.dp else 0.dp
                        val isFirstInGroup = indexInGroup == 0
                        val isLastInGroup = indexInGroup == group.lastIndex

                        Thumb(
                            slide = slide,
                            ratio = ratio,
                            thumbWidth = thumbWidth,
                            thumbHeight = thumbHeight,
                            selected = if (isSpan) groupSelected && isFirstInGroup else slide.id == selectedSlideId,
                            inGroup = isSpan,
                            isFirstInGroup = isFirstInGroup,
                            isLastInGroup = isLastInGroup,
                            showRemove = group.size == 1 && slide.id == selectedSlideId && slides.size > 1,
                            onClick = { onSlideSelect(if (isSpan) groupSelectId else slide.id) },
                            onRemove = { onRemoveSlide(slide.id) },
                            modifier = Modifier
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
                }
            }

            Box(
                modifier = Modifier
                    .width(thumbWidth + 6.dp)
                    .height(thumbHeight + 6.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(7.dp))
                    .pointerHoverIcon(PointerIcon.Hand)
                    .clickable { onAddSlide() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    TablerIcons.Plus,
                    contentDescription = "Add slide",
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.width(4.dp))
        }
    }
}

@Composable
private fun Thumb(
    slide: Slide,
    ratio: Float,
    thumbWidth: androidx.compose.ui.unit.Dp,
    thumbHeight: androidx.compose.ui.unit.Dp,
    selected: Boolean,
    inGroup: Boolean,
    isFirstInGroup: Boolean,
    isLastInGroup: Boolean,
    showRemove: Boolean,
    onClick: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier) {
        Box(
            modifier = Modifier
                .width(thumbWidth)
                .height(thumbHeight)
                .clip(
                    if (inGroup) RoundedCornerShape(
                        topStart = if (isFirstInGroup) 3.dp else 0.dp,
                        bottomStart = if (isFirstInGroup) 3.dp else 0.dp,
                        topEnd = if (isLastInGroup) 3.dp else 0.dp,
                        bottomEnd = if (isLastInGroup) 3.dp else 0.dp,
                    ) else RoundedCornerShape(3.dp)
                )
                .clipToBounds()
                .background(
                    if (slide.elements.isNotEmpty()) Color.White
                    else MaterialTheme.colorScheme.surfaceContainer,
                )
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable { onClick() },
        ) {
            Box(
                modifier = Modifier.fillMaxHeight().width(thumbWidth).aspectRatio(ratio),
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

        if (selected) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = (-10).dp)
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.onSurface),
            )
        }

        if (showRemove) {
            IconButton(
                onClick = onRemove,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .size(15.dp)
                    .pointerHoverIcon(PointerIcon.Hand),
            ) {
                Icon(
                    TablerIcons.X,
                    contentDescription = "Remove slide",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(7.dp),
                )
            }
        }
    }
}

private fun groupByPano(slides: List<Slide>): List<List<Slide>> {
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
