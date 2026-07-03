# Example: SHARED library ergonomics on Windows (issue #21)
# Demonstrates the two things that make a SHARED cpp_library usable out of the box:
#
#   1. EXPORT_HEADER on the library generates a <target>_export.h with a GREETER_EXPORT macro
#      that expands to the right __declspec(dllexport/dllimport) / visibility attribute. On
#      MSVC this is what populates the import library so the executable can link at all.
#   2. Automatic DLL staging copies the built Greeter.dll next to GreeterApp.exe after the
#      build, so the executable actually launches from the build tree.
#
# The library is built in its own subdirectory (greeter/) so its .dll lands in a different
# output directory than the app -- the executable therefore genuinely relies on the staging
# step rather than incidental co-location. On Linux/macOS there are no DLLs; the shared object
# is found through the build-tree RPATH and the staging step is a no-op.

cmake_minimum_required(VERSION 3.20)
project(SharedLibraryExample VERSION 1.0.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Build the SHARED library first.
add_subdirectory(greeter)

# An executable that links the SHARED library. Targets stages Greeter's DLL next to this
# executable automatically, so running it from the build tree just works.
cpp_binary(
    TARGET GreeterApp
    SOURCES app/main.cpp
    DEPENDENCIES
        PRIVATE
            Greeter
    CXX_STANDARD 17
)

message(STATUS "Example: shared_library - Created SHARED Greeter + GreeterApp")
