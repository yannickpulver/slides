package com.yannickpulver.slides

import androidx.compose.runtime.remember
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyShortcut
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.MenuBar
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.yannickpulver.slides.model.Project
import com.yannickpulver.slides.ui.editor.EditorViewModel
import io.github.vinceglb.filekit.FileKit
import io.github.vinceglb.filekit.dialogs.FileKitType
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.dialogs.compose.rememberFileSaverLauncher
import io.github.vinceglb.filekit.path
import kotlinx.serialization.json.Json
import java.io.File

private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }

fun main() {
    FileKit.init(appId = "com.yannickpulver.slides")
    application {
        val viewModel = remember { EditorViewModel() }

        Window(
            onCloseRequest = ::exitApplication,
            title = "Slides",
            state = rememberWindowState(width = 1200.dp, height = 800.dp),
        ) {
            val openLauncher = rememberFilePickerLauncher(
                type = FileKitType.File(extensions = listOf("slides")),
            ) { file ->
                file?.path?.let { path ->
                    try {
                        val project = json.decodeFromString<Project>(File(path).readText())
                        viewModel.loadProject(project, path)
                    } catch (e: Exception) {
                        println("Failed to open: ${e.message}")
                    }
                }
            }

            val saveLauncher = rememberFileSaverLauncher { file ->
                file?.path?.let { path ->
                    saveProjectToFile(viewModel.state.value.project, path)
                    viewModel.setProjectFilePath(path)
                }
            }

            MenuBar {
                Menu("File") {
                    Item("New Project", shortcut = KeyShortcut(Key.N, meta = true)) {
                        viewModel.newProject()
                    }
                    Item("Open...", shortcut = KeyShortcut(Key.O, meta = true)) {
                        openLauncher.launch()
                    }
                    Item("Save", shortcut = KeyShortcut(Key.S, meta = true)) {
                        val state = viewModel.state.value
                        val path = state.projectFilePath
                        if (path != null) {
                            saveProjectToFile(state.project, path)
                        } else {
                            saveLauncher.launch("project", "slides")
                        }
                    }
                    Item("Save As...", shortcut = KeyShortcut(Key.S, meta = true, shift = true)) {
                        saveLauncher.launch("project", "slides")
                    }
                }
            }
            App(viewModel)
        }
    }
}

private fun saveProjectToFile(project: Project, path: String) {
    try {
        File(path).writeText(json.encodeToString(Project.serializer(), project))
        println("Saved: $path")
    } catch (e: Exception) {
        println("Failed to save: ${e.message}")
    }
}
