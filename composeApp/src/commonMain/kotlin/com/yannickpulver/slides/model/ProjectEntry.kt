package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable

@Serializable
data class ProjectEntry(
    val id: String,
    val name: String,
    val filePath: String,
    val lastModified: Long,
)
