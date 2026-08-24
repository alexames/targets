# Configure-mode regression test for the placeholder translation unit cpp_target() injects.
#
# Every library these rules create is a compiled one, so a consumer sees the same usage
# requirements however it reached the target. A library with nothing of its own to compile
# therefore gets the shipped dummy.cpp: that covers a header-only library (public files, no
# private translation unit) and a codegen library whose translation units are produced by
# custom commands (no files at all). Both are asserted here, because each reaches the
# placeholder by a different route through the file lists.
#
# The placeholder is resolved from the shipped cmake/dummy.cpp; a checkout or package that
# failed to ship it fails loudly rather than producing a library with no translation unit.
#
# A FATAL_ERROR in any assertion makes configuration exit non-zero and fails the CTest.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetDummySource LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# (1) Header-only library: HEADERS but no SOURCES -> STATIC carrying the placeholder TU.
cpp_library(
  TARGET HeaderOnlyLib
  HEADERS header_only.h
)

get_target_property(_ho_type HeaderOnlyLib TYPE)
if(NOT _ho_type STREQUAL "STATIC_LIBRARY")
  message(FATAL_ERROR
    "header-only cpp_library must be STATIC_LIBRARY, got '${_ho_type}'")
endif()

get_target_property(_ho_sources HeaderOnlyLib SOURCES)
if(NOT _ho_sources MATCHES "dummy\\.cpp")
  message(FATAL_ERROR
    "header-only library must carry the dummy.cpp placeholder TU, got: '${_ho_sources}'")
endif()

# (2) Source-less, header-less library -> STATIC carrying the dummy.cpp placeholder TU.
cpp_library(
  TARGET GeneratedLib
)

get_target_property(_gen_type GeneratedLib TYPE)
if(NOT _gen_type STREQUAL "STATIC_LIBRARY")
  message(FATAL_ERROR
    "source-less cpp_library must be STATIC_LIBRARY, got '${_gen_type}'")
endif()

get_target_property(_gen_sources GeneratedLib SOURCES)
if(NOT _gen_sources MATCHES "dummy\\.cpp")
  message(FATAL_ERROR
    "source-less STATIC library must carry the dummy.cpp placeholder TU, got: "
    "'${_gen_sources}'")
endif()

message(STATUS "cpp_target dummy.cpp placeholder test passed")
