cmake_minimum_required(VERSION 3.20)
project(Targets
    VERSION 0.4.0
    DESCRIPTION "Modern CMake build abstraction library"
    LANGUAGES NONE
)

# This CMakeLists.txt is for testing and building examples
# The library itself is header-only CMake modules

option(TARGETS_BUILD_EXAMPLES "Build example projects" ON)
option(TARGETS_BUILD_TESTS "Build integration tests" ON)

# Install CMake modules
install(
    DIRECTORY cmake/
    DESTINATION share/targets/cmake
    FILES_MATCHING PATTERN "*.cmake"
)

# Install package config
include(CMakePackageConfigHelpers)
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/TargetsConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/TargetsConfig.cmake"
    INSTALL_DESTINATION share/targets
)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/TargetsConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/TargetsConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/TargetsConfigVersion.cmake"
    DESTINATION share/targets
)

# Build examples
if(TARGETS_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

# Build tests
if(TARGETS_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
