# End-to-end consumer for the in-repo vcpkg overlay port.
#
# Regression test for https://github.com/alexames/targets/issues/2: the in-repo
# ports/targets portfile installed a layout whose TargetsConfig.cmake pointed at CMake
# modules that did not exist, so find_package(Targets CONFIG REQUIRED) failed. CI
# configures this project with the vcpkg toolchain and --overlay-ports=<repo>/ports, so
# it consumes the package exactly as the port installs it. Configuration only succeeds if
# the port installs a working layout: find_package must locate the package and the
# included CMake modules must define the cpp_* rules used below.

cmake_minimum_required(VERSION 3.20)
project(ConsumeTargetsPort LANGUAGES CXX)

find_package(Targets CONFIG REQUIRED)

cpp_library(
  TARGET Greeter
  SOURCES src/greeter.cpp
  HEADERS greeter.h
  HEADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include
  INCLUDES
    PUBLIC include
)

cpp_binary(
  TARGET greet
  SOURCES src/main.cpp
  DEPENDENCIES
    PRIVATE Greeter
)

# Exercise the source-less STATIC fallback from the INSTALLED package layout (issue #7).
# A library with neither SOURCES nor HEADERS must resolve the shipped dummy.cpp placeholder
# TU from share/targets/cmake/dummy.cpp and build as a STATIC library. Previously the
# fallback pointed at the wrong directory and the port shipped no dummy.cpp, so a port
# consumer could never create such a target. This target is part of the default build, so
# `cmake --build` compiles the installed dummy.cpp end-to-end.
cpp_library(
  TARGET GeneratedPlaceholder
)

get_target_property(_placeholder_type GeneratedPlaceholder TYPE)
if(NOT _placeholder_type STREQUAL "STATIC_LIBRARY")
  message(FATAL_ERROR
    "source-less cpp_library must be STATIC_LIBRARY from the installed port, got "
    "'${_placeholder_type}' (issue #7)")
endif()

message(STATUS "consume_port: found Targets via the installed port and defined targets")
