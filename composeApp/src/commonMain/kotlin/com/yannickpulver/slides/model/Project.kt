package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
@Serializable
data class Project(
    val id: String = Uuid.random().toString(),
    val name: String = "Untitled",
    val aspectRatio: AspectRatio = AspectRatio.INSTAGRAM_PORTRAIT,
    val slides: List<Slide> = listOf(Slide()),
)

@Serializable
enum class AspectRatio(val width: Int, val height: Int) {
    INSTAGRAM_PORTRAIT(1080, 1440),
}
