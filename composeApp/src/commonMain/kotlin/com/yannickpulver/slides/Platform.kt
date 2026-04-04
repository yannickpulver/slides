package com.yannickpulver.slides

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform