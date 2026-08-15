import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.jsonObject

allprojects {
    repositories {
        google()
        mavenCentral()
        rustlsPlatformVerifier()
    }
}

fun RepositoryHandler.rustlsPlatformVerifier() : MavenArtifactRepository {
    @Suppress("UnstableApiUsage")
    val manifestPath = let {
        val dependencyJson = providers.exec {
            workingDir = File(project.rootDir, "../")
            commandLine("cargo", "metadata", "--format-version=1", "--manifest-path", "rust/Cargo.toml")
        }.standardOutput.asText.get().trim()

        val path = Json.decodeFromString<JsonObject>(dependencyJson)
            .getValue("packages")
            .jsonArray
            .first { element ->
                element.jsonObject.getValue("name").jsonPrimitive.content == "rustls-platform-verifier-android"
            }.jsonObject.getValue("manifest_path").jsonPrimitive.content

        File(path)
    }

    return maven {
        url = uri(File(manifestPath.parentFile, "maven").path)
        metadataSources.artifact()
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
