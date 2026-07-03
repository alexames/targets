# Install/export rule generation (regression test for issue #20).
#
# cpp_library(... INSTALL EXPORT ...) must make the target export-safe and generate the
# install/export rules. This project configures AND generates (the CTest harness runs
# `cmake -S -B`, which includes the generate step), so the install(EXPORT) rule emitted by
# cpp_library is validated by CMake at generate time: a plain source path left in the
# target's INTERFACE_INCLUDE_DIRECTORIES would make generation a hard error. The explicit
# assertions below add a fast, direct check that the include dirs were wrapped and the
# exported alias exists. Any FATAL_ERROR (assertion or generate-time) fails the test via a
# non-zero exit; the sentinel is informational only.
cmake_minimum_required(VERSION 3.20)
project(InstallExportAssert VERSION 3.1.0 LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

cpp_library(
  TARGET Thing
  SOURCES src/thing.cpp
  HEADERS thing/thing.h
  HEADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include
  INCLUDES
    PUBLIC include/
  INSTALL
  EXPORT InstallExportAssertTargets
)

# The exported target name must match the build-tree alias, so a downstream consumer uses
# the same InstallExportAssert::Thing whether it vendors the library or find_package()s it.
if(NOT TARGET InstallExportAssert::Thing)
  message(FATAL_ERROR "install: expected namespaced alias InstallExportAssert::Thing (issue #20)")
endif()

# Public include dirs must be wrapped so install(EXPORT) is export-safe: a BUILD_INTERFACE
# entry for in-tree consumers and an INSTALL_INTERFACE entry for installed consumers.
get_target_property(_inc Thing INTERFACE_INCLUDE_DIRECTORIES)
if(NOT _inc MATCHES "INSTALL_INTERFACE")
  message(FATAL_ERROR "install: Thing is missing an INSTALL_INTERFACE include entry: ${_inc}")
endif()
if(NOT _inc MATCHES "BUILD_INTERFACE")
  message(FATAL_ERROR "install: Thing is missing a BUILD_INTERFACE include entry: ${_inc}")
endif()

message(STATUS "INSTALL_EXPORT_OK")
