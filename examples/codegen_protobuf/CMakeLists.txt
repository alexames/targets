# Example: Code Generation with Protocol Buffers (and gRPC)
# Demonstrates protobuf_cpp_library() and grpc_cpp_library() usage.
#
# Requires Protocol Buffers (and, for the gRPC portion, gRPC). Install via vcpkg:
#   vcpkg install protobuf grpc
# The enclosing examples/CMakeLists.txt only adds this example when Protobuf is found, so a
# toolchain without it is skipped rather than failing to configure.

cmake_minimum_required(VERSION 3.20)
project(ExampleProtobuf VERSION 1.0.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

find_package(Protobuf REQUIRED)

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
