package com.yannickpulver.slides.ui.editor

import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaType
import com.yannickpulver.slides.model.Slide
import org.bytedeco.ffmpeg.global.avutil
import org.bytedeco.javacv.FFmpegFrameGrabber
import org.bytedeco.javacv.FFmpegFrameRecorder
import org.bytedeco.javacv.Java2DFrameConverter
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import kotlin.math.roundToInt

actual fun exportSlideAsImage(
    slide: Slide,
    aspectRatio: AspectRatio,
    outputDir: String,
    scaleFactor: Int,
    slideIndex: Int,
    onProgress: (Float) -> Unit,
) {
    val hasVideo = slide.elements.any { it.type == MediaType.VIDEO }
    if (hasVideo) {
        exportSlideAsVideo(slide, aspectRatio, outputDir, scaleFactor, slideIndex, onProgress)
    } else {
        exportSlideAsPng(slide, aspectRatio, outputDir, scaleFactor, slideIndex)
        onProgress(1f)
    }
}

private fun exportSlideAsPng(slide: Slide, aspectRatio: AspectRatio, outputDir: String, scaleFactor: Int, slideIndex: Int) {
    val width = aspectRatio.width * scaleFactor
    val height = aspectRatio.height * scaleFactor
    val canvas = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    val g2d = canvas.createGraphics()
    setupGraphics(g2d)
    g2d.color = java.awt.Color.WHITE
    g2d.fillRect(0, 0, width, height)

    slide.elements.sortedBy { it.zIndex }.forEach { element ->
        try {
            val sourceImage = ImageIO.read(File(element.sourcePath)) ?: return@forEach
            drawElementToGraphics(g2d, sourceImage, element, width, height)
        } catch (_: Exception) {}
    }

    g2d.dispose()
    val suffix = if (scaleFactor > 1) "@${scaleFactor}x" else ""
    val outputFile = File(outputDir, "slide${slideIndex}-${slide.id.take(8)}${suffix}.png")
    ImageIO.write(canvas, "png", outputFile)
    println("Exported: ${outputFile.absolutePath}")
}

private fun exportSlideAsVideo(
    slide: Slide,
    aspectRatio: AspectRatio,
    outputDir: String,
    scaleFactor: Int,
    slideIndex: Int,
    onProgress: (Float) -> Unit,
) {
    val width = aspectRatio.width * scaleFactor
    val height = aspectRatio.height * scaleFactor
    val fps = 30.0
    val outputFile = File(outputDir, "slide${slideIndex}-${slide.id.take(8)}.mp4")

    val videoElements = slide.elements.filter { it.type == MediaType.VIDEO }
    val imageElements = slide.elements.filter { it.type == MediaType.IMAGE }

    // Open grabbers and probe durations
    var maxDurationUs = 0L
    val videoGrabbers = videoElements.map { element ->
        val grabber = FFmpegFrameGrabber(element.sourcePath).apply { start() }
        if (grabber.lengthInTime > maxDurationUs) maxDurationUs = grabber.lengthInTime
        element to grabber
    }
    if (maxDurationUs <= 0) maxDurationUs = 3_000_000L

    val totalFrames = ((maxDurationUs / 1_000_000.0) * fps).toInt()
    val converter = Java2DFrameConverter()

    // Cache static images
    val imageCache = imageElements.associateWith { element ->
        try { ImageIO.read(File(element.sourcePath)) } catch (_: Exception) { null }
    }

    // Cache latest video frame per element — pre-grab first frame
    val videoFrameCache = mutableMapOf<String, BufferedImage>()
    for ((element, grabber) in videoGrabbers) {
        val frame = grabber.grabImage()
        if (frame != null) {
            val bimg = converter.convert(frame)
            if (bimg != null) videoFrameCache[element.id] = bimg
        }
    }

    // Separate audio grabber from first video (grabImage() skips audio frames)
    val audioGrabber = if (videoElements.isNotEmpty()) {
        try {
            FFmpegFrameGrabber(videoElements.first().sourcePath).apply { start() }
        } catch (_: Exception) { null }
    } else null
    val hasAudio = audioGrabber != null && audioGrabber.audioChannels > 0

    val recorder = FFmpegFrameRecorder(outputFile, width, height).apply {
        frameRate = fps
        format = "mp4"
        videoBitrate = 15_000_000
        pixelFormat = avutil.AV_PIX_FMT_YUV420P
        videoCodecName = "h264_videotoolbox"
        if (hasAudio) {
            audioChannels = audioGrabber!!.audioChannels
            sampleRate = audioGrabber.sampleRate
            audioCodecName = "aac"
            audioBitrate = 192_000
        }
        start()
    }

    try {
        for (frameIndex in 0 until totalFrames) {
            val targetUs = ((frameIndex / fps) * 1_000_000).toLong()

            // Advance each video grabber to the target timestamp
            for ((element, grabber) in videoGrabbers) {
                // Grab frames until we're at or past the target time
                while (grabber.timestamp < targetUs) {
                    val frame = grabber.grabImage() ?: break
                    // Only convert the frame we'll actually use
                    if (grabber.timestamp >= targetUs - 50_000) {
                        val bimg = converter.convert(frame)
                        if (bimg != null) videoFrameCache[element.id] = bimg
                    }
                }
            }

            // Composite all elements onto canvas
            val canvas = BufferedImage(width, height, BufferedImage.TYPE_3BYTE_BGR)
            val g2d = canvas.createGraphics()
            setupGraphics(g2d)
            g2d.color = java.awt.Color.WHITE
            g2d.fillRect(0, 0, width, height)

            slide.elements.sortedBy { it.zIndex }.forEach { element ->
                val img = when (element.type) {
                    MediaType.IMAGE -> imageCache[element]
                    MediaType.VIDEO -> videoFrameCache[element.id]
                }
                if (img != null) drawElementToGraphics(g2d, img, element, width, height)
            }

            g2d.dispose()
            recorder.record(converter.convert(canvas))

            // Record audio samples up to this timestamp
            if (hasAudio && audioGrabber != null) {
                while (audioGrabber.timestamp < targetUs + 50_000) {
                    val samples = audioGrabber.grabSamples() ?: break
                    if (samples.samples != null) {
                        recorder.recordSamples(*samples.samples)
                    }
                }
            }

            // Progress update every 10 frames
            if (frameIndex % 10 == 0) {
                onProgress((frameIndex + 1).toFloat() / totalFrames)
            }
        }
    } finally {
        recorder.stop()
        recorder.release()
        videoGrabbers.forEach { (_, g) ->
            try { g.stop(); g.release() } catch (_: Exception) {}
        }
        try { audioGrabber?.stop(); audioGrabber?.release() } catch (_: Exception) {}
    }

    onProgress(1f)
    println("Exported: ${outputFile.absolutePath}")
}

