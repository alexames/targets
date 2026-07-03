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

message(STATUS "consume_port: found Targets via the installed port and defined targets")
