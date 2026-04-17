package com.yannickpulver.slides

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.yannickpulver.slides.model.ProjectEntry
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.ui.editor.EditorScreen
import com.yannickpulver.slides.ui.editor.EditorViewModel
import com.yannickpulver.slides.ui.projects.ProjectPickerScreen
import com.yannickpulver.slides.ui.theme.AppTypography

private val GrayColorScheme = darkColorScheme(
    primary = Color(0xFFBDBDBD),
    onPrimary = Color(0xFF171717),
    primaryContainer = Color(0xFF3A3A3A),
    onPrimaryContainer = Color(0xFFEAEAEA),
    secondary = Color(0xFFA0A0A0),
    onSecondary = Color(0xFF171717),
    secondaryContainer = Color(0xFF333333),
    onSecondaryContainer = Color(0xFFEAEAEA),
    background = Color(0xFF171717),
    onBackground = Color(0xFFEAEAEA),
    surface = Color(0xFF171717),
    onSurface = Color(0xFFEAEAEA),
    surfaceVariant = Color(0xFF272727),
    onSurfaceVariant = Color(0xFFBDBDBD),
    surfaceContainerLowest = Color(0xFF121212),
    surfaceContainerLow = Color(0xFF1E1E1E),
    surfaceContainer = Color(0xFF272727),
    surfaceContainerHigh = Color(0xFF303030),
    surfaceContainerHighest = Color(0xFF3A3A3A),
    outline = Color(0xFF5A5A5A),
    outlineVariant = Color(0xFF3A3A3A),
)

enum class Screen { ProjectPicker, Editor }

@Composable
fun App(
    viewModel: EditorViewModel,
    projects: List<ProjectEntry>,
    firstSlides: Map<String, Slide?>,
    onCreateProject: () -> Unit,
    onOpenProject: (ProjectEntry) -> Unit,
    onDeleteProject: (ProjectEntry) -> Unit,
    currentScreen: Screen,
    onBackToProjects: () -> Unit,
) {
    MaterialTheme(colorScheme = GrayColorScheme, typography = AppTypography()) {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            when (currentScreen) {
                Screen.ProjectPicker -> ProjectPickerScreen(
                    projects = projects,
                    firstSlides = firstSlides,
                    onCreateProject = onCreateProject,
                    onOpenProject = onOpenProject,
                    onDeleteProject = onDeleteProject,
                )
                Screen.Editor -> EditorScreen(viewModel, onBack = onBackToProjects)
            }
        }
    }
}
