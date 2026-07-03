# Configure-mode regression test for MSVC compile/link flag injection (issue #5).
#
# cpp_target used to inject /ZI (edit-and-continue debug info) and /SAFESEH:NO
# unconditionally on MSVC. /ZI de-optimizes Release builds and is only valid on x86/x64;
# /SAFESEH:NO is an x86-only linker option (a silent no-op on x64, invalid on ARM64).
# cpp_target now scopes these flags. This test creates a library target and inspects its
# COMPILE_OPTIONS / LINK_OPTIONS to assert the scoping.
#
# On non-MSVC toolchains (the Linux/macOS CI legs) the MSVC block is skipped, so the test
# asserts none of the flags are present. The edit-and-continue opt-out is covered by a
# second CTest entry that configures this project with -DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetMsvcFlags LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A real translation unit in the build tree; SOURCE_DIR points there so source_group(TREE)
# is happy and the target is a normal (non-INTERFACE) library that receives the flags.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/flaglib.cpp")
file(WRITE "${_src}" "int flaglib_symbol() { return 0; }\n")

cpp_library(
  TARGET FlagLib
  SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  SOURCES "${_src}"
)

# An executable exercises the /SAFESEH:NO path, which applies only to linked images
# (executables and shared libraries), never to static libraries.
set(_main "${CMAKE_CURRENT_BINARY_DIR}/flagapp.cpp")
file(WRITE "${_main}" "int main() { return 0; }\n")
cpp_binary(
  TARGET FlagApp
  SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  SOURCES "${_main}"
)

get_target_property(_copts FlagLib COMPILE_OPTIONS)
if(NOT _copts)
  set(_copts "")
endif()
get_target_property(_lopts FlagLib LINK_OPTIONS)
if(NOT _lopts)
  set(_lopts "")
endif()
get_target_property(_applopts FlagApp LINK_OPTIONS)
if(NOT _applopts)
  set(_applopts "")
endif()

message(STATUS "FlagLib COMPILE_OPTIONS: ${_copts}")
message(STATUS "FlagLib LINK_OPTIONS: ${_lopts}")
message(STATUS "FlagApp LINK_OPTIONS: ${_applopts}")
message(STATUS "Architecture id: ${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")

if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
  # /utf-8 is always injected.
  if(NOT "/utf-8" IN_LIST _copts)
    message(FATAL_ERROR "expected /utf-8 in COMPILE_OPTIONS: ${_copts}")
  endif()

  # /ZI must never appear as a bare (all-configuration) option -- that is the Release
  # de-optimization bug. It is only ever permitted inside a Debug generator expression.
  if("/ZI" IN_LIST _copts)
    message(FATAL_ERROR "/ZI injected unconditionally (would de-optimize Release): ${_copts}")
  endif()

  if(TARGETS_MSVC_EDIT_AND_CONTINUE
     AND NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(ARM|ARM64|ARM64EC)$")
    if(NOT "$<$<CONFIG:Debug>:/ZI>" IN_LIST _copts)
      message(FATAL_ERROR "expected Debug-gated /ZI generator expression in COMPILE_OPTIONS: ${_copts}")
    endif()
  else()
    # Opted out or ARM/ARM64: /ZI must be absent in every form.
    if(_copts MATCHES "/ZI")
      message(FATAL_ERROR "/ZI present despite opt-out or non-x86/x64 arch: ${_copts}")
    endif()
  endif()

  # /SAFESEH:NO is x86-only and applies only to linked images (exe/DLL), never to a
  # static library. On non-x86 it must be absent everywhere.
  if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "X86")
    if(NOT "/SAFESEH:NO" IN_LIST _applopts)
      message(FATAL_ERROR "expected /SAFESEH:NO on x86 executable: ${_applopts}")
    endif()
    if(_lopts MATCHES "SAFESEH")
      message(FATAL_ERROR "/SAFESEH:NO must not be applied to a static library: ${_lopts}")
    endif()
  else()
    if(_lopts MATCHES "SAFESEH" OR _applopts MATCHES "SAFESEH")
      message(FATAL_ERROR
        "/SAFESEH:NO must not be injected on non-x86 arch "
        "(${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}): lib=${_lopts} app=${_applopts}")
    endif()
  endif()
else()
  # Non-MSVC toolchains must receive none of these MSVC-only flags.
  if(_copts MATCHES "/ZI" OR _copts MATCHES "/utf-8")
    message(FATAL_ERROR "MSVC-only compile flags leaked to non-MSVC toolchain: ${_copts}")
  endif()
  if(_lopts MATCHES "SAFESEH")
    message(FATAL_ERROR "MSVC-only link flags leaked to non-MSVC toolchain: ${_lopts}")
  endif()
endif()

message(STATUS "cpp_target MSVC flags test passed (issue #5)")
