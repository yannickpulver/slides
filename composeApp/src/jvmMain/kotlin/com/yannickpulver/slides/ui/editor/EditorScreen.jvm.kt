package com.yannickpulver.slides.ui.editor

import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaFitMode
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
    val bgColor = if (slide.gapPx > 0f && slide.elements.isNotEmpty())
        awtColor(slide.elements.first().backgroundColorArgb)
    else java.awt.Color.WHITE
    g2d.color = bgColor
    g2d.fillRect(0, 0, width, height)

    slide.elements.sortedBy { it.zIndex }.forEach { element ->
        try {
            val sourceImage = ImageIO.read(File(element.sourcePath)) ?: return@forEach
            drawElementToGraphics(
                g2d, sourceImage, element, width, height, aspectRatio.width, aspectRatio.height,
                spanIndex = slide.spanIndex, spanCount = slide.spanCount,
                gapPx = slide.gapPx, slotCount = slide.template.slotCount,
            )
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
    val hasAudio = audioGrabber?.audioChannels?.let { it > 0 } == true
    val audioSource = audioGrabber.takeIf { hasAudio }

    val recorder = FFmpegFrameRecorder(outputFile, width, height).apply {
        frameRate = fps
        format = "mp4"
        videoBitrate = 15_000_000
        pixelFormat = avutil.AV_PIX_FMT_YUV420P
        videoCodecName = "h264_videotoolbox"
        if (audioSource != null) {
            audioChannels = audioSource.audioChannels
            sampleRate = audioSource.sampleRate
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
            val videoBgColor = if (slide.gapPx > 0f && slide.elements.isNotEmpty())
                awtColor(slide.elements.first().backgroundColorArgb)
            else java.awt.Color.WHITE
            g2d.color = videoBgColor
            g2d.fillRect(0, 0, width, height)

            slide.elements.sortedBy { it.zIndex }.forEach { element ->
                val img = when (element.type) {
                    MediaType.IMAGE -> imageCache[element]
                    MediaType.VIDEO -> videoFrameCache[element.id]
                }
                if (img != null) {
                    drawElementToGraphics(
                        g2d, img, element, width, height, aspectRatio.width, aspectRatio.height,
                        spanIndex = slide.spanIndex, spanCount = slide.spanCount,
                        gapPx = slide.gapPx, slotCount = slide.template.slotCount,
                    )
                }
            }

            g2d.dispose()
            recorder.record(converter.convert(canvas))

            // Record audio samples up to this timestamp
            if (audioSource != null) {
                while (audioSource.timestamp < targetUs + 50_000) {
                    val samples = audioSource.grabSamples() ?: break
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
    logicalCanvasWidth: Int,
    logicalCanvasHeight: Int,
    spanIndex: Int = 0,
    spanCount: Int = 1,
    gapPx: Float = 0f,
    slotCount: Int = 1,
) {
    // Compute gap-adjusted slot positions
    val totalGapPx = gapPx * (slotCount - 1)
    val availableHeight = canvasHeight - totalGapPx
    val slotX = (element.bounds.x * canvasWidth).roundToInt()
    val rawSlotH = (element.bounds.height * availableHeight).roundToInt()
    val slotIndex = (element.bounds.y / element.bounds.height.coerceAtLeast(0.001f)).roundToInt()
    val slotY = (element.bounds.y * availableHeight + slotIndex * gapPx).roundToInt()
    val slotW = (element.bounds.width * canvasWidth).roundToInt()
    val slotH = rawSlotH

    g2d.color = awtColor(element.backgroundColorArgb)
    g2d.fillRect(slotX, slotY, slotW, slotH)

    val prevClip = g2d.clip
    g2d.clipRect(slotX, slotY, slotW, slotH)

    val imgW = sourceImage.width.toFloat()
    val imgH = sourceImage.height.toFloat()
    val effectiveSlotW = slotW.toFloat() * spanCount
    val effectiveLogicalW = logicalCanvasWidth * element.bounds.width * spanCount
    val frame = computeExportFrame(
        slotWidth = effectiveSlotW,
        slotHeight = slotH.toFloat(),
        mediaWidth = imgW,
        mediaHeight = imgH,
        element = element,
        logicalSlotWidth = effectiveLogicalW,
        logicalSlotHeight = logicalCanvasHeight * element.bounds.height,
    )
    val sliceShiftX = frame.shiftX + (effectiveSlotW - slotW.toFloat()) / 2f - (spanIndex * slotW)
    val drawW = frame.drawWidth.roundToInt()
    val drawH = frame.drawHeight.roundToInt()
    val centerX = slotX + (slotW - drawW) / 2 + sliceShiftX.roundToInt()
    val centerY = slotY + (slotH - drawH) / 2 + frame.shiftY.roundToInt()

    val scaled = progressiveScale(sourceImage, drawW, drawH)
    g2d.drawImage(scaled, centerX, centerY, drawW, drawH, null)
    g2d.clip = prevClip
    drawFrameMasks(
        g2d = g2d,
        slotX = slotX,
        slotY = slotY,
        slotWidth = slotW,
        slotHeight = slotH,
        inset = computeFrameInsetPx(
            slotWidth = effectiveSlotW,
            slotHeight = slotH.toFloat(),
            logicalSlotWidth = effectiveLogicalW,
            logicalSlotHeight = logicalCanvasHeight * element.bounds.height,
            frameBorderPx = element.frameBorderPx,
        ).roundToInt(),
        color = awtColor(element.backgroundColorArgb),
        spanIndex = spanIndex,
        spanCount = spanCount,
    )
}

private data class ExportFrame(
    val drawWidth: Float,
    val drawHeight: Float,
    val shiftX: Float,
    val shiftY: Float,
)

private fun computeFrameInsetPx(
    slotWidth: Float,
    slotHeight: Float,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
    frameBorderPx: Float,
): Float {
    val insetScale = minOf(
        slotWidth.coerceAtLeast(1f) / logicalSlotWidth.coerceAtLeast(1f),
        slotHeight.coerceAtLeast(1f) / logicalSlotHeight.coerceAtLeast(1f),
    )
    return frameBorderPx.coerceIn(0f, MAX_FRAME_BORDER_PX) * insetScale
}

private fun computeExportFrame(
    slotWidth: Float,
    slotHeight: Float,
    mediaWidth: Float,
    mediaHeight: Float,
    element: MediaElement,
    logicalSlotWidth: Float,
    logicalSlotHeight: Float,
): ExportFrame {
    val safeSlotWidth = slotWidth.coerceAtLeast(1f)
    val safeSlotHeight = slotHeight.coerceAtLeast(1f)
    val safeMediaWidth = mediaWidth.coerceAtLeast(1f)
    val safeMediaHeight = mediaHeight.coerceAtLeast(1f)
    val inset = computeFrameInsetPx(
        slotWidth = safeSlotWidth,
        slotHeight = safeSlotHeight,
        logicalSlotWidth = logicalSlotWidth,
        logicalSlotHeight = logicalSlotHeight,
        frameBorderPx = element.frameBorderPx,
    )
    val availableWidth = (safeSlotWidth - inset * 2f).coerceAtLeast(1f)
    val availableHeight = (safeSlotHeight - inset * 2f).coerceAtLeast(1f)

    return if (element.fitMode == MediaFitMode.FIT) {
        val fitScale = minOf(availableWidth / safeMediaWidth, availableHeight / safeMediaHeight)
        ExportFrame(
            drawWidth = safeMediaWidth * fitScale,
            drawHeight = safeMediaHeight * fitScale,
            shiftX = 0f,
            shiftY = 0f,
        )
    } else {
        val fillScale = maxOf(availableWidth / safeMediaWidth, availableHeight / safeMediaHeight)
        ExportFrame(
            drawWidth = safeMediaWidth * fillScale * element.cropScale,
            drawHeight = safeMediaHeight * fillScale * element.cropScale,
            // cropOffsetX is normalized to single-slot width, so multiply by full virtual width
            shiftX = element.cropOffsetX * safeSlotWidth,
            shiftY = element.cropOffsetY * safeSlotHeight,
        )
    }
}

private fun awtColor(argb: Long): java.awt.Color {
    val alpha = ((argb shr 24) and 0xFF).toInt()
    val red = ((argb shr 16) and 0xFF).toInt()
    val green = ((argb shr 8) and 0xFF).toInt()
    val blue = (argb and 0xFF).toInt()
    return java.awt.Color(red, green, blue, alpha)
}

private fun drawFrameMasks(
    g2d: Graphics2D,
    slotX: Int,
    slotY: Int,
    slotWidth: Int,
    slotHeight: Int,
    inset: Int,
    color: java.awt.Color,
    spanIndex: Int = 0,
    spanCount: Int = 1,
) {
    if (inset <= 0) return
    g2d.color = color
    // Top — always
    g2d.fillRect(slotX, slotY, slotWidth, inset)
    // Bottom — always
    g2d.fillRect(slotX, slotY + slotHeight - inset, slotWidth, inset)
    // Left — only first in span
    if (spanIndex == 0) g2d.fillRect(slotX, slotY, inset, slotHeight)
    // Right — only last in span
    if (spanIndex == spanCount - 1) g2d.fillRect(slotX + slotWidth - inset, slotY, inset, slotHeight)
}

private const val MAX_FRAME_BORDER_PX = 240f

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
