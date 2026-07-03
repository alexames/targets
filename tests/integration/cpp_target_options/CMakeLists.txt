# Configure-mode tests for the per-target COPTS / LINKOPTS options and the DATA attribute
# (issue #27).
#
# COPTS and LINKOPTS carry PUBLIC/PRIVATE visibility and the same platform buckets as
# DEFINITIONS, translating to target_compile_options / target_link_options. These tests
# inspect COMPILE_OPTIONS / LINK_OPTIONS (and the INTERFACE_* variants) to prove the values
# land with the correct visibility and platform filtering. DATA staging is a POST_BUILD copy
# whose runtime behaviour is proven by the examples/data_files example (built and run in CI);
# here the "data_stage" scenario only proves the staging wiring configures cleanly for both a
# file and a directory, and "interface_warns" proves COPTS/LINKOPTS/DATA are reported as
# ignored on a header-only INTERFACE library (consistent with issue #13).
#
# No C++ toolchain is needed: the options are stored as literal strings regardless of the
# active compiler, so the project enables no languages and each scenario halts (via a sentinel
# FATAL_ERROR matched by PASS_REGULAR_EXPRESSION) before generation.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetOptions LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

if(NOT DEFINED SCENARIO)
  message(FATAL_ERROR
    "This test project requires -DSCENARIO=<copts|linkopts|data_stage|interface_warns>")
endif()

# A real translation unit in the build tree so a compiled (non-INTERFACE) target is created;
# SOURCE_DIR points there to keep source_group(TREE) happy. It is never compiled (LANGUAGES
# NONE); every scenario halts before generation.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/opts.cpp")
file(WRITE "${_src}" "int opts_symbol() { return 0; }\n")

# Fetch a target's option-list property as a (possibly empty) list.
macro(_get_opts _out _tgt _prop)
  get_target_property(${_out} ${_tgt} ${_prop})
  if(NOT ${_out})
    set(${_out} "")
  endif()
endmacro()

# Assert that ITEM is / is not present in the list held by LIST_VAR.
function(_expect_in list_var item)
  if(NOT "${item}" IN_LIST ${list_var})
    message(FATAL_ERROR "${SCENARIO}: expected '${item}' in ${list_var}='${${list_var}}'")
  endif()
endfunction()
function(_expect_not_in list_var item)
  if("${item}" IN_LIST ${list_var})
    message(FATAL_ERROR "${SCENARIO}: '${item}' must NOT be in ${list_var}='${${list_var}}'")
  endif()
endfunction()

if(SCENARIO STREQUAL "copts")
  # PUBLIC options reach both COMPILE_OPTIONS and INTERFACE_COMPILE_OPTIONS; PRIVATE options
  # only COMPILE_OPTIONS. The WINDOWS-bucketed option is present only on Windows.
  cpp_library(TARGET OptCopts
    COPTS
      PUBLIC -pub-copt
      PRIVATE -priv-copt WINDOWS /bigobj
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts OptCopts COMPILE_OPTIONS)
  _get_opts(_iface OptCopts INTERFACE_COMPILE_OPTIONS)
  _expect_in(_copts "-pub-copt")
  _expect_in(_copts "-priv-copt")
  _expect_in(_iface "-pub-copt")
  _expect_not_in(_iface "-priv-copt")
  if(WIN32)
    _expect_in(_copts "/bigobj")
  else()
    _expect_not_in(_copts "/bigobj")
  endif()
  message(FATAL_ERROR "COPTS_OK: compile options applied with visibility and platform filter")

elseif(SCENARIO STREQUAL "linkopts")
  cpp_library(TARGET OptLinkopts
    LINKOPTS
      PUBLIC -pub-link
      PRIVATE -priv-link LINUX -priv-linux-link
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_lopts OptLinkopts LINK_OPTIONS)
  _get_opts(_iface OptLinkopts INTERFACE_LINK_OPTIONS)
  _expect_in(_lopts "-pub-link")
  _expect_in(_lopts "-priv-link")
  _expect_in(_iface "-pub-link")
  _expect_not_in(_iface "-priv-link")
  if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    _expect_in(_lopts "-priv-linux-link")
  else()
    _expect_not_in(_lopts "-priv-linux-link")
  endif()
  message(FATAL_ERROR "LINKOPTS_OK: link options applied with visibility and platform filter")

elseif(SCENARIO STREQUAL "data_stage")
  # DATA on a compiled binary must configure cleanly for both a file and a directory: the
  # POST_BUILD staging custom commands are wired without error. Runtime staging is proven by
  # the examples/data_files example.
  set(_datafile "${CMAKE_CURRENT_BINARY_DIR}/asset.txt")
  file(WRITE "${_datafile}" "asset\n")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/assets")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/assets/more.txt" "more\n")
  cpp_binary(TARGET DataStageApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    DATA "${_datafile}" "${CMAKE_CURRENT_BINARY_DIR}/assets")
  if(NOT TARGET DataStageApp)
    message(FATAL_ERROR "data_stage: DataStageApp target was not created")
  endif()
  message(FATAL_ERROR "DATA_STAGE_OK: DATA file + directory staging wired")

elseif(SCENARIO STREQUAL "interface_warns")
  # COPTS/LINKOPTS are compile/link settings and DATA stages next to an artifact; a header-only
  # INTERFACE library has neither, so all three must be reported as ignored (issue #13 policy).
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/opts.h" "#pragma once\nint hdr_only();\n")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/opts_data.txt" "data\n")
  cpp_library(TARGET OptHeaderOnly
    HEADERS "${CMAKE_CURRENT_BINARY_DIR}/opts.h"
    HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    COPTS PRIVATE -fno-rtti
    LINKOPTS PRIVATE -s
    DATA "${CMAKE_CURRENT_BINARY_DIR}/opts_data.txt")
  message(FATAL_ERROR "interface_warns: expected an ignored-argument warning, not this")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
