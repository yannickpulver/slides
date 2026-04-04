package com.yannickpulver.slides.template

import com.yannickpulver.slides.model.ElementBounds
import com.yannickpulver.slides.model.SlideTemplate

fun boundsForTemplate(template: SlideTemplate): List<ElementBounds> = when (template) {
    SlideTemplate.SINGLE -> listOf(
        ElementBounds(0f, 0f, 1f, 1f)
    )
    SlideTemplate.TWO_VERTICAL -> listOf(
        ElementBounds(0f, 0f, 1f, 0.5f),
        ElementBounds(0f, 0.5f, 1f, 0.5f),
    )
    SlideTemplate.THREE_VERTICAL -> listOf(
        ElementBounds(0f, 0f, 1f, 1f / 3f),
        ElementBounds(0f, 1f / 3f, 1f, 1f / 3f),
        ElementBounds(0f, 2f / 3f, 1f, 1f / 3f),
    )
}
