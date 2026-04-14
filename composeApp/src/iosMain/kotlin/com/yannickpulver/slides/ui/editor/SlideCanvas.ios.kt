package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.graphics.ImageBitmap

actual fun loadImageBitmap(path: String): ImageBitmap? {
    // TODO: Implement iOS image loading
    return null
}

actual fun getVideoInfo(path: String): VideoInfo = VideoInfo(0, 0, 0)
