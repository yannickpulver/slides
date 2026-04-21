package com.yannickpulver.slides.ui.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yannickpulver.slides.model.MediaElement
import com.yannickpulver.slides.model.MediaFitMode
import com.yannickpulver.slides.model.Slide
import com.yannickpulver.slides.model.SlideTemplate
import com.yannickpulver.slides.model.TextAlignment
import com.yannickpulver.slides.model.TextOverlay
import com.yannickpulver.slides.model.isSpanTemplate
import com.yannickpulver.slides.model.spanSize
import compose.icons.TablerIcons
import compose.icons.tablericons.Download
import compose.icons.tablericons.Trash
import kotlin.math.roundToInt

private const val MAX_FRAME_BORDER_PX = 240f
private const val MAX_GAP_PX = 120f

private val TightLineHeight = LineHeightStyle(
    alignment = LineHeightStyle.Alignment.Center,
    trim = LineHeightStyle.Trim.Both,
)

private val SWATCHES = listOf(
    0xFFFFFFFFL to "white",
    0xFF000000L to "black",
    0xFFF4EFE7L to "cream",
    0xFFE8755FL to "coral",
    0xFF2E4A3AL to "forest",
)

private val STACK_TEMPLATES = listOf(
    SlideTemplate.SINGLE,
    SlideTemplate.TWO_VERTICAL,
    SlideTemplate.THREE_VERTICAL,
)

private val PANORAMA_TEMPLATES = listOf(
    SlideTemplate.SPAN_2,
    SlideTemplate.SPAN_3,
    SlideTemplate.SPAN_4,
)

@Composable
fun EditorSidebar(
    slide: Slide?,
    slideIndex: Int,
    canDeleteSlide: Boolean,
    selectedElement: MediaElement?,
    selectedTextOverlay: TextOverlay?,
    onTemplateSelected: (SlideTemplate) -> Unit,
    onBackgroundColor: (Long) -> Unit,
    onGapChanged: (Float) -> Unit,
    onFitMode: (MediaFitMode) -> Unit,
    onBorderChanged: (Float) -> Unit,
    onAddText: () -> Unit,
    onTextStyle: (fontFamily: String?, fontSize: Float?, color: Long?, alignment: TextAlignment?) -> Unit,
    onTextDelete: () -> Unit,
    onDeleteSlide: () -> Unit,
    onExport: (scale: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .width(240.dp)
            .fillMaxHeight()
            .background(MaterialTheme.colorScheme.background)
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        if (slide != null) {
            SidebarHeader(
                slide = slide,
                slideIndex = slideIndex,
                canDelete = canDeleteSlide,
                onDelete = onDeleteSlide,
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
        ) {
            if (slide != null) {
                LayoutSection(slide = slide, onTemplateSelected = onTemplateSelected)
                CanvasSection(
                    slide = slide,
                    onBackgroundColor = onBackgroundColor,
                    onGapChanged = onGapChanged,
                )
                if (selectedElement != null) {
                    ElementSection(
                        element = selectedElement,
                        onFitMode = onFitMode,
                        onBorderChanged = onBorderChanged,
                    )
                }
                TextSection(
                    overlay = selectedTextOverlay,
                    onStyle = onTextStyle,
                    onDelete = onTextDelete,
                    onAddText = onAddText,
                )
            }
        }
        ExportSection(slideCount = (slide?.let { 1 } ?: 0), onExport = onExport)
    }
}

@Composable
private fun SidebarHeader(
    slide: Slide,
    slideIndex: Int,
    canDelete: Boolean,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            "Slide ${slideIndex + 1}",
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.weight(1f))
        val meta = if (slide.template.isSpanTemplate) {
            "pan ${slide.spanIndex + 1}/${slide.spanCount}"
        } else {
            "${slide.elements.size}/${slide.template.slotCount} images"
        }
        Text(
            meta,
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
        )
        if (canDelete) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainer)
                    .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp))
                    .pointerHoverIcon(PointerIcon.Hand)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { onDelete() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    TablerIcons.Trash,
                    contentDescription = "Delete slide",
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SectionFrame(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            title.uppercase(),
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            modifier = Modifier.padding(bottom = 10.dp),
        )
        content()
    }
}

