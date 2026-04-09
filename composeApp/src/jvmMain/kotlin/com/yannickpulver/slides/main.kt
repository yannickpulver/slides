package com.yannickpulver.slides

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyShortcut
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.MenuBar
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.yannickpulver.slides.data.ProjectStore
import com.yannickpulver.slides.model.Project
import com.yannickpulver.slides.model.ProjectEntry
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.ui.editor.EditorViewModel
import io.github.vinceglb.filekit.FileKit
import io.github.vinceglb.filekit.dialogs.FileKitType
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.dialogs.compose.rememberFileSaverLauncher
import io.github.vinceglb.filekit.path
import java.io.File

fun main() {
    FileKit.init(appId = "com.yannickpulver.slides")
    application {
        val projectStore = remember { ProjectStore() }
        val viewModel = remember { EditorViewModel() }
        var currentScreen by remember { mutableStateOf(Screen.ProjectPicker) }
        var projects by remember { mutableStateOf(projectStore.listProjects()) }
        var firstSlides by remember {
            mutableStateOf(projects.associate { it.id to projectStore.loadFirstSlide(it.filePath) })
        }

        fun refreshProjects() {
            projects = projectStore.listProjects()
            firstSlides = projects.associate { it.id to projectStore.loadFirstSlide(it.filePath) }
        }

        fun openProject(entry: ProjectEntry) {
            try {
                val project = projectStore.loadProject(entry.filePath)
                viewModel.loadProject(project, entry.filePath)
                currentScreen = Screen.Editor
            } catch (e: Exception) {
                println("Failed to open: ${e.message}")
            }
        }

        fun saveCurrentProject() {
            val state = viewModel.state.value
            val path = state.projectFilePath ?: return
            projectStore.saveProject(state.project, path)
            refreshProjects()
        }

        Window(
            onCloseRequest = {
                if (currentScreen == Screen.Editor) saveCurrentProject()
                exitApplication()
            },
            title = "Slides",
            state = rememberWindowState(width = 1200.dp, height = 800.dp),
        ) {
            // Extend content into title bar area
            window.rootPane.putClientProperty("apple.awt.fullWindowContent", true)
            window.rootPane.putClientProperty("apple.awt.transparentTitleBar", true)
            val openLauncher = rememberFilePickerLauncher(
                type = FileKitType.File(extensions = listOf("slides")),
            ) { file ->
                file?.path?.let { path ->
                    try {
                        val project = projectStore.loadProject(path)
                        // Register in index so it shows in picker
                        projectStore.addOrUpdate(
                            ProjectEntry(
                                id = project.id,
                                name = project.name,
                                filePath = path,
                                lastModified = System.currentTimeMillis(),
                            )
                        )
                        viewModel.loadProject(project, path)
                        currentScreen = Screen.Editor
                        refreshProjects()
                    } catch (e: Exception) {
                        println("Failed to open: ${e.message}")
                    }
                }
            }

            val saveLauncher = rememberFileSaverLauncher { file ->
                file?.path?.let { path ->
                    projectStore.saveProject(viewModel.state.value.project, path)
                    viewModel.setProjectFilePath(path)
                    refreshProjects()
                }
            }

            if (currentScreen == Screen.Editor) {
                MenuBar {
                    Menu("File") {
                        Item("Back to Projects") {
                            saveCurrentProject()
                            currentScreen = Screen.ProjectPicker
                            refreshProjects()
                        }
                        Separator()
                        Item("Save", shortcut = KeyShortcut(Key.S, meta = true)) {
                            val state = viewModel.state.value
                            val path = state.projectFilePath
                            if (path != null) {
                                projectStore.saveProject(state.project, path)
                                refreshProjects()
                            } else {
                                saveLauncher.launch("project", "slides")
                            }
                        }
                        Item("Save As...", shortcut = KeyShortcut(Key.S, meta = true, shift = true)) {
                            saveLauncher.launch("project", "slides")
                        }
                        Separator()
                        Item("Open...", shortcut = KeyShortcut(Key.O, meta = true)) {
                            openLauncher.launch()
                        }
                    }
                }
            }

            App(
                viewModel = viewModel,
                projects = projects,
                firstSlides = firstSlides,
                onCreateProject = {
                    val (entry, project) = projectStore.createProject()
                    viewModel.loadProject(project, entry.filePath)
                    currentScreen = Screen.Editor
                    refreshProjects()
                },
                onOpenProject = ::openProject,
                onDeleteProject = { entry ->
                    projectStore.remove(entry.id)
                    refreshProjects()
                },
                currentScreen = currentScreen,
                onBackToProjects = {
                    saveCurrentProject()
                    currentScreen = Screen.ProjectPicker
                    refreshProjects()
                },
            )
        }
    }
}
