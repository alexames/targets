# Configure-mode tests: the codegen and embed rules carry the same target-wide settings
# cpp_target does.
#
# flatbuffer_cpp_library, protobuf_cpp_library and embed_binary each create their target with
# their own add_library(), so nothing cpp_target applies reaches them unless the rule applies
# it too. The settings asserted here are the ones a compiled target gets whatever rule built
# it: CXX_SCAN_FOR_MODULES OFF, and on MSVC the /utf-8 flag.
#
# The 3.28 minimum is load-bearing for the scanning assertions: below it CMP0155 is OLD,
# CMake never scans whatever the property says, and they would hold for the wrong reason.
#
# flatc and protoc are absent on CI, so both are faked with CMAKE_COMMAND exactly as the
# rules' own tests do; neither is ever invoked, because these scenarios only configure and
# generate. embed_binary needs no tool at all -- it writes its sources itself.
#
# A single scenario is selected with -DSCENARIO=... :
#   global_standard       a project-wide CMAKE_CXX_STANDARD of 23, the direct route into
#                         scanning range. It reaches the rules that inherit the standard; the
#                         protobuf target overrides it with its own C++17 pin.
#   interface_propagation no project-wide standard. A header-only cpp_library dependency
#                         carries cxx_std_23 as an INTERFACE compile feature, which raises
#                         the standard its consumers are compiled with -- so a codegen target
#                         reaches scanning range through a dependency alone, in a project
#                         that never asked for C++20 anywhere.

cmake_minimum_required(VERSION 3.28)

if(NOT SCENARIO MATCHES "^(global_standard|interface_propagation)$")
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()

if(SCENARIO STREQUAL "global_standard")
  set(CMAKE_CXX_STANDARD 23)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()

project(TestCodegenTargetDefaults LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

cmake_policy(GET CMP0155 _cmp0155)
if(NOT _cmp0155 STREQUAL "NEW")
  message(FATAL_ERROR
    "CMP0155 is '${_cmp0155}', not NEW -- CMake would not scan whatever the property said, "
    "so this test would pass against unfixed code")
endif()

# Faked tool discovery. The rules advance to target creation without a real toolchain.
set(FLATBUFFERS_FLATC_EXECUTABLE "${CMAKE_COMMAND}")
set(Protobuf_PROTOC_EXECUTABLE "${CMAKE_COMMAND}")

set(_schema "${CMAKE_CURRENT_BINARY_DIR}/message.fbs")
file(WRITE "${_schema}" "table Message { id:int; }\nroot_type Message;\n")

set(_payload "${CMAKE_CURRENT_BINARY_DIR}/payload.bin")
file(WRITE "${_payload}" "codegen-target-defaults-payload")

flatbuffer_cpp_library(
  TARGET SchemaLib
  SCHEMAS "${_schema}"
  SCHEMA_ROOT_DIR "${CMAKE_CURRENT_BINARY_DIR}"
)

protobuf_cpp_library(
  TARGET ProtoLib
  PROTOS "${CMAKE_CURRENT_LIST_DIR}/proto/example.proto"
  PROTO_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/proto"
)

embed_binary(
  TARGET EmbeddedLib
  FILES "${_payload}"
  NAMESPACE test::embedded
)

set(_codegen_targets SchemaLib ProtoLib EmbeddedLib)

if(SCENARIO STREQUAL "global_standard")
  # ProtoLib is absent: protobuf_cpp_library sets CXX_STANDARD 17 on its target, which
  # overrides the project-wide value and keeps it out of scanning range in this scenario.
  # The interface_propagation scenario is where its scanning suppression earns its place.
  foreach(_target SchemaLib EmbeddedLib)
    get_target_property(_standard ${_target} CXX_STANDARD)
    if(NOT _standard GREATER_EQUAL 20)
      message(FATAL_ERROR
        "${_target} is C++${_standard}; CMake does not scan below C++20, so this scenario "
        "would pass against unfixed code")
    endif()
  endforeach()
endif()

if(SCENARIO STREQUAL "interface_propagation")
  # A header-only cpp_library resolves to an INTERFACE library carrying cxx_std_23 as an
  # INTERFACE compile feature. CMake compiles a consumer at the highest standard any of its
  # compile features requires, so linking this raises each codegen target to C++23 -- and
  # therefore into scanning range -- while its CXX_STANDARD property still reads whatever the
  # rule set. The property is why the assertions below cannot use it to prove the raise.
  set(_header "${CMAKE_CURRENT_BINARY_DIR}/headeronly.h")
  file(WRITE "${_header}" "#pragma once\ninline int header_only_symbol() { return 0; }\n")
  cpp_library(
    TARGET HeaderOnlyLib
    HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    HEADERS "${_header}"
  )

  get_target_property(_type HeaderOnlyLib TYPE)
  if(NOT _type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR
      "HeaderOnlyLib is a ${_type}, not an INTERFACE_LIBRARY -- it would carry the compile "
      "feature as a private setting and propagate nothing, so this scenario would assert "
      "against a mechanism that is not present")
  endif()
  get_target_property(_features HeaderOnlyLib INTERFACE_COMPILE_FEATURES)
  if(NOT "cxx_std_23" IN_LIST _features)
    message(FATAL_ERROR
      "HeaderOnlyLib INTERFACE_COMPILE_FEATURES is '${_features}', without cxx_std_23 -- "
      "nothing would raise its consumers into scanning range and this scenario would pass "
      "against unfixed code")
  endif()

  foreach(_target IN LISTS _codegen_targets)
    target_link_libraries(${_target} PUBLIC HeaderOnlyLib)
    get_target_property(_links ${_target} LINK_LIBRARIES)
    if(NOT "HeaderOnlyLib" IN_LIST _links)
      message(FATAL_ERROR "${_target} does not link HeaderOnlyLib: ${_links}")
    endif()
  endforeach()

  # protobuf_cpp_library pins C++17 as a floor for the code protoc generates. A dependency
  # may raise the standard above it, but nothing may lower or drop it.
  get_target_property(_proto_standard ProtoLib CXX_STANDARD)
  if(NOT _proto_standard GREATER_EQUAL 17)
    message(FATAL_ERROR
      "ProtoLib CXX_STANDARD is '${_proto_standard}'; protobuf-generated code needs at "
      "least 17")
  endif()
endif()

foreach(_target IN LISTS _codegen_targets)
  get_target_property(_scan ${_target} CXX_SCAN_FOR_MODULES)
  if(_scan MATCHES "NOTFOUND$")
    set(_scan "<unset>")
  endif()
  get_target_property(_copts ${_target} COMPILE_OPTIONS)
  if(NOT _copts)
    set(_copts "")
  endif()
  message(STATUS "${_target} CXX_SCAN_FOR_MODULES=${_scan} COMPILE_OPTIONS=${_copts}")

  if(NOT "${_scan}" STREQUAL "OFF")
    message(FATAL_ERROR
      "${_target} CXX_SCAN_FOR_MODULES is '${_scan}', expected 'OFF' -- this rule creates "
      "its target without the settings every compiled target carries")
  endif()

  if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
    if(NOT "/utf-8" IN_LIST _copts)
      message(FATAL_ERROR "expected /utf-8 in ${_target} COMPILE_OPTIONS: ${_copts}")
    endif()
  elseif(_copts MATCHES "/utf-8")
    message(FATAL_ERROR
      "MSVC-only /utf-8 leaked to a non-MSVC toolchain on ${_target}: ${_copts}")
  endif()
endforeach()

message(STATUS "codegen target defaults test passed (${SCENARIO})")
