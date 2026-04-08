package com.yannickpulver.slides.ui.filmstrip

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.unit.dp
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.ui.editor.SlidePreview
import compose.icons.TablerIcons
import compose.icons.tablericons.Plus
import compose.icons.tablericons.X

@Composable
fun Filmstrip(
    slides: List<Slide>,
    selectedSlideId: String?,
    selectedSpanGroupId: String? = null,
    aspectRatio: AspectRatio,
    onSlideSelect: (String) -> Unit,
    onAddSlide: () -> Unit,
    onRemoveSlide: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()

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
                    SlideThumbnail(
                        slide = slide,
                        ratio = ratio,
                        isSelected = slide.id == selectedSlideId,
                        isInSelectedGroup = isInGroup && slide.id != selectedSlideId,
                        onClick = { onSlideSelect(slide.id) },
                        onRemove = { onRemoveSlide(slide.id) },
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
) {
    val borderColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isInSelectedGroup -> MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
        else -> Color.LightGray
    }
    val borderWidth = if (isSelected || isInSelectedGroup) 2.dp else 1.dp

    Box {
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
                        aspectRatio = AspectRatio.INSTAGRAM_PORTRAIT,
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
