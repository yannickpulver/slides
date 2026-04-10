package com.yannickpulver.slides.ui.editor

import androidx.compose.ui.text.font.FontFamily

actual fun getAvailableFontFamilies(): List<String> = emptyList()

actual fun getAvailableFontFamiliesOrNull(): List<String>? = emptyList()

actual fun fontFamilyFromName(name: String): FontFamily = FontFamily.Default
