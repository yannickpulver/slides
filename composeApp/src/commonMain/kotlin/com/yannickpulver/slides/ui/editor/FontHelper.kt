package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.text.font.FontFamily

expect fun getAvailableFontFamilies(): List<String>

/** Returns null if fonts are still loading, list when ready */
expect fun getAvailableFontFamiliesOrNull(): List<String>?

expect fun fontFamilyFromName(name: String): FontFamily
