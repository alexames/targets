# Targets - Modern CMake Build Abstraction
# Version: 0.1.0
# Homepage: https://github.com/yourusername/targets
# License: MIT

if(TARGETS_INCLUDED)
    return()
endif()
set(TARGETS_INCLUDED TRUE)

# Minimum CMake version check
if(CMAKE_VERSION VERSION_LESS "3.20")
    message(FATAL_ERROR "Targets requires CMake 3.20 or later")
endif()

# Get the directory where this file is located
get_filename_component(TARGETS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

# Add to module path
list(APPEND CMAKE_MODULE_PATH "${TARGETS_CMAKE_DIR}")

# Include core modules
include("${TARGETS_CMAKE_DIR}/core/cpp_target.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_library.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_binary.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_test.cmake")

# Include dependency management
include("${TARGETS_CMAKE_DIR}/dependencies/import_dependencies.cmake")
include("${TARGETS_CMAKE_DIR}/dependencies/find_targets.cmake")

# Include code generation
include("${TARGETS_CMAKE_DIR}/codegen/flatbuffer_cpp_library.cmake")

# Include utilities
include("${TARGETS_CMAKE_DIR}/utils/set_folder_for_targets.cmake")
include("${TARGETS_CMAKE_DIR}/utils/embed_binary.cmake")

message(STATUS "Targets: Modern CMake build abstraction loaded (version 0.1.0)")
