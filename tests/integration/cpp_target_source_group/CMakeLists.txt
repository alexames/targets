# Configure-mode regression test for cpp_target() source grouping (issue #6).
#
# source_group(TREE <root> FILES <files>) reports an error for any file that is not
# located under <root>. cpp_target passed every source and header through it, so a
# generated file in an out-of-source build tree (or a "../shared" source) made
# configuration fail with "ROOT: ... is not a prefix of file: ...". That error is a
# (non-fatal) CMake error: it does not halt processing, but it does make configuration
# exit non-zero and skip generation. It is layout-dependent, so it slipped past a
# build-inside-source CI and broke out-of-source builds.
#
# This project mixes in-tree fixtures (in_tree.cpp / Include/in_tree.h) with generated
# files written to the build tree (out of the SOURCE_DIR/HEADER_DIR roots). The CTest
# harness invokes it with a build dir that is a sibling of this source dir, so the
# generated files are genuinely outside the roots. With the bug present, configuration
# fails (non-zero exit) and the CTest fails; with the fix, the out-of-root files are
# grouped flat and configuration + generation complete cleanly (exit 0).

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetSourceGroup LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# Generated files placed in the build tree. With an out-of-source build dir these are
# not under SOURCE_DIR/HEADER_DIR, which is exactly the case that used to error.
set(generated_source "${CMAKE_CURRENT_BINARY_DIR}/generated.cpp")
set(generated_header "${CMAKE_CURRENT_BINARY_DIR}/generated.h")
file(WRITE "${generated_source}" "int generated() { return 1; }\n")
file(WRITE "${generated_header}" "#pragma once\nint generated();\n")

# SOURCE_DIR/HEADER_DIR default to this list dir (and its Include/ subdir), so in_tree.*
# are under the roots while the generated files are not. A clean configure proves the
# out-of-root files skipped source_group(TREE ...) instead of failing it.
cpp_library(
  TARGET SourceGroupLib
  SOURCES
    in_tree.cpp
    "${generated_source}"
  HEADERS
    in_tree.h
    "${generated_header}"
)

if(NOT TARGET SourceGroupLib)
  message(FATAL_ERROR "cpp_library did not create target SourceGroupLib")
endif()

message(STATUS "cpp_target source_group configure-mode test passed")
