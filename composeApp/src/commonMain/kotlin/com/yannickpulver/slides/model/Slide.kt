package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class Slide(
    val id: String = Uuid.random().toString(),
    val elements: List<MediaElement> = emptyList(),
    val template: SlideTemplate = SlideTemplate.SINGLE,
    val hasChosenTemplate: Boolean = false,
)

@Serializable
enum class SlideTemplate(val slotCount: Int) {
    SINGLE(1),
    TWO_VERTICAL(2),
    THREE_VERTICAL(3),
}
