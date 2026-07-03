# Configure-mode tests for the opt-in toolchain hygiene knobs (issue #23).
#
# WARNINGS / WERROR / SANITIZERS / LTO are all OFF by default: a target only gets these
# flags when it explicitly opts in, and the flags are translated per compiler with
# CXX_COMPILER_ID generator expressions. These tests inspect COMPILE_OPTIONS / LINK_OPTIONS
# and the INTERPROCEDURAL_OPTIMIZATION property to prove that opting in lands the expected,
# compiler-gated entries and that the default target gets none of them.
#
# Most scenarios need no C++ toolchain -- the flags are stored as literal generator-
# expression strings regardless of the active compiler -- so the project enables no
# languages and each scenario halts (via a sentinel FATAL_ERROR matched by
# PASS_REGULAR_EXPRESSION) before generation. The LTO scenario is the exception: it enables
# CXX because check_ipo_supported() probes the compiler.

cmake_minimum_required(VERSION 3.20)

if(SCENARIO STREQUAL "lto")
  project(TestCppTargetHygiene LANGUAGES CXX)
else()
  project(TestCppTargetHygiene LANGUAGES NONE)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A real translation unit in the build tree so a compiled (non-INTERFACE) library is
# created; SOURCE_DIR points there to keep source_group(TREE) happy. It is never compiled
# for the LANGUAGES NONE scenarios (they halt before generation).
set(_src "${CMAKE_CURRENT_BINARY_DIR}/hygiene.cpp")
file(WRITE "${_src}" "int hygiene_symbol() { return 0; }\n")

# Fetch a target's COMPILE_OPTIONS / LINK_OPTIONS as a (possibly empty) list.
macro(_get_opts _out _tgt _prop)
  get_target_property(${_out} ${_tgt} ${_prop})
  if(NOT ${_out})
    set(${_out} "")
  endif()
endmacro()

if(SCENARIO STREQUAL "default")
  # No knobs: none of the hygiene flags/properties must appear.
  cpp_library(TARGET HygieneDefault SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts HygieneDefault COMPILE_OPTIONS)
  _get_opts(_lopts HygieneDefault LINK_OPTIONS)
  foreach(_needle "/W4" "/W0" "-Wall" "-w" "/WX" "-Werror" "-fsanitize" "/fsanitize")
    if("${_copts}" MATCHES "${_needle}" OR "${_lopts}" MATCHES "${_needle}")
      message(FATAL_ERROR "default: unexpected hygiene flag '${_needle}' in copts='${_copts}' lopts='${_lopts}'")
    endif()
  endforeach()
  get_target_property(_ipo HygieneDefault INTERPROCEDURAL_OPTIMIZATION)
  if(_ipo)
    message(FATAL_ERROR "default: INTERPROCEDURAL_OPTIMIZATION set without opt-in: ${_ipo}")
  endif()
  message(FATAL_ERROR "DEFAULT_OK: no hygiene flags injected by default")

elseif(SCENARIO STREQUAL "warnings_strict")
  cpp_library(TARGET HygieneWarn WARNINGS strict SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts HygieneWarn COMPILE_OPTIONS)
  foreach(_expected
      "$<$<CXX_COMPILER_ID:MSVC>:/W4>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wextra>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wpedantic>")
    if(NOT "${_expected}" IN_LIST _copts)
      message(FATAL_ERROR "warnings_strict: expected '${_expected}' in COMPILE_OPTIONS: ${_copts}")
    endif()
  endforeach()
  message(FATAL_ERROR "WARNINGS_STRICT_OK: strict warning flags gated per compiler")

elseif(SCENARIO STREQUAL "warnings_off")
  cpp_library(TARGET HygieneWarnOff WARNINGS off SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts HygieneWarnOff COMPILE_OPTIONS)
  foreach(_expected
      "$<$<CXX_COMPILER_ID:MSVC>:/W0>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-w>")
    if(NOT "${_expected}" IN_LIST _copts)
      message(FATAL_ERROR "warnings_off: expected '${_expected}' in COMPILE_OPTIONS: ${_copts}")
    endif()
  endforeach()
  message(FATAL_ERROR "WARNINGS_OFF_OK: off silences warnings per compiler")

