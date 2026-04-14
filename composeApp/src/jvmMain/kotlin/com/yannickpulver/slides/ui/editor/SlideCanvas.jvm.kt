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

private const val MAX_CANVAS_PX = 2048

actual fun loadImageBitmap(path: String): ImageBitmap? {
    return try {
        val file = File(path)
        if (!file.exists()) return null
        val ext = file.extension.lowercase()
        if (ext in videoExtensions) {
            loadVideoThumbnail(path)
        } else {
            val corrected = loadExifCorrectedImage(file) ?: return null
            downscale(corrected).toComposeImageBitmap()
        }
    } catch (e: Exception) {
        null
    }
}

private fun downscale(image: BufferedImage): BufferedImage {
    val w = image.width
    val h = image.height
    val longest = maxOf(w, h)
    if (longest <= MAX_CANVAS_PX) return image
    val scale = MAX_CANVAS_PX.toDouble() / longest
    val nw = (w * scale).toInt()
    val nh = (h * scale).toInt()
    val scaled = BufferedImage(nw, nh, image.type.takeIf { it != 0 } ?: BufferedImage.TYPE_INT_ARGB)
    val g = scaled.createGraphics()
    g.setRenderingHint(java.awt.RenderingHints.KEY_INTERPOLATION, java.awt.RenderingHints.VALUE_INTERPOLATION_BILINEAR)
    g.drawImage(image, 0, 0, nw, nh, null)
    g.dispose()
    return scaled
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

internal fun readVideoRotation(grabber: FFmpegFrameGrabber): Int {
    return try {
        // displayRotation reads the display matrix side data (modern videos)
        val dr = grabber.displayRotation
        if (dr != 0.0) {
            // displayRotation is negative for CW rotation, normalize to positive degrees
            return (((-dr).toInt() % 360) + 360) % 360
        }
        // Fallback to metadata tag (older videos)
        val rotate = grabber.videoMetadata?.get("rotate")?.toIntOrNull()
            ?: grabber.metadata?.get("rotate")?.toIntOrNull()
        if (rotate != null) ((rotate % 360) + 360) % 360 else 0
    } catch (_: Exception) {
        0
    }
}

internal fun applyVideoRotation(image: BufferedImage, rotation: Int): BufferedImage {
    if (rotation == 0) return image
    val w = image.width
    val h = image.height
    val swap = rotation == 90 || rotation == 270
    val newW = if (swap) h else w
    val newH = if (swap) w else h
    val transform = AffineTransform()
    when (rotation) {
        90 -> { transform.translate(h.toDouble(), 0.0); transform.rotate(Math.PI / 2) }
        180 -> { transform.translate(w.toDouble(), h.toDouble()); transform.rotate(Math.PI) }
        270 -> { transform.translate(0.0, w.toDouble()); transform.rotate(-Math.PI / 2) }
    }
    val result = BufferedImage(newW, newH, image.type.takeIf { it != 0 } ?: BufferedImage.TYPE_INT_ARGB)
    val g = result.createGraphics()
    g.transform(transform)
    g.drawImage(image, 0, 0, null)
    g.dispose()
    return result
}

actual fun getVideoInfo(path: String): VideoInfo {
    val grabber = FFmpegFrameGrabber(path)
    return try {
        grabber.start()
        VideoInfo(
            rotation = readVideoRotation(grabber),
            codedWidth = grabber.imageWidth,
            codedHeight = grabber.imageHeight,
        )
    } catch (_: Exception) {
        VideoInfo(0, 0, 0)
    } finally {
        try { grabber.stop(); grabber.release() } catch (_: Exception) {}
    }
}

private fun loadVideoThumbnail(path: String): ImageBitmap? {
    val grabber = FFmpegFrameGrabber(path)
    val converter = Java2DFrameConverter()
    return try {
        grabber.start()
        val rotation = readVideoRotation(grabber)
        val frame = grabber.grabKeyFrame() ?: grabber.grabImage()
        val bufferedImage = frame?.let { converter.convert(it) } ?: return null
        applyVideoRotation(bufferedImage, rotation).toComposeImageBitmap()
    } finally {
        grabber.stop()
        grabber.release()
    }
}
