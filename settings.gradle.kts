rootProject.name = "ktor-cio-empty-reply-repro"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
    // gradle.properties holds the versions last measured; `-PkotlinVersion=…` rechecks on another compiler.
    val kotlinVersion: String by settings
    plugins { kotlin("multiplatform") version kotlinVersion }
}

dependencyResolutionManagement { repositories { mavenCentral() } }
