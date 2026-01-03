# Example: Code Generation with FlatBuffers
# Demonstrates flatbuffer_cpp_library() usage

cmake_minimum_required(VERSION 3.20)
project(ExampleFlatBuffers VERSION 1.0.0)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Note: This example requires FlatBuffers to be installed
# Install via vcpkg: vcpkg install flatbuffers

message(STATUS "Example: codegen_flatbuffers - FlatBuffers codegen example")
message(STATUS "  This example is a placeholder. A complete implementation would require FlatBuffers schemas.")
