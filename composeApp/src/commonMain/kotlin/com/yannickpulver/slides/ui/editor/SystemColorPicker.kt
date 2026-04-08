package com.yannickpulver.slides.ui.editor

import androidx.compose.runtime.Composable

@Composable
expect fun rememberSystemColorPickerLauncher(
    onColorPicked: (Long) -> Unit,
): (Long) -> Unit
