package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import org.bytedeco.javacv.FFmpegFrameGrabber
import org.bytedeco.javacv.Java2DFrameConverter
import java.io.File
import javax.imageio.ImageIO

private val videoExtensions = setOf("mp4", "mov", "avi", "mkv", "webm")

actual fun loadImageBitmap(path: String): ImageBitmap? {
    return try {
        val file = File(path)
        if (!file.exists()) return null
        val ext = file.extension.lowercase()
        if (ext in videoExtensions) {
            loadVideoThumbnail(path)
        } else {
            val bufferedImage = ImageIO.read(file) ?: return null
            bufferedImage.toComposeImageBitmap()
        }
    } catch (e: Exception) {
        null
    }
}

private fun loadVideoThumbnail(path: String): ImageBitmap? {
    val grabber = FFmpegFrameGrabber(path)
    val converter = Java2DFrameConverter()
    return try {
        grabber.start()
        val frame = grabber.grabKeyFrame() ?: grabber.grabImage()
        val bufferedImage = frame?.let { converter.convert(it) }
        bufferedImage?.toComposeImageBitmap()
    } finally {
        grabber.stop()
        grabber.release()
    }
}
