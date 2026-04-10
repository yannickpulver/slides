package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import org.bytedeco.javacv.FFmpegFrameGrabber
import org.bytedeco.javacv.Java2DFrameConverter
import java.awt.geom.AffineTransform
import java.awt.image.BufferedImage
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
            val corrected = loadExifCorrectedImage(file) ?: return null
            corrected.toComposeImageBitmap()
        }
    } catch (e: Exception) {
        null
    }
}

internal fun loadExifCorrectedImage(file: File): BufferedImage? {
    val orientation = readExifOrientation(file)
    val image = ImageIO.read(file) ?: return null
    return applyExifOrientation(image, orientation)
}

private fun readExifOrientation(file: File): Int {
    return try {
        file.inputStream().use { stream ->
            val bytes = stream.readNBytes(65536) // EXIF is always in first 64KB
            if (bytes.size < 4 || bytes[0] != 0xFF.toByte() || bytes[1] != 0xD8.toByte()) return 1 // Not JPEG

            var offset = 2
            while (offset + 4 < bytes.size) {
                if (bytes[offset] != 0xFF.toByte()) return 1
                val marker = bytes[offset + 1].toInt() and 0xFF
                if (marker == 0xE1) { // APP1
                    val segLen = ((bytes[offset + 2].toInt() and 0xFF) shl 8) or (bytes[offset + 3].toInt() and 0xFF)
                    val segStart = offset + 4
                    if (segStart + 6 > bytes.size) return 1
                    val exif = String(bytes, segStart, 4, Charsets.US_ASCII)
                    if (exif != "Exif") { offset += 2 + segLen; continue }

                    val tiffStart = segStart + 6
                    if (tiffStart + 8 > bytes.size) return 1

                    val bigEndian = bytes[tiffStart].toInt() and 0xFF == 0x4D

                    fun u16(o: Int): Int = if (bigEndian)
                        ((bytes[o].toInt() and 0xFF) shl 8) or (bytes[o + 1].toInt() and 0xFF)
                    else
                        ((bytes[o + 1].toInt() and 0xFF) shl 8) or (bytes[o].toInt() and 0xFF)

                    fun u32(o: Int): Int = if (bigEndian)
                        ((bytes[o].toInt() and 0xFF) shl 24) or ((bytes[o + 1].toInt() and 0xFF) shl 16) or
                            ((bytes[o + 2].toInt() and 0xFF) shl 8) or (bytes[o + 3].toInt() and 0xFF)
                    else
                        ((bytes[o + 3].toInt() and 0xFF) shl 24) or ((bytes[o + 2].toInt() and 0xFF) shl 16) or
                            ((bytes[o + 1].toInt() and 0xFF) shl 8) or (bytes[o].toInt() and 0xFF)

                    val ifdOffset = tiffStart + u32(tiffStart + 4)
                    if (ifdOffset + 2 > bytes.size) return 1

                    val count = u16(ifdOffset)
                    for (i in 0 until count) {
                        val e = ifdOffset + 2 + i * 12
                        if (e + 12 > bytes.size) return 1
                        if (u16(e) == 0x0112) return u16(e + 8) // Orientation tag
                    }
                    return 1
                }
                val segLen = ((bytes[offset + 2].toInt() and 0xFF) shl 8) or (bytes[offset + 3].toInt() and 0xFF)
                offset += 2 + segLen
            }
            1
        }
    } catch (e: Exception) {
        1
    }
}

private fun applyExifOrientation(image: BufferedImage, orientation: Int): BufferedImage {
    if (orientation == 1) return image

    val w = image.width
    val h = image.height
    val swapDimensions = orientation in 5..8
    val newW = if (swapDimensions) h else w
    val newH = if (swapDimensions) w else h

    val transform = AffineTransform()
    when (orientation) {
        2 -> { transform.scale(-1.0, 1.0); transform.translate(-w.toDouble(), 0.0) }
        3 -> { transform.translate(w.toDouble(), h.toDouble()); transform.rotate(Math.PI) }
        4 -> { transform.scale(1.0, -1.0); transform.translate(0.0, -h.toDouble()) }
        5 -> { transform.rotate(Math.PI / 2); transform.scale(1.0, -1.0) }
        6 -> { transform.translate(h.toDouble(), 0.0); transform.rotate(Math.PI / 2) }
        7 -> { transform.translate(h.toDouble(), w.toDouble()); transform.rotate(Math.PI / 2); transform.scale(-1.0, 1.0); transform.translate(-w.toDouble(), 0.0) }
        8 -> { transform.translate(0.0, w.toDouble()); transform.rotate(-Math.PI / 2) }
    }

    val result = BufferedImage(newW, newH, image.type.takeIf { it != 0 } ?: BufferedImage.TYPE_INT_ARGB)
    val g = result.createGraphics()
    g.transform(transform)
    g.drawImage(image, 0, 0, null)
    g.dispose()
    return result
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
