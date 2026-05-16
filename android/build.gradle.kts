import org.gradle.api.tasks.compile.JavaCompile
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

subprojects {
    if (path == ":isar_flutter_libs") {
        afterEvaluate {
            pluginManager.withPlugin("com.android.library") {
                val android = extensions.findByName("android")
                if (android != null) {
                    val ext = android as com.android.build.gradle.BaseExtension
                    ext.namespace = "dev.isar.isar_flutter_libs"
                    ext.compileSdkVersion(34)
                }
            }
        }
    }
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}
