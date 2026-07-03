# Example: Toolchain Hygiene
# Demonstrates the opt-in hygiene knobs (issue #23): a strict warning level and link-time
# optimization, applied per target and translated per compiler.
#
# Building this example (as CI does on GCC / Clang / MSVC) proves the knobs land valid,
# compiler-appropriate flags on every toolchain. WERROR and SANITIZERS are intentionally
# NOT used here so the example stays buildable everywhere; their exact flag mapping is
# covered by the configure-mode tests under tests/integration/cpp_target_hygiene.

cmake_minimum_required(VERSION 3.20)
project(ToolchainHygiene VERSION 1.0.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# A library built with a strict warning level and link-time optimization. WARNINGS strict
# maps to /W4 (MSVC) or -Wall -Wextra -Wpedantic (GCC/Clang); LTO enables interprocedural
# optimization when the toolchain supports it (check_ipo_supported) and no-ops otherwise.
cpp_library(
    TARGET HygieneMath
    SOURCES
        src/hygiene.cpp
    HEADERS
        hygiene/hygiene.h
    HEADER_DIR
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES
        PUBLIC
            include/
    CXX_STANDARD 17
    WARNINGS strict
    LTO
)

# The consuming executable opts into the same hygiene knobs.
cpp_binary(
    TARGET HygieneApp
    SOURCES
        src/main.cpp
    DEPENDENCIES
        PRIVATE
            HygieneMath
    CXX_STANDARD 17
    WARNINGS strict
    LTO
)

message(STATUS "Example: toolchain_hygiene - Created HygieneMath (WARNINGS strict, LTO) and HygieneApp")
