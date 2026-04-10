package com.yannickpulver.slides

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
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

private val GrayColorScheme = lightColorScheme(
    primary = Color(0xFF616161),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE0E0E0),
    onPrimaryContainer = Color(0xFF1A1A1A),
    secondary = Color(0xFF757575),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFEEEEEE),
    onSecondaryContainer = Color(0xFF1A1A1A),
    surface = Color(0xFFFAFAFA),
    onSurface = Color(0xFF1A1A1A),
    surfaceVariant = Color(0xFFF5F5F5),
    onSurfaceVariant = Color(0xFF424242),
    surfaceContainerLow = Color(0xFFF0F0F0),
    surfaceContainer = Color(0xFFEAEAEA),
    outline = Color(0xFFBDBDBD),
    outlineVariant = Color(0xFFE0E0E0),
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
