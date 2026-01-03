# Portfile for Targets library
# This is a CMake-only library (no compiled code)

vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# For local development, use the source directly
set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/../..")

# Install CMake modules
file(INSTALL
    "${SOURCE_PATH}/cmake/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/cmake"
    FILES_MATCHING PATTERN "*.cmake"
)

# Install the main entry point at the root share directory
file(INSTALL
    "${SOURCE_PATH}/cmake/Targets.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Install license
file(INSTALL
    "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright
)

# Install usage file
file(INSTALL
    "${CMAKE_CURRENT_LIST_DIR}/usage"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Create the config file
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/TargetsConfig.cmake" [[
# TargetsConfig.cmake - Package configuration file

get_filename_component(TARGETS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

# Include the main Targets module
include("${TARGETS_CMAKE_DIR}/Targets.cmake")

set(Targets_FOUND TRUE)
]])

# No DLLs, LIBs, or binaries for a CMake-only package
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
