package com.yannickpulver.slides.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import org.jetbrains.compose.resources.Font
import slides.composeapp.generated.resources.Res
import slides.composeapp.generated.resources.miranda_sans_bold
import slides.composeapp.generated.resources.miranda_sans_italic
import slides.composeapp.generated.resources.miranda_sans_medium
import slides.composeapp.generated.resources.miranda_sans_regular
import slides.composeapp.generated.resources.miranda_sans_semibold

@Composable
fun AppFontFamily(): FontFamily = FontFamily(
    Font(Res.font.miranda_sans_regular, weight = FontWeight.Normal),
    Font(Res.font.miranda_sans_medium, weight = FontWeight.Medium),
    Font(Res.font.miranda_sans_semibold, weight = FontWeight.SemiBold),
    Font(Res.font.miranda_sans_bold, weight = FontWeight.Bold),
    Font(Res.font.miranda_sans_italic, weight = FontWeight.Normal, style = FontStyle.Italic),
)

@Composable
fun AppTypography(): Typography {
    val fontFamily = AppFontFamily()
    val default = Typography()
    return Typography(
        displayLarge = default.displayLarge.copy(fontFamily = fontFamily),
        displayMedium = default.displayMedium.copy(fontFamily = fontFamily),
        displaySmall = default.displaySmall.copy(fontFamily = fontFamily),
        headlineLarge = default.headlineLarge.copy(fontFamily = fontFamily),
        headlineMedium = default.headlineMedium.copy(fontFamily = fontFamily),
        headlineSmall = default.headlineSmall.copy(fontFamily = fontFamily),
        titleLarge = default.titleLarge.copy(fontFamily = fontFamily),
        titleMedium = default.titleMedium.copy(fontFamily = fontFamily),
        titleSmall = default.titleSmall.copy(fontFamily = fontFamily),
        bodyLarge = default.bodyLarge.copy(fontFamily = fontFamily),
        bodyMedium = default.bodyMedium.copy(fontFamily = fontFamily),
        bodySmall = default.bodySmall.copy(fontFamily = fontFamily),
        labelLarge = default.labelLarge.copy(fontFamily = fontFamily),
        labelMedium = default.labelMedium.copy(fontFamily = fontFamily),
        labelSmall = default.labelSmall.copy(fontFamily = fontFamily),
    )
}
