// Root-level build.gradle (Kotlin DSL) — aligned with Settings plugins (AGP 8.5.0, Kotlin 1.9.24)
// No buildscript/classpath block needed because plugins and versions are declared via settings.gradle
// and applied in module build files.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Consolidate build outputs under the repo root's /build folder (outside /android)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Ensure the :app module evaluates first where needed
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}