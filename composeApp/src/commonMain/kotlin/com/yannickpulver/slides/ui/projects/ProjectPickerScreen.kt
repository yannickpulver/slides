package com.yannickpulver.slides.ui.projects

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yannickpulver.slides.APP_VERSION
import com.yannickpulver.slides.model.AspectRatio
import com.yannickpulver.slides.model.ProjectEntry
import com.yannickpulver.slides.model.ProjectMeta
import com.yannickpulver.slides.ui.editor.SlidePreview
import compose.icons.TablerIcons
import compose.icons.tablericons.ChevronDown
import compose.icons.tablericons.Plus
import compose.icons.tablericons.Search
import compose.icons.tablericons.Trash
import compose.icons.tablericons.X
import java.util.Calendar

private enum class SortMode(val label: String) {
    Recent("Recent"),
    Name("Name"),
    Oldest("Oldest"),
}

private val DEFAULT_PREVIEW_RATIO = AspectRatio.PORTRAIT_4_3.let { it.width.toFloat() / it.height.toFloat() }

@Composable
fun ProjectPickerScreen(
    projects: List<ProjectEntry>,
    projectMetas: Map<String, ProjectMeta?>,
    onCreateProject: () -> Unit,
    onOpenProject: (ProjectEntry) -> Unit,
    onDeleteProject: (ProjectEntry) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var sort by remember { mutableStateOf(SortMode.Recent) }

    val filtered = remember(projects, query, sort) {
        val q = query.trim().lowercase()
        val base = if (q.isEmpty()) projects else projects.filter { it.name.lowercase().contains(q) }
        when (sort) {
            SortMode.Recent -> base.sortedByDescending { it.lastModified }
            SortMode.Oldest -> base.sortedBy { it.lastModified }
            SortMode.Name -> base.sortedBy { it.name.lowercase() }
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        OverviewHeader(
            count = projects.size,
            query = query,
            onQueryChange = { query = it },
            sort = sort,
            onSortChange = { sort = it },
            onNew = onCreateProject,
        )

        LazyVerticalGrid(
            columns = GridCells.Adaptive(196.dp),
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(start = 32.dp, end = 32.dp, top = 24.dp, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item {
                NewProjectCard(onClick = onCreateProject)
            }
            items(filtered, key = { it.id }) { entry ->
                ProjectCard(
                    entry = entry,
                    meta = projectMetas[entry.id],
                    onClick = { onOpenProject(entry) },
                    onDelete = { onDeleteProject(entry) },
                )
            }
        }

        OverviewFooter(projectCount = projects.size)
    }
}

@Composable
private fun OverviewHeader(
    count: Int,
    query: String,
    onQueryChange: (String) -> Unit,
    sort: SortMode,
    onSortChange: (SortMode) -> Unit,
    onNew: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 32.dp, end = 32.dp, top = 28.dp, bottom = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                "Slides",
                fontSize = 28.sp,
                fontWeight = FontWeight.Normal,
                fontStyle = FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                "${count} ${if (count == 1) "project" else "projects"}".uppercase(),
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                modifier = Modifier.padding(bottom = 6.dp),
            )
        }

        Spacer(Modifier.weight(1f))

        SearchField(query = query, onQueryChange = onQueryChange)
        SortDropdown(sort = sort, onSortChange = onSortChange)

        Box(
            modifier = Modifier
                .width(0.5.dp)
                .height(20.dp)
                .background(MaterialTheme.colorScheme.outline),
        )

        NewButton(onClick = onNew)
    }
}

@Composable
private fun SearchField(query: String, onQueryChange: (String) -> Unit) {
    Row(
        modifier = Modifier
            .height(28.dp)
            .width(220.dp)
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(6.dp))
            .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(6.dp))
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            TablerIcons.Search,
            contentDescription = null,
            modifier = Modifier.size(12.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
        )
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodySmall.copy(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 12.sp,
                ),
                cursorBrush = SolidColor(MaterialTheme.colorScheme.onSurface),
                modifier = Modifier.fillMaxWidth(),
            )
            if (query.isEmpty()) {
                Text(
                    "Search projects",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }
        }
        if (query.isNotEmpty()) {
            Icon(
                TablerIcons.X,
                contentDescription = "Clear",
                modifier = Modifier
                    .size(10.dp)
                    .pointerHoverIcon(PointerIcon.Hand)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { onQueryChange("") },
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
        }
    }
}

@Composable
private fun SortDropdown(sort: SortMode, onSortChange: (SortMode) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .height(28.dp)
                .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(6.dp))
                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(6.dp))
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { open = true }
                .padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                "SORT",
                fontSize = 9.sp,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
            Text(
                sort.label,
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Icon(
                TablerIcons.ChevronDown,
                contentDescription = null,
                modifier = Modifier.size(10.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
        ) {
            SortMode.entries.forEach { option ->
                DropdownMenuItem(
                    text = {
                        Text(
                            option.label,
                            fontSize = 12.sp,
                            color = if (option == sort) MaterialTheme.colorScheme.onSurface
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    },
                    onClick = { onSortChange(option); open = false },
                )
            }
        }
    }
}

@Composable
private fun NewButton(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .height(28.dp)
            .background(MaterialTheme.colorScheme.onSurface, RoundedCornerShape(6.dp))
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            TablerIcons.Plus,
            contentDescription = null,
            modifier = Modifier.size(12.dp),
            tint = MaterialTheme.colorScheme.background,
        )
        Text(
            "New",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.background,
        )
    }
}

