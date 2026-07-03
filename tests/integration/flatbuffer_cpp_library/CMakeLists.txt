# Configure-mode regression test for flatbuffer_cpp_library() source grouping (issue #59).
#
# source_group(TREE <root> FILES <files>) reports an error for any file that is not located
# under <root>. flatbuffer_cpp_library passed its generated headers, schema sources, and
# binary schemas straight through it, so a schema (or generated file) resolving outside the
# given root -- an out-of-source build tree layout or a `..`-relative schema -- made
# configuration fail with "ROOT: ... is not a prefix of file: ...". That error is a
# (non-fatal, SEND_ERROR) CMake error: it does not halt processing, but it does make
# configuration exit non-zero and skip generation. This is the same defect fixed for
# cpp_target in issue #6, re-introduced here by copy-pasted scaffolding.
#
# This test writes a schema into the build tree (out of SCHEMA_ROOT_DIR, which is the source
# tree) so its generated header and binary schema also resolve out of their respective roots
# -- exercising all three source_group(TREE ...) sites at once. flatc is never installed on
# CI, so the flatc executable is faked with CMAKE_COMMAND (exactly as the protobuf tests fake
# protoc); the rule builds its custom commands and target without a real toolchain and nothing
# is ever generated. A clean configure (exit 0) proves the out-of-root files skipped
# source_group(TREE ...) instead of failing it. With the bug present, configuration exits
# non-zero and this test fails. There is deliberately no PASS_REGULAR_EXPRESSION: the original
# error is a SEND_ERROR that would not stop a trailing sentinel from printing, so the exit code
# is the only reliable signal (mirroring the issue #6 test).

cmake_minimum_required(VERSION 3.20)
project(TestFlatbufferCppLibrary LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# Fake flatc discovery so the rule advances to target creation and source grouping without a
# real FlatBuffers toolchain. It is never invoked: the test only configures + generates.
set(FLATBUFFERS_FLATC_EXECUTABLE "${CMAKE_COMMAND}")

# A schema written into the build tree. With an out-of-source build dir it is not under
# SCHEMA_ROOT_DIR (the source tree), which is exactly the layout that used to error.
set(generated_schema "${CMAKE_CURRENT_BINARY_DIR}/generated/message.fbs")
file(WRITE "${generated_schema}" "table Message { id:int; }\nroot_type Message;\n")

flatbuffer_cpp_library(
  TARGET OutOfRootSchemas
  SCHEMAS "${generated_schema}"
  SCHEMA_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}"
  BINARY_SCHEMAS_DIR "${CMAKE_CURRENT_BINARY_DIR}/bfbs"
)

if(NOT TARGET OutOfRootSchemas)
  message(FATAL_ERROR "flatbuffer_cpp_library did not create target OutOfRootSchemas")
endif()

message(STATUS "flatbuffer_cpp_library source_group configure-mode test passed")