@Composable
private fun LayoutSection(slide: Slide, onTemplateSelected: (SlideTemplate) -> Unit) {
    SectionFrame(title = "Layout") {
        Text(
            "Stack — images on this slide",
            fontSize = 10.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            modifier = Modifier.padding(bottom = 4.dp),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
            STACK_TEMPLATES.forEach { tmpl ->
                LayoutTile(
                    template = tmpl,
                    active = !slide.template.isSpanTemplate && slide.template == tmpl,
                    modifier = Modifier.weight(1f),
                    onClick = { onTemplateSelected(tmpl) },
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        Text(
            "Panorama — across N slides",
            fontSize = 10.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            modifier = Modifier.padding(bottom = 4.dp),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
            PANORAMA_TEMPLATES.forEach { tmpl ->
                LayoutTile(
                    template = tmpl,
                    active = slide.template == tmpl,
                    modifier = Modifier.weight(1f),
                    onClick = { onTemplateSelected(tmpl) },
                )
            }
        }
    }
}

@Composable
private fun LayoutTile(
    template: SlideTemplate,
    active: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val isPano = template.isSpanTemplate
    Box(
        modifier = modifier
            .height(if (isPano) 28.dp else 44.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(
                if (active) MaterialTheme.colorScheme.surfaceContainerHigh
                else MaterialTheme.colorScheme.surfaceContainer,
            )
            .border(
                0.5.dp,
                if (active) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.outline,
                RoundedCornerShape(4.dp),
            )
            .pointerHoverIcon(PointerIcon.Hand)
            .clickable(
                interactionSource = remember(template) { MutableInteractionSource() },
                indication = null,
            ) { onClick() }
            .padding(4.dp),
        contentAlignment = Alignment.Center,
    ) {
        TemplateIcon(
            template = template,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

@Composable
private fun CanvasSection(
    slide: Slide,
    onBackgroundColor: (Long) -> Unit,
    onGapChanged: (Float) -> Unit,
) {
    SectionFrame(title = "Canvas") {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Background", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                SWATCHES.forEach { (argb, _) ->
                    val selected = slide.backgroundColorArgb == argb
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(Color(argb.toInt()))
                            .border(
                                if (selected) 1.5.dp else 0.5.dp,
                                if (selected) Color.White else Color.White.copy(alpha = 0.2f),
                                CircleShape,
                            )
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember(argb) { MutableInteractionSource() },
                                indication = null,
                            ) { onBackgroundColor(argb) },
                    )
                }
            }
        }
        if (slide.template.slotCount > 1) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Gap", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                PxField(
                    value = slide.gapPx.roundToInt().toString(),
                    onChange = { v -> onGapChanged(v.coerceIn(0f, MAX_GAP_PX)) },
                )
            }
        }
    }
}

@Composable
private fun ElementSection(
    element: MediaElement,
    onFitMode: (MediaFitMode) -> Unit,
    onBorderChanged: (Float) -> Unit,
) {
    SectionFrame(title = "Image") {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Fit", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Segmented(
                options = listOf("Fill" to MediaFitMode.FILL, "Full" to MediaFitMode.FIT),
                selected = element.fitMode,
                onSelect = onFitMode,
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Border", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            PxField(
                value = element.frameBorderPx.roundToInt().toString(),
                onChange = { v -> onBorderChanged(v.coerceIn(0f, MAX_FRAME_BORDER_PX)) },
            )
        }
    }
}

@Composable
private fun TextSection(
    overlay: TextOverlay?,
    onStyle: (fontFamily: String?, fontSize: Float?, color: Long?, alignment: TextAlignment?) -> Unit,
    onDelete: () -> Unit,
    onAddText: () -> Unit,
) {
    SectionFrame(title = "Text") {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(MaterialTheme.colorScheme.surfaceContainer)
                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(5.dp))
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onAddText() },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "+ Add text",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (overlay == null) return@SectionFrame

        Spacer(Modifier.height(10.dp))

        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Size", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            PxField(
                value = overlay.fontSizePx.roundToInt().toString(),
                onChange = { v -> onStyle(null, v.coerceIn(8f, 200f), null, null) },
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Align", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Segmented(
                options = listOf(
                    "L" to TextAlignment.LEFT,
                    "C" to TextAlignment.CENTER,
                    "R" to TextAlignment.RIGHT,
                ),
                selected = overlay.alignment,
                onSelect = { onStyle(null, null, null, it) },
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Font", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            FontPickerField(
                current = overlay.fontFamily,
                onSelect = { name -> onStyle(name, null, null, null) },
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Color", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                listOf(0xFFFFFFFFL, 0xFF000000L, 0xFFE8755FL).forEach { c ->
                    val selected = overlay.colorArgb == c
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(Color(c.toInt()))
                            .border(
                                if (selected) 1.5.dp else 0.5.dp,
                                if (selected) Color.White else Color.White.copy(alpha = 0.2f),
                                CircleShape,
                            )
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember(c) { MutableInteractionSource() },
                                indication = null,
                            ) { onStyle(null, null, c, null) },
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(MaterialTheme.colorScheme.surfaceContainer)
                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(5.dp))
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onDelete() },
            contentAlignment = Alignment.Center,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(
                    TablerIcons.Trash,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text("Remove", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun ExportSection(slideCount: Int, onExport: (Int) -> Unit) {
    var scale by remember { mutableStateOf(2) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            "EXPORT",
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            modifier = Modifier.padding(bottom = 10.dp),
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Scale", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(
                modifier = Modifier
                    .height(22.dp)
                    .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(4.dp))
                    .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp))
                    .padding(2.dp),
            ) {
                listOf(1, 2, 3).forEach { s ->
                    val sel = scale == s
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(3.dp))
                            .then(
                                if (sel) Modifier.background(MaterialTheme.colorScheme.onSurface) else Modifier,
                            )
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable(
                                interactionSource = remember(s) { MutableInteractionSource() },
                                indication = null,
                            ) { scale = s }
                            .padding(horizontal = 7.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "${s}x",
                            style = androidx.compose.ui.text.TextStyle(
                                fontSize = 10.sp,
                                lineHeight = 10.sp,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Medium,
                                lineHeightStyle = TightLineHeight,
                                color = if (sel) MaterialTheme.colorScheme.background else MaterialTheme.colorScheme.onSurfaceVariant,
                            ),
                        )
                    }
                }
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(30.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(MaterialTheme.colorScheme.onSurface)
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onExport(scale) },
            contentAlignment = Alignment.Center,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(
                    TablerIcons.Download,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.background,
                )
                Text(
                    "Export",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.background,
                )
            }
        }
    }
}

