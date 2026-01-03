# Example: Executable with Dependencies
# Demonstrates cpp_binary() usage and linking to other targets

cmake_minimum_required(VERSION 3.20)
project(ExampleExecutable VERSION 1.0.0)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Build the basic_library example first
add_subdirectory(../basic_library "${CMAKE_CURRENT_BINARY_DIR}/basic_library")

# Define an executable that depends on MathLib
cpp_binary(
    TARGET CalculatorApp
    SOURCES
        src/main.cpp
    DEPENDENCIES
        PRIVATE
            MathLib
    CXX_STANDARD 17
)

message(STATUS "Example: executable_with_deps - Created target CalculatorApp")
