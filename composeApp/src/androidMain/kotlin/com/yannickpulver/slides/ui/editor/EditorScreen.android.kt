package com.yannickpulver.slides.ui.editor

import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.Slide

actual fun exportSlideAsImage(
    slide: Slide,
    aspectRatio: AspectRatio,
    outputDir: String,
    scaleFactor: Int,
    slideLabel: String,
    lastModifiedMillis: Long?,
    onProgress: (Float) -> Unit,
) {
    // TODO: Implement Android export
}