@Composable
private fun <T> Segmented(
    options: List<Pair<String, T>>,
    selected: T,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = Modifier
            .height(22.dp)
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(4.dp))
            .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp))
            .padding(2.dp),
    ) {
        options.forEach { (label, value) ->
            val sel = selected == value
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(3.dp))
                    .then(
                        if (sel) Modifier.background(MaterialTheme.colorScheme.onSurface) else Modifier,
                    )
                    .pointerHoverIcon(PointerIcon.Hand)
                    .clickable(
                        interactionSource = remember(label) { MutableInteractionSource() },
                        indication = null,
                    ) { onSelect(value) }
                    .padding(horizontal = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    style = androidx.compose.ui.text.TextStyle(
                        fontSize = 10.sp,
                        lineHeight = 10.sp,
                        fontWeight = FontWeight.Medium,
                        lineHeightStyle = TightLineHeight,
                        color = if (sel) MaterialTheme.colorScheme.background else MaterialTheme.colorScheme.onSurfaceVariant,
                    ),
                )
            }
        }
    }
}

@Composable
private fun PxField(value: String, onChange: (Float) -> Unit) {
    var local by remember(value) { mutableStateOf(value) }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        BasicTextField(
            value = local,
            onValueChange = { v ->
                val filtered = v.filter { it.isDigit() }.take(4)
                local = filtered
                if (filtered.isNotEmpty()) {
                    filtered.toFloatOrNull()?.let { onChange(it) }
                }
            },
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
            cursorBrush = SolidColor(MaterialTheme.colorScheme.onSurface),
            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.width(44.dp).height(22.dp),
            decorationBox = { inner ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainer)
                        .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp),
                    contentAlignment = Alignment.Center,
                ) { inner() }
            },
        )
        Text(
            "px",
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
        )
    }
}

@Composable
private fun FontPickerField(
    current: String,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }
    var fontNames by remember { mutableStateOf(getAvailableFontFamiliesOrNull()) }
    androidx.compose.runtime.LaunchedEffect(expanded) {
        if (expanded && fontNames == null) {
            while (getAvailableFontFamiliesOrNull() == null) {
                kotlinx.coroutines.delay(100)
            }
            fontNames = getAvailableFontFamiliesOrNull()
        }
    }

    Box {
        Box(
            modifier = Modifier
                .defaultMinSize(minWidth = 110.dp)
                .height(22.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(4.dp))
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { expanded = true }
                .padding(horizontal = 6.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            Text(
                current.ifEmpty { "Default" },
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )
        }
        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false; search = "" },
            modifier = Modifier.width(240.dp).background(MaterialTheme.colorScheme.surfaceContainer),
        ) {
            val searchFocus = remember { androidx.compose.ui.focus.FocusRequester() }
            BasicTextField(
                value = search,
                onValueChange = { search = it },
                singleLine = true,
                textStyle = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurface),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 6.dp)
                    .focusRequester(searchFocus),
                decorationBox = { inner ->
                    Box {
                        if (search.isEmpty()) {
                            Text(
                                "Search fonts…",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        inner()
                    }
                },
            )
            androidx.compose.runtime.LaunchedEffect(expanded) { if (expanded) searchFocus.requestFocus() }
            Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)))

            val names = fontNames
            if (names == null) {
                Box(Modifier.fillMaxWidth().height(60.dp), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                }
            } else {
                val filtered = if (search.isBlank()) names else names.filter { it.contains(search, ignoreCase = true) }
                Box(modifier = Modifier.height(280.dp)) {
                    val scrollState = rememberScrollState()
                    Column(modifier = Modifier.fillMaxWidth().verticalScroll(scrollState)) {
                        if (search.isBlank()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(28.dp)
                                    .clickable { onSelect(""); expanded = false; search = "" }
                                    .padding(horizontal = 12.dp),
                                contentAlignment = Alignment.CenterStart,
                            ) {
                                Text("Default", style = MaterialTheme.typography.bodySmall)
                            }
                        }
                        filtered.forEach { name ->
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(28.dp)
                                    .clickable { onSelect(name); expanded = false; search = "" }
                                    .padding(horizontal = 12.dp),
                                contentAlignment = Alignment.CenterStart,
                            ) {
                                Text(
                                    name,
                                    style = MaterialTheme.typography.bodySmall,
                                    fontFamily = fontFamilyFromName(name),
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
