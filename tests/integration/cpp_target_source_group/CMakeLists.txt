# Configure-mode regression tests for cpp_target()'s file grouping (issues #6 and #66).
#
# source_group(TREE <root> FILES <files>) reports an error for any file that is not
# located under <root>. cpp_target passed every source and header through it, so a
# generated file in an out-of-source build tree (or a "../shared" source) made
# configuration fail with "ROOT: ... is not a prefix of file: ...". That error is a
# (non-fatal) CMake error: it does not halt processing, but it does make configuration
# exit non-zero and skip generation. It is layout-dependent, so it slipped past a
# build-inside-source CI and broke out-of-source builds.
#
# The two roots are also the private and public base directories: a PRIVATE entry resolves
# against SOURCE_DIR and a PUBLIC one against HEADER_DIR, whichever spelling named it. The
# visibility_base_dirs scenario pins that, and ide_source_groups.cmake reads back the IDE
# groups it produces.
#
# A single scenario is selected via -DSCENARIO=..., and every one configures and generates
# to the end: the exit code decides, and a file resolved against the wrong base names a path
# that is not there, which CMake reports at generate time.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetSourceGroup LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

if(SCENARIO STREQUAL "out_of_root")
  # Generated files placed in the build tree. With an out-of-source build dir these are
  # not under SOURCE_DIR/HEADER_DIR, which is exactly the case that used to error.
  set(generated_source "${CMAKE_CURRENT_BINARY_DIR}/generated.cpp")
  set(generated_header "${CMAKE_CURRENT_BINARY_DIR}/generated.h")
  file(WRITE "${generated_source}" "int generated() { return 1; }\n")
  file(WRITE "${generated_header}" "#pragma once\nint generated();\n")

  # SOURCE_DIR/HEADER_DIR default to this list dir (and its Include/ subdir), so in_tree.*
  # are under the roots while the generated files are not. A clean configure proves the
  # out-of-root files skipped source_group(TREE ...) instead of failing it. The deprecated
  # spelling is deliberate here: it keeps a call in the suite that still uses it.
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
    message(FATAL_ERROR "out_of_root: cpp_library did not create target SourceGroupLib")
  endif()
elseif(SCENARIO STREQUAL "visibility_base_dirs")
  # detail.hpp exists only beside this CMakeLists (SOURCE_DIR) and public.hpp only under
  # Include (HEADER_DIR), so an entry resolved against the other base names a file that is
  # not there and generation fails -- the assertions below are not the only thing holding
  # the two bases apart.
  cpp_library(
    TARGET VisibilityLib
    SOURCES
      PUBLIC
        public.hpp
      PRIVATE
        in_tree.cpp
        detail.hpp
  )

  get_target_property(_files VisibilityLib SOURCES)
  foreach(_expected
      "${CMAKE_CURRENT_LIST_DIR}/in_tree.cpp"
      "${CMAKE_CURRENT_LIST_DIR}/detail.hpp"
      "${CMAKE_CURRENT_LIST_DIR}/Include/public.hpp")
    if(NOT "${_expected}" IN_LIST _files)
      message(FATAL_ERROR
        "visibility_base_dirs: '${_expected}' is missing from VisibilityLib's SOURCES, "
        "which holds: ${_files}")
    endif()
  endforeach()

  # A private header carries no compile step, but in_tree.cpp does.
  get_target_property(_type VisibilityLib TYPE)
  if(NOT _type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "visibility_base_dirs: expected STATIC_LIBRARY, got '${_type}'")
  endif()
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
