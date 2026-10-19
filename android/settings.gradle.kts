pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Munyati"

// Same module split as the iOS app's Swift packages (see ../CLAUDE.md and android/README.md).
include(":app")
include(":core")
include(":networking")
include(":shared")
include(":designsystem")
include(":authentication")

// Feature modules, one per iOS package under Packages/Features.
include(":features:catalog")
include(":features:providerstudio")
