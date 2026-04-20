package com.yannickpulver.slides.data

import com.yannickpulver.slides.model.Project
import com.yannickpulver.slides.model.ProjectEntry
import com.yannickpulver.slides.model.ProjectMeta
import com.yannickpulver.slides.model.Slide
import kotlinx.serialization.json.Json
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ProjectStore {

    private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }
    private val baseDir = File(System.getProperty("user.home"), ".slides").also { it.mkdirs() }
    private val projectsDir = File(baseDir, "projects").also { it.mkdirs() }
    private val indexFile = File(baseDir, "projects.json")

    fun listProjects(): List<ProjectEntry> {
        if (!indexFile.exists()) return emptyList()
        return try {
            json.decodeFromString<List<ProjectEntry>>(indexFile.readText())
                .sortedByDescending { it.lastModified }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun createProject(): Pair<ProjectEntry, Project> {
        val dateFormat = SimpleDateFormat("dd.MM.yyyy", Locale.getDefault())
        val name = "Project ${dateFormat.format(Date())}"
        val project = Project(name = name)
        val file = File(projectsDir, "${project.id}.slides")
        file.writeText(json.encodeToString(Project.serializer(), project))
        val entry = ProjectEntry(
            id = project.id,
            name = name,
            filePath = file.absolutePath,
            lastModified = System.currentTimeMillis(),
        )
        addOrUpdate(entry)
        return entry to project
    }

    fun addOrUpdate(entry: ProjectEntry) {
        val entries = listProjects().toMutableList()
        val idx = entries.indexOfFirst { it.id == entry.id }
        if (idx >= 0) entries[idx] = entry else entries.add(entry)
        saveIndex(entries)
    }

    fun remove(id: String) {
        val entries = listProjects().filter { it.id != id }
        saveIndex(entries)
    }

    fun saveProject(project: Project, filePath: String) {
        File(filePath).writeText(json.encodeToString(Project.serializer(), project))
        addOrUpdate(
            ProjectEntry(
                id = project.id,
                name = project.name,
                filePath = filePath,
                lastModified = System.currentTimeMillis(),
            )
        )
    }

    fun loadProject(filePath: String): Project {
        return json.decodeFromString<Project>(File(filePath).readText())
    }

    fun loadFirstSlide(filePath: String): Slide? {
        return try {
            loadProject(filePath).slides.firstOrNull()
        } catch (e: Exception) {
            null
        }
    }

    fun loadProjectMeta(filePath: String): ProjectMeta? {
        return try {
            val p = loadProject(filePath)
            ProjectMeta(
                firstSlide = p.slides.firstOrNull(),
                aspectRatio = p.aspectRatio,
                slideCount = p.slides.size,
                hasPanorama = p.slides.any { it.spanGroupId != null },
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun saveIndex(entries: List<ProjectEntry>) {
        indexFile.writeText(json.encodeToString(entries))
    }
}
