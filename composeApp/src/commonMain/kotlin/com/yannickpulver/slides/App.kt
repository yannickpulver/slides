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
import com.yannickpulver.slides.model.ProjectMeta
import com.yannickpulver.slides.ui.editor.EditorScreen
import com.yannickpulver.slides.ui.editor.EditorViewModel
import com.yannickpulver.slides.ui.projects.ProjectPickerScreen
import com.yannickpulver.slides.ui.theme.AppTypography

private val GrayColorScheme = darkColorScheme(
    primary = Color(0xFFEDEDEF),
    onPrimary = Color(0xFF0E0E0F),
    primaryContainer = Color(0xFF2A2A2E),
    onPrimaryContainer = Color(0xFFEDEDEF),
    secondary = Color(0xFF8E8E93),
    onSecondary = Color(0xFF0E0E0F),
    secondaryContainer = Color(0xFF1D1D20),
    onSecondaryContainer = Color(0xFFEDEDEF),
    background = Color(0xFF0E0E0F),
    onBackground = Color(0xFFEDEDEF),
    surface = Color(0xFF0E0E0F),
    onSurface = Color(0xFFEDEDEF),
    surfaceVariant = Color(0xFF1D1D20),
    onSurfaceVariant = Color(0xFF8E8E93),
    surfaceContainerLowest = Color(0xFF0A0A0B),
    surfaceContainerLow = Color(0xFF121214),
    surfaceContainer = Color(0xFF17171A),
    surfaceContainerHigh = Color(0xFF1D1D20),
    surfaceContainerHighest = Color(0xFF232327),
    outline = Color(0xFF2A2A2E),
    outlineVariant = Color(0xFF232327),
)

enum class Screen { ProjectPicker, Editor }

@Composable
fun App(
    viewModel: EditorViewModel,
    projects: List<ProjectEntry>,
    projectMetas: Map<String, ProjectMeta?>,
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
                    projectMetas = projectMetas,
                    onCreateProject = onCreateProject,
                    onOpenProject = onOpenProject,
                    onDeleteProject = onDeleteProject,
                )
                Screen.Editor -> EditorScreen(viewModel, onBack = onBackToProjects)
            }
        }
    }
}
