# Targets - Modern CMake Build Abstraction
# Version: see cmake/TargetsVersion.cmake (single source of truth)
# Homepage: https://github.com/alexames/targets
# License: MIT

if(TARGETS_INCLUDED)
    return()
endif()
set(TARGETS_INCLUDED TRUE)

# Every feature these modules use above this floor is version-guarded and degrades, so this
# is the whole compatibility statement. A CI job configures at exactly this version to keep
# that true.
if(CMAKE_VERSION VERSION_LESS "3.20")
    message(FATAL_ERROR "Targets requires CMake 3.20 or later")
endif()

get_filename_component(TARGETS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

list(APPEND CMAKE_MODULE_PATH "${TARGETS_CMAKE_DIR}")

include("${TARGETS_CMAKE_DIR}/TargetsVersion.cmake")

include("${TARGETS_CMAKE_DIR}/core/install_export.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_target.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_library.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_binary.cmake")
include("${TARGETS_CMAKE_DIR}/core/cpp_test.cmake")

include("${TARGETS_CMAKE_DIR}/dependencies/import_dependencies.cmake")
include("${TARGETS_CMAKE_DIR}/dependencies/find_targets.cmake")

include("${TARGETS_CMAKE_DIR}/codegen/flatbuffer_cpp_library.cmake")
include("${TARGETS_CMAKE_DIR}/codegen/protobuf_cpp_library.cmake")

include("${TARGETS_CMAKE_DIR}/utils/set_folder_for_targets.cmake")
include("${TARGETS_CMAKE_DIR}/utils/embed_binary.cmake")
include("${TARGETS_CMAKE_DIR}/utils/compiler_cache.cmake")

message(STATUS "Targets: Modern CMake build abstraction loaded (version ${TARGETS_VERSION})")