private fun setupGraphics(g2d: Graphics2D) {
    g2d.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC)
    g2d.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY)
    g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
}

private fun drawElementToGraphics(
    g2d: Graphics2D,
    sourceImage: BufferedImage,
    element: MediaElement,
    canvasWidth: Int,
    canvasHeight: Int,
) {
    val slotX = (element.bounds.x * canvasWidth).roundToInt()
    val slotY = (element.bounds.y * canvasHeight).roundToInt()
    val slotW = (element.bounds.width * canvasWidth).roundToInt()
    val slotH = (element.bounds.height * canvasHeight).roundToInt()

    val prevClip = g2d.clip
    g2d.clipRect(slotX, slotY, slotW, slotH)

    val imgW = sourceImage.width.toFloat()
    val imgH = sourceImage.height.toFloat()
    val fillScale = maxOf(slotW / imgW, slotH / imgH)
    val totalScale = fillScale * element.cropScale

    val drawW = (imgW * totalScale).roundToInt()
    val drawH = (imgH * totalScale).roundToInt()

    // Offsets are normalized fractions of slot size
    val centerX = slotX + (slotW - drawW) / 2 + (element.cropOffsetX * slotW).roundToInt()
    val centerY = slotY + (slotH - drawH) / 2 + (element.cropOffsetY * slotH).roundToInt()

    // Progressive downscale for quality — halve until close to target, then final resize
    val scaled = progressiveScale(sourceImage, drawW, drawH)
    g2d.drawImage(scaled, centerX, centerY, drawW, drawH, null)
    g2d.clip = prevClip
}

private fun progressiveScale(src: BufferedImage, targetW: Int, targetH: Int): BufferedImage {
    var w = src.width
    var h = src.height
    var img = src

    // Halve dimensions until within 2x of target
    while (w / 2 > targetW && h / 2 > targetH) {
        w /= 2
        h /= 2
        val step = BufferedImage(w, h, src.type.takeIf { it != 0 } ?: BufferedImage.TYPE_INT_ARGB)
        val g = step.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR)
        g.drawImage(img, 0, 0, w, h, null)
        g.dispose()
        img = step
    }
    return img
}
