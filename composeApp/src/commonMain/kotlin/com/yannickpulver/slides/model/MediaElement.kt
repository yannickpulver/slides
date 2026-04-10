package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class MediaElement(
    val id: String = Uuid.random().toString(),
    val type: MediaType = MediaType.IMAGE,
    val sourcePath: String,
    val bounds: ElementBounds,
    val zIndex: Int = 0,
    val cropOffsetX: Float = 0f,
    val cropOffsetY: Float = 0f,
    val cropScale: Float = 1f,
    val fitMode: MediaFitMode = MediaFitMode.FILL,
    val frameBorderPx: Float = 0f,
    val backgroundColorArgb: Long = 0xFFFFFFFF,
)

@Serializable
enum class MediaType { IMAGE, VIDEO }

@Serializable
enum class MediaFitMode { FILL, FIT }

@Serializable
data class ElementBounds(
    val x: Float = 0f,
    val y: Float = 0f,
    val width: Float = 1f,
    val height: Float = 1f,
)

@Serializable
enum class TextAlignment { LEFT, CENTER, RIGHT }

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class TextOverlay(
    val id: String = Uuid.random().toString(),
    val text: String = "Text",
    val x: Float = 0.1f,
    val y: Float = 0.1f,
    val width: Float = 0.8f,
    val fontFamily: String = "",
    val fontSizePx: Float = 32f,
    val colorArgb: Long = 0xFFFFFFFF,
    val alignment: TextAlignment = TextAlignment.LEFT,
)
