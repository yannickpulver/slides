package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class Project(
    val id: String = Uuid.random().toString(),
    val name: String = "Untitled",
    val aspectRatio: AspectRatio = AspectRatio.PORTRAIT_4_3,
    val slides: List<Slide> = listOf(Slide()),
)

@Serializable
enum class AspectRatio(val width: Int, val height: Int, val label: String) {
    PORTRAIT_4_3(1080, 1440, "4:3"),
    PORTRAIT_16_9(1080, 1920, "16:9"),
}
