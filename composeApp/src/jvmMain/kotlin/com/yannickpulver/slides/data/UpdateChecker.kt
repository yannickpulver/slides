package com.yannickpulver.slides.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URI

@Serializable
data class GitHubRelease(
    val tag_name: String,
    val html_url: String,
)

object UpdateChecker {
    private const val REPO = "yannickpulver/slides"
    private val json = Json { ignoreUnknownKeys = true }

    fun currentVersion(): String =
        UpdateChecker::class.java.getResourceAsStream("/version.txt")
            ?.bufferedReader()?.readText()?.trim() ?: "0.0.0"

    suspend fun checkForUpdate(): UpdateInfo? = withContext(Dispatchers.IO) {
        try {
            val url = URI("https://api.github.com/repos/$REPO/releases/latest").toURL()
            val conn = url.openConnection() as HttpURLConnection
            conn.setRequestProperty("Accept", "application/vnd.github.v3+json")
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            val body = conn.inputStream.bufferedReader().readText()
            conn.disconnect()

            val release = json.decodeFromString<GitHubRelease>(body)
            val latest = release.tag_name.removePrefix("v")
            val current = currentVersion()

            if (isNewer(latest, current)) {
                UpdateInfo(latestVersion = latest, downloadUrl = release.html_url)
            } else null
        } catch (_: Exception) {
            null
        }
    }

    private fun isNewer(latest: String, current: String): Boolean {
        val l = latest.split(".").map { it.toIntOrNull() ?: 0 }
        val c = current.split(".").map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(l.size, c.size)) {
            val lv = l.getOrElse(i) { 0 }
            val cv = c.getOrElse(i) { 0 }
            if (lv > cv) return true
            if (lv < cv) return false
        }
        return false
    }
}

data class UpdateInfo(val latestVersion: String, val downloadUrl: String)
