package com.yannickpulver.slides.ui.editor

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

@Composable
actual fun rememberSystemColorPickerLauncher(
    onColorPicked: (Long) -> Unit,
): (Long) -> Unit {
    val scope = rememberCoroutineScope()
    return remember(onColorPicked) {
        { initialColor ->
            scope.launch {
                val color = withContext(Dispatchers.IO) {
                    chooseSystemColor(initialColor)
                }
                color?.let(onColorPicked)
            }
        }
    }
}

private fun chooseSystemColor(initialColor: Long): Long? {
    val osName = System.getProperty("os.name").orEmpty()
    return if (osName.contains("mac", ignoreCase = true)) {
        chooseMacSystemColor(initialColor)
    } else {
        null
    }
}

private fun chooseMacSystemColor(initialColor: Long): Long? {
    val red16 = argbChannelTo16Bit(initialColor, 16)
    val green16 = argbChannelTo16Bit(initialColor, 8)
    val blue16 = argbChannelTo16Bit(initialColor, 0)
    val script = """
        try
            set pickedColor to choose color default color {$red16, $green16, $blue16}
            return (item 1 of pickedColor as string) & "," & (item 2 of pickedColor as string) & "," & (item 3 of pickedColor as string)
        on error number -128
            return ""
        end try
    """.trimIndent()

    val process = ProcessBuilder("osascript", "-e", script)
        .redirectErrorStream(true)
        .start()
    val output = process.inputStream.bufferedReader().use { it.readText().trim() }
    val exitCode = process.waitFor()
    if (exitCode != 0 || output.isBlank()) return null

    val parts = output.split(',').mapNotNull { it.trim().toIntOrNull() }
    if (parts.size != 3) return null

    val red = convert16BitTo8Bit(parts[0])
    val green = convert16BitTo8Bit(parts[1])
    val blue = convert16BitTo8Bit(parts[2])
    return (0xFFL shl 24) or
        ((red.toLong() and 0xFF) shl 16) or
        ((green.toLong() and 0xFF) shl 8) or
        (blue.toLong() and 0xFF)
}

private fun argbChannelTo16Bit(argb: Long, shift: Int): Int {
    val value8 = ((argb shr shift) and 0xFF).toInt()
    return ((value8 / 255.0) * 65535.0).roundToInt().coerceIn(0, 65535)
}

private fun convert16BitTo8Bit(value: Int): Int =
    ((value.coerceIn(0, 65535) / 65535.0) * 255.0).roundToInt().coerceIn(0, 255)
