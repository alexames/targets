# Configure-mode regression/behaviour tests for protobuf_cpp_library / grpc_cpp_library
# (issue #26).
#
# These tests deliberately run WITHOUT protoc or the gRPC plugin installed: CI has neither.
# They cover argument validation, the point-of-use "tool not found" diagnostics, and -- with
# protoc/plugin discovery faked by setting the executable variables -- the generated custom-
# command wiring and target shape. A single scenario is selected via -DSCENARIO=... and
# paired with a PASS_REGULAR_EXPRESSION in the enclosing CTest harness.
#
# The project enables no languages, so no C++ toolchain (and no real protoc) is needed:
# every scenario reaches its assertion during configuration and deliberately halts before
# generation.

cmake_minimum_required(VERSION 3.20)
project(TestProtobufCppLibrary LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

set(_proto_dir "${CMAKE_CURRENT_LIST_DIR}/proto")

if(SCENARIO STREQUAL "missing_target")
  # TARGET is required.
  protobuf_cpp_library(
    PROTOS "${_proto_dir}/example.proto"
    PROTO_ROOT_DIR "${_proto_dir}"
  )
elseif(SCENARIO STREQUAL "missing_protos")
  # PROTOS is required.
  protobuf_cpp_library(
    TARGET MissingProtos
    PROTO_ROOT_DIR "${_proto_dir}"
  )
elseif(SCENARIO STREQUAL "unknown_arg")
  # A misspelled keyword (PROTO instead of PROTOS) must be rejected, not silently ignored.
  protobuf_cpp_library(
    TARGET UnknownArg
    PROTO "${_proto_dir}/example.proto"
  )
elseif(SCENARIO STREQUAL "no_protoc")
  # With valid arguments but no protoc discoverable, the rule must fail clearly at the point
  # of use rather than producing a broken target.
  protobuf_cpp_library(
    TARGET NoProtoc
    PROTOS "${_proto_dir}/example.proto"
    PROTO_ROOT_DIR "${_proto_dir}"
  )
elseif(SCENARIO STREQUAL "no_grpc_plugin")
  # protoc discovery is faked so the rule advances to the gRPC plugin check, which must fail
  # clearly when no plugin is discoverable.
  set(Protobuf_PROTOC_EXECUTABLE "${CMAKE_COMMAND}")
  grpc_cpp_library(
    TARGET NoGrpcPlugin
    PROTOS "${_proto_dir}/example.proto"
    PROTO_ROOT_DIR "${_proto_dir}"
  )
elseif(SCENARIO STREQUAL "wiring")
  # Fake protoc discovery so the rule builds its custom command and target without a real
  # toolchain, then assert the wiring: the target and namespace alias exist, the generated
  # .pb.cc/.pb.h are listed as sources, the generated-header dir is a PUBLIC include, and the
  # PROTOBUF_IMPORT_DIRS property records the proto root. Halts before generation.
  set(Protobuf_PROTOC_EXECUTABLE "${CMAKE_COMMAND}")
  protobuf_cpp_library(
    TARGET WiredProtos
    PROTOS "${_proto_dir}/example.proto"
    PROTO_ROOT_DIR "${_proto_dir}"
  )
  if(NOT TARGET WiredProtos)
    message(FATAL_ERROR "wiring: WiredProtos target was not created")
  endif()
  if(NOT TARGET TestProtobufCppLibrary::WiredProtos)
    message(FATAL_ERROR "wiring: namespace alias TestProtobufCppLibrary::WiredProtos missing")
  endif()
  get_target_property(_srcs WiredProtos SOURCES)
  if(NOT _srcs MATCHES "example\\.pb\\.cc")
    message(FATAL_ERROR "wiring: generated example.pb.cc missing from SOURCES: ${_srcs}")
  endif()
  if(NOT _srcs MATCHES "example\\.pb\\.h")
    message(FATAL_ERROR "wiring: generated example.pb.h missing from SOURCES: ${_srcs}")
  endif()
  if(_srcs MATCHES "example\\.grpc\\.pb\\.cc")
    message(FATAL_ERROR "wiring: protobuf_cpp_library must not emit gRPC stubs: ${_srcs}")
  endif()
  get_target_property(_incs WiredProtos INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT _incs MATCHES "_protobuf_cpp_library/WiredProtos")
    message(FATAL_ERROR "wiring: generated-header dir missing from PUBLIC includes: ${_incs}")
  endif()
  get_target_property(_import_dirs WiredProtos PROTOBUF_IMPORT_DIRS)
  if(NOT _import_dirs STREQUAL "${_proto_dir}")
    message(FATAL_ERROR "wiring: PROTOBUF_IMPORT_DIRS='${_import_dirs}' != '${_proto_dir}'")
  endif()
  message(FATAL_ERROR "WIRING_OK: protobuf_cpp_library wiring verified")
elseif(SCENARIO STREQUAL "grpc_wiring")
  # Fake protoc AND grpc plugin discovery, then assert grpc_cpp_library additionally emits
  # the gRPC service stubs alongside the message sources. Halts before generation.
  set(Protobuf_PROTOC_EXECUTABLE "${CMAKE_COMMAND}")
  set(GRPC_CPP_PLUGIN_EXECUTABLE "${CMAKE_COMMAND}")
  grpc_cpp_library(
    TARGET WiredServices
    PROTOS "${_proto_dir}/example.proto"
    PROTO_ROOT_DIR "${_proto_dir}"
  )
  if(NOT TARGET WiredServices)
    message(FATAL_ERROR "grpc_wiring: WiredServices target was not created")
  endif()
  get_target_property(_srcs WiredServices SOURCES)
  if(NOT _srcs MATCHES "example\\.pb\\.cc")
    message(FATAL_ERROR "grpc_wiring: generated example.pb.cc missing from SOURCES: ${_srcs}")
  endif()
  if(NOT _srcs MATCHES "example\\.grpc\\.pb\\.cc")
    message(FATAL_ERROR "grpc_wiring: generated example.grpc.pb.cc missing from SOURCES: ${_srcs}")
  endif()
  message(FATAL_ERROR "GRPC_WIRING_OK: grpc_cpp_library wiring verified")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
