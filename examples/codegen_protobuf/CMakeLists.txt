# Example: Code Generation with Protocol Buffers (and gRPC)
# Demonstrates protobuf_cpp_library() and grpc_cpp_library() usage.
#
# Requires Protocol Buffers (and, for the gRPC portion, gRPC). Install via vcpkg:
#   vcpkg install protobuf grpc
# Detection happens here -- inside this CXX project scope, not the language-less examples
# aggregate -- and the example returns early when Protobuf is unavailable, so a toolchain
# without it still configures and builds cleanly.

cmake_minimum_required(VERSION 3.20)
project(ExampleProtobuf VERSION 1.0.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# Probe for Protocol Buffers in this CXX scope (find_package(Protobuf) needs an enabled
# language). protobuf_cpp_library needs protoc specifically, so gate on it and skip cleanly
# when it is not discoverable.
find_package(Protobuf QUIET)
if(NOT (TARGET protobuf::protoc OR Protobuf_PROTOC_EXECUTABLE))
    message(STATUS "Example: codegen_protobuf - Protocol Buffers (protoc) not found; skipping")
    return()
endif()

# Generate a C++ library from the message schema.
protobuf_cpp_library(
    TARGET AddressBookProtos
    PROTOS proto/addressbook.proto
    PROTO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/proto"
)

# A small consumer that round-trips a generated message.
cpp_binary(
    TARGET AddressBookApp
    SOURCES src/main.cpp
    DEPENDENCIES
        PRIVATE
            AddressBookProtos
    CXX_STANDARD 17
)

# When gRPC is also available, demonstrate grpc_cpp_library(): it generates the message
# sources plus the gRPC service stubs and links the gRPC C++ runtime.
find_package(gRPC QUIET)
if(gRPC_FOUND OR TARGET gRPC::grpc_cpp_plugin)
    grpc_cpp_library(
        TARGET GreeterServices
        PROTOS proto/greeter.proto
        PROTO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/proto"
    )
    message(STATUS "Example: codegen_protobuf - gRPC found, built GreeterServices")
else()
    message(STATUS "Example: codegen_protobuf - gRPC not found, skipping GreeterServices")
endif()

message(STATUS "Example: codegen_protobuf - Created target AddressBookApp")