@Composable
private fun OverviewFooter(projectCount: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(28.dp)
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Spacer(Modifier.weight(1f))
        Text(
            "$projectCount ${if (projectCount == 1) "project" else "projects"}",
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        )
        Text(
            "·",
            fontSize = 10.sp,
            color = MaterialTheme.colorScheme.outline,
        )
        Text(
            "v$APP_VERSION",
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        )
    }
}

@Composable
private fun NewProjectCard(onClick: () -> Unit) {
    var hovered by remember { mutableStateOf(false) }
    val borderColor = if (hovered) MaterialTheme.colorScheme.onSurfaceVariant
    else MaterialTheme.colorScheme.outline

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .pointerHoverIcon(PointerIcon.Hand)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val e = awaitPointerEvent()
                        when (e.type) {
                            PointerEventType.Enter -> hovered = true
                            PointerEventType.Exit -> hovered = false
                        }
                    }
                }
            }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(DEFAULT_PREVIEW_RATIO)
                .clip(RoundedCornerShape(4.dp))
                .border(1.dp, borderColor, RoundedCornerShape(4.dp))
                .background(
                    if (hovered) Color.White.copy(alpha = 0.02f) else Color.Transparent,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(
                    TablerIcons.Plus,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = if (hovered) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "NEW PROJECT",
                    fontSize = 10.sp,
                    fontFamily = FontFamily.Monospace,
                    color = if (hovered) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Text(
            "Start from blank",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 2.dp),
        )
    }
}

@Composable
private fun ProjectCard(
    entry: ProjectEntry,
    meta: ProjectMeta?,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    var hovered by remember { mutableStateOf(false) }
    val aspectRatio = meta?.aspectRatio ?: AspectRatio.PORTRAIT_4_3

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .pointerHoverIcon(PointerIcon.Hand)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val e = awaitPointerEvent()
                        when (e.type) {
                            PointerEventType.Enter -> hovered = true
                            PointerEventType.Exit -> hovered = false
                        }
                    }
                }
            }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        val ratio = aspectRatio.width.toFloat() / aspectRatio.height.toFloat()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(ratio)
                .clip(RoundedCornerShape(4.dp))
                .border(
                    0.5.dp,
                    if (hovered) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    RoundedCornerShape(4.dp),
                )
                .background(
                    if (meta?.firstSlide != null && meta.firstSlide.elements.isNotEmpty()) Color.White
                    else MaterialTheme.colorScheme.surfaceContainer
                )
                .clipToBounds(),
            contentAlignment = Alignment.Center,
        ) {
            val firstSlide = meta?.firstSlide
            if (firstSlide != null && firstSlide.elements.isNotEmpty()) {
                SlidePreview(
                    slide = firstSlide,
                    aspectRatio = aspectRatio,
                    fillFraction = 1f,
                )
            } else {
                Text(
                    "Empty",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }

            if (hovered) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp),
                ) {
                    CardAction(icon = TablerIcons.Trash, contentDescription = "Delete", onClick = onDelete)
                }
            }
        }

        Column(modifier = Modifier.padding(horizontal = 2.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                entry.name,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                metaLine(entry.lastModified, meta),
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun CardAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(RoundedCornerShape(5.dp))
            .background(Color(0xD90F0F11))
            .border(0.5.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(5.dp))
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = contentDescription,
            modifier = Modifier.size(11.dp),
            tint = Color.White.copy(alpha = 0.85f),
        )
    }
}

private fun metaLine(lastModified: Long, meta: ProjectMeta?): String {
    val time = relTime(lastModified)
    return if (meta != null) "$time  ·  ${meta.slideCount}  ·  ${meta.aspectRatio.label}" else time
}

private fun relTime(ts: Long): String {
    val diffMs = System.currentTimeMillis() - ts
    val diffMin = diffMs / 60_000L
    if (diffMin < 1) return "just now"
    if (diffMin < 60) return "${diffMin}m ago"
    val diffHour = diffMin / 60L
    if (diffHour < 24) return "${diffHour}h ago"
    val diffDay = diffHour / 24L
    val now = Calendar.getInstance()
    val then = Calendar.getInstance().apply { timeInMillis = ts }
    if (now.get(Calendar.YEAR) == then.get(Calendar.YEAR) &&
        now.get(Calendar.DAY_OF_YEAR) - then.get(Calendar.DAY_OF_YEAR) == 1
    ) return "yesterday"
    if (diffDay < 7) return "${diffDay}d ago"
    if (diffDay < 30) return "${diffDay / 7L}w ago"
    return "${diffDay / 30L}mo ago"
}
