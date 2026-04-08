package com.yannickpulver.slides

class JVMPlatform: Platform {
    override val name: String = "Java ${System.getProperty("java.version")}"
}

actual fun getPlatform(): Platform = JVMPlatform()

actual fun openInFinder(path: String) {
    java.awt.Desktop.getDesktop().open(java.io.File(path))
}