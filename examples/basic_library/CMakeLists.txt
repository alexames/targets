# Example: Basic Library
# Demonstrates cpp_library() usage

cmake_minimum_required(VERSION 3.20)
project(ExampleBasicLibrary VERSION 1.0.0)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Define a simple library
cpp_library(
    TARGET MathLib
    SOURCES
        src/calculator.cpp
    HEADERS
        include/mathlib/calculator.h
    INCLUDES
        PUBLIC
            include/
    CXX_STANDARD 17
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
)

message(STATUS "Example: basic_library - Created target MathLib")
