package com.yannickpulver.slides.model

data class ExportConfig(
    val outputDir: String,
    val imageFormat: ImageFormat = ImageFormat.PNG,
    val staticImageDurationSec: Float = 3f,
    val fps: Int = 30,
)

enum class ImageFormat(val extension: String) {
    PNG("png"),
    JPEG("jpg"),
}
