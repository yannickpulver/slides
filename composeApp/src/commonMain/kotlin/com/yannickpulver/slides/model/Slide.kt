package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class Slide(
    val id: String = Uuid.random().toString(),
    val elements: List<MediaElement> = emptyList(),
    val textOverlays: List<TextOverlay> = emptyList(),
    val template: SlideTemplate = SlideTemplate.SINGLE,
    val hasChosenTemplate: Boolean = false,
    val gapPx: Float = 0f,
    val spanGroupId: String? = null,
    val spanIndex: Int = 0,
    val spanCount: Int = 1,
) {
    val isSpan: Boolean get() = spanGroupId != null
}

@Serializable
enum class SlideTemplate(val slotCount: Int) {
    SINGLE(1),
    TWO_VERTICAL(2),
    THREE_VERTICAL(3),
    SPAN_2(1),
    SPAN_3(1),
    SPAN_4(1),
    SPAN_5(1),
}

fun SlideTemplate.spanSize(): Int? = when (this) {
    SlideTemplate.SPAN_2 -> 2
    SlideTemplate.SPAN_3 -> 3
    SlideTemplate.SPAN_4 -> 4
    SlideTemplate.SPAN_5 -> 5
    else -> null
}

val SlideTemplate.isSpanTemplate: Boolean get() = spanSize() != null
