package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.platform.Font
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicReference

private val fontNamesRef = AtomicReference<List<String>?>(null)
private val fontFileIndex = ConcurrentHashMap<String, File>()

// Kick off font indexing eagerly on a daemon thread at class load time
private val fontIndexThread = Thread({
    val fontDirs = listOf(
        "/System/Library/Fonts",
        "/Library/Fonts",
        System.getProperty("user.home") + "/Library/Fonts",
    )
    val familyToFile = mutableMapOf<String, File>()
    for (dir in fontDirs) {
        val dirFile = File(dir)
        if (!dirFile.isDirectory) continue
        dirFile.walk().filter { it.extension.lowercase() in setOf("ttf", "otf", "ttc") }.forEach { file ->
            try {
                val fonts = java.awt.Font.createFonts(file)
                for (f in fonts) {
                    familyToFile.putIfAbsent(f.family, file)
                }
            } catch (_: Exception) {}
        }
    }
    fontFileIndex.putAll(familyToFile)
    fontNamesRef.set(familyToFile.keys.filter { !it.startsWith(".") }.sorted())
}, "font-indexer").apply { isDaemon = true; start() }

actual fun getAvailableFontFamilies(): List<String> {
    return fontNamesRef.get() ?: run {
        fontIndexThread.join()
        fontNamesRef.get() ?: emptyList()
    }
}

actual fun getAvailableFontFamiliesOrNull(): List<String>? = fontNamesRef.get()

private val fontFamilyCache = ConcurrentHashMap<String, FontFamily>()

fun awtFontFromName(name: String, size: Float): java.awt.Font {
    val file = fontFileIndex[name]
    return if (file != null) {
        try {
            java.awt.Font.createFont(java.awt.Font.TRUETYPE_FONT, file).deriveFont(size)
        } catch (_: Exception) {
            java.awt.Font(java.awt.Font.SANS_SERIF, java.awt.Font.PLAIN, size.toInt())
        }
    } else {
        java.awt.Font(name.ifEmpty { java.awt.Font.SANS_SERIF }, java.awt.Font.PLAIN, size.toInt())
    }
}

actual fun fontFamilyFromName(name: String): FontFamily {
    return fontFamilyCache.getOrPut(name) {
        val file = fontFileIndex[name] ?: return@getOrPut FontFamily.Default
        try {
            FontFamily(Font(file, FontWeight.Normal, FontStyle.Normal))
        } catch (_: Exception) {
            FontFamily.Default
        }
    }
}