elseif(SCENARIO STREQUAL "warnings_invalid")
  # An unknown level must fail fast with a clear message.
  cpp_library(TARGET HygieneBad WARNINGS loud SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  message(FATAL_ERROR "warnings_invalid: expected a FATAL_ERROR for an invalid WARNINGS level")

elseif(SCENARIO STREQUAL "werror")
  cpp_library(TARGET HygieneWerror WERROR SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts HygieneWerror COMPILE_OPTIONS)
  foreach(_expected
      "$<$<CXX_COMPILER_ID:MSVC>:/WX>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Werror>")
    if(NOT "${_expected}" IN_LIST _copts)
      message(FATAL_ERROR "werror: expected '${_expected}' in COMPILE_OPTIONS: ${_copts}")
    endif()
  endforeach()
  message(FATAL_ERROR "WERROR_OK: warnings-as-errors gated per compiler")

elseif(SCENARIO STREQUAL "sanitizers")
  cpp_library(TARGET HygieneSan SANITIZERS address undefined
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  _get_opts(_copts HygieneSan COMPILE_OPTIONS)
  _get_opts(_lopts HygieneSan LINK_OPTIONS)
  # GCC/Clang: same -fsanitize flag on compile AND link.
  set(_gnu "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=address,undefined>")
  if(NOT "${_gnu}" IN_LIST _copts)
    message(FATAL_ERROR "sanitizers: expected '${_gnu}' in COMPILE_OPTIONS: ${_copts}")
  endif()
  if(NOT "${_gnu}" IN_LIST _lopts)
    message(FATAL_ERROR "sanitizers: expected '${_gnu}' in LINK_OPTIONS: ${_lopts}")
  endif()
  # MSVC: only the address sanitizer, compile-only, and gated to non-Debug configs (Debug's
  # /RTC1 and this library's /ZI are incompatible with /fsanitize=address).
  if(NOT "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<NOT:$<CONFIG:Debug>>>:/fsanitize=address>" IN_LIST _copts)
    message(FATAL_ERROR "sanitizers: expected non-Debug-gated MSVC /fsanitize=address in COMPILE_OPTIONS: ${_copts}")
  endif()
  message(FATAL_ERROR "SANITIZERS_OK: sanitizers on compile+link (GCC/Clang) and MSVC ASan")

elseif(SCENARIO STREQUAL "lto")
  # LTO uses check_ipo_supported(); assert the property is ON when IPO is supported and
  # absent (skipped) when it is not, so the test is robust on any toolchain.
  include(CheckIPOSupported)
  check_ipo_supported(RESULT _ipo_ok OUTPUT _ipo_err LANGUAGES CXX)
  cpp_library(TARGET HygieneLto LTO SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}")
  get_target_property(_ipo HygieneLto INTERPROCEDURAL_OPTIMIZATION)
  if(_ipo_ok)
    if(NOT _ipo)
      message(FATAL_ERROR "lto: IPO is supported but INTERPROCEDURAL_OPTIMIZATION was not set")
    endif()
  else()
    if(_ipo)
      message(FATAL_ERROR "lto: INTERPROCEDURAL_OPTIMIZATION set despite unsupported IPO")
    endif()
  endif()
  message(FATAL_ERROR "LTO_OK: interprocedural optimization gated on check_ipo_supported")

elseif(SCENARIO STREQUAL "interface_warns")
  # The knobs are compile/link settings; on a header-only INTERFACE library they must be
  # reported as ignored (consistent with issue #13), not applied.
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/hygiene.h" "#pragma once\nint hdr_only();\n")
  cpp_library(TARGET HygieneHeaderOnly
    HEADERS "${CMAKE_CURRENT_BINARY_DIR}/hygiene.h"
    HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    WARNINGS strict
    WERROR
    SANITIZERS address
    LTO)
  message(FATAL_ERROR "interface_warns: expected an ignored-argument warning, not this")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
