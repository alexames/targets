# Configure-mode regression test for cpp_target()'s dummy.cpp fallback and header-only
# INTERFACE detection (issue #7).
#
# Two intertwined behaviors are asserted:
#   1. A library with HEADERS but no SOURCES must become an INTERFACE library and must NOT
#      gain the dummy.cpp placeholder translation unit. Before the fix, the dummy was
#      appended to the sources list *before* the INTERFACE decision, so the moment the
#      dummy path resolved every header-only library silently became a STATIC library
#      containing only dummy.cpp (changing its usage-requirement semantics).
#   2. A library with neither SOURCES nor HEADERS (e.g. a codegen STATIC target whose TUs
#      are produced by custom commands) must configure as a STATIC library carrying the
#      shipped dummy.cpp placeholder TU. Before the fix the fallback pointed at the wrong
#      directory (cmake/core/dummy.cpp instead of cmake/dummy.cpp) and never fired, so this
#      failed with CMake's "No SOURCES given to target".
#
# A FATAL_ERROR in any assertion makes configuration exit non-zero and fails the CTest.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetDummySource LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# (1) Header-only library: HEADERS but no SOURCES -> INTERFACE, and no dummy TU.
cpp_library(
  TARGET HeaderOnlyLib
  HEADERS header_only.h
)

get_target_property(_ho_type HeaderOnlyLib TYPE)
if(NOT _ho_type STREQUAL "INTERFACE_LIBRARY")
  message(FATAL_ERROR
    "header-only cpp_library must be INTERFACE_LIBRARY, got '${_ho_type}' "
    "(dummy.cpp likely flipped it to STATIC -- issue #7)")
endif()

# An INTERFACE library must not carry a compiled placeholder TU.
get_target_property(_ho_sources HeaderOnlyLib SOURCES)
if(_ho_sources AND _ho_sources MATCHES "dummy\\.cpp")
  message(FATAL_ERROR
    "header-only INTERFACE library must not carry the dummy.cpp TU: ${_ho_sources}")
endif()

# (2) Source-less, header-less library -> STATIC carrying the dummy.cpp placeholder TU.
cpp_library(
  TARGET GeneratedLib
)

get_target_property(_gen_type GeneratedLib TYPE)
if(NOT _gen_type STREQUAL "STATIC_LIBRARY")
  message(FATAL_ERROR
    "source-less cpp_library must be STATIC_LIBRARY, got '${_gen_type}' (issue #7)")
endif()

get_target_property(_gen_sources GeneratedLib SOURCES)
if(NOT _gen_sources MATCHES "dummy\\.cpp")
  message(FATAL_ERROR
    "source-less STATIC library must carry the dummy.cpp placeholder TU, got: "
    "'${_gen_sources}' (issue #7)")
endif()

message(STATUS "cpp_target dummy.cpp / INTERFACE test passed (issue #7)")
