// --- BAGIAN INI WAJIB DITAMBAHKAN UNTUK FIREBASE ---
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Classpath Google Services (Jembatan agar Firebase dikenali)
        classpath("com.google.gms:google-services:4.4.1")
    }
}
// ----------------------------------------------------

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}