# The embedded INNER project. Its own project() call makes PROJECT_NAME == "Inner" for
# everything beneath it, while CMAKE_PROJECT_NAME stays "Outer" (the top-level project).
# The target that exercises the Targets rules lives under this project's Source/ tree so
# that the namespace root (default ${PROJECT_SOURCE_DIR}/Source) resolves correctly.

project(Inner LANGUAGES CXX)

add_subdirectory(Source/Core)
