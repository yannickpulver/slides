package com.yannickpulver.slides.model

import kotlinx.serialization.Serializable

/** Film-edge overlay masks bundled in composeResources/files/film-edges/{full,preview}. */
@Serializable
enum class FilmEdge {
    WHITE_THIN_1,
    WHITE_THIN_2,
    WHITE_THIN_3,
    DOUBLE_1,
    DOUBLE_2,
    DOUBLE_3,
    DOUBLE_INV_1,
    DOUBLE_INV_2,
    DOUBLE_INV_3,
    WHITE_SOFT,
    BLACK_SOFT_1,
    BLACK_SOFT_2,
    BLACK_SOFT_3,
    ;

    fun resourcePath(landscape: Boolean, preview: Boolean): String {
        val size = if (preview) "preview" else "full"
        val orientation = if (landscape) "landscape" else "portrait"
        return "files/film-edges/$size/${name.lowercase()}_$orientation.png"
    }
}
