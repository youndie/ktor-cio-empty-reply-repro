import org.jetbrains.kotlin.gradle.plugin.getKotlinPluginVersion

plugins { kotlin("multiplatform") }

val ktorVersion: String by project

kotlin {
    // The same server on the JVM is the control: it has never lost an answer under this load.
    jvm { mainRun { mainClass = "MainKt" } }
    linuxX64 { binaries.executable { entryPoint = "main" } }
    sourceSets.commonMain.dependencies {
        implementation("io.ktor:ktor-server-core:$ktorVersion")
        implementation("io.ktor:ktor-server-cio:$ktorVersion")
    }
}

// The JVM server runs from its compiled classes and this classpath, because a multiplatform build cannot apply the
// `application` plugin. run.sh reads the resolved Ktor version off the jar names and the compiler's from
// kotlinVersion.txt, so a run reports what it ran rather than what was asked for.
tasks.register("writeJvmRuntimeClasspath") {
    val classpath = configurations.named("jvmRuntimeClasspath")
    val out = layout.buildDirectory.file("jvmRuntimeClasspath.txt")
    val compiler = layout.buildDirectory.file("kotlinVersion.txt")
    val kotlinPluginVersion = getKotlinPluginVersion()
    inputs.files(classpath)
    inputs.property("kotlinPluginVersion", kotlinPluginVersion)
    outputs.files(out, compiler)
    doLast {
        out.get().asFile.writeText(classpath.get().files.joinToString(":"))
        compiler.get().asFile.writeText(kotlinPluginVersion)
    }
}
