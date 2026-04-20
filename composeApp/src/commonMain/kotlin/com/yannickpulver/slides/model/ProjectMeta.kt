package com.yannickpulver.slides.model

data class ProjectMeta(
    val firstSlide: Slide?,
    val aspectRatio: AspectRatio,
    val slideCount: Int,
    val hasPanorama: Boolean,
)
