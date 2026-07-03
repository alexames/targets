# Example: Embed Binary
# Demonstrates embed_binary() - compiling a data file into a C++ static library

cmake_minimum_required(VERSION 3.20)
project(ExampleEmbedBinary VERSION 1.0.0)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Embed a data file as a C++ static library. The generated header is placed on
# EmbeddedAssets' public include path, so anything linking it can #include it.
embed_binary(
    TARGET EmbeddedAssets
    FILES
        assets/message.txt
    NAMESPACE embedded_assets
)

# An executable that reads the embedded data.
cpp_binary(
    TARGET EmbedBinaryDemo
    SOURCES
        src/main.cpp
    DEPENDENCIES
        PRIVATE
            EmbeddedAssets
    CXX_STANDARD 17
)

message(STATUS "Example: embed_binary - Created target EmbeddedAssets")
