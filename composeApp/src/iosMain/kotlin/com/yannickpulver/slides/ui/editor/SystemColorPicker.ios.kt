package com.yannickpulver.slides.ui.editor

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

@Composable
actual fun rememberSystemColorPickerLauncher(
    onColorPicked: (Long) -> Unit,
): (Long) -> Unit = remember(onColorPicked) {
    { _ -> }
}
