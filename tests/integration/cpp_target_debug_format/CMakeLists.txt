# Configure-mode tests for the MSVC Debug debug-information format.
#
# A single scenario is selected via -DSCENARIO=... . The launcher scenarios set
# CMAKE_CXX_COMPILER_LAUNCHER themselves, after project(), the way
# targets_enable_compiler_cache() does: cpp_target reads it when the target is created, so
# neither a generator that runs launchers nor a launcher that could survive being run is
# needed.
#
# On a non-MSVC toolchain the whole MSVC block is skipped, and every scenario asserts that
# none of these flags leaked there.

cmake_minimum_required(VERSION 3.20)

# CMP0141 decides where the MSVC debug format lives: NEW keeps it in
# MSVC_DEBUG_INFORMATION_FORMAT and out of CMAKE_CXX_FLAGS_DEBUG, OLD leaves a /Zi in those
# flags that only another flag can override. cpp_target has a route for each, so the scenario
# picks the policy here -- project() initializes the configuration flags from it. Asking for
# NEW takes a CMake that knows the policy, which the harness checks before selecting it.
if(DEBUG_FORMAT_POLICY STREQUAL "NEW")
  cmake_policy(SET CMP0141 NEW)
endif()

project(TestCppTargetDebugFormat LANGUAGES CXX)

set(known_scenarios
  launcher_property
  launcher_flags
  launcher_flags_stripped
  launcher_user_format
  launcher_edit_and_continue_off
  no_launcher)
if(NOT "${SCENARIO}" IN_LIST known_scenarios)
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

if(SCENARIO MATCHES "^launcher_")
  # Any non-empty value is a configured launcher as far as cpp_target is concerned, and
  # nothing ever runs this one: the scenario configures and never builds.
  set(CMAKE_CXX_COMPILER_LAUNCHER "${CMAKE_COMMAND}")
else()
  # CMake initializes this from the environment variable of the same name, so a developer
  # with a machine-wide ccache would otherwise trip the launcher-free assertions below.
  set(CMAKE_CXX_COMPILER_LAUNCHER "")
endif()

if(SCENARIO STREQUAL "launcher_user_format")
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "ProgramDatabase")
endif()

if(SCENARIO STREQUAL "launcher_flags_stripped")
  string(REGEX REPLACE "(^| )[/-]Z[iI]( |$)" " " CMAKE_CXX_FLAGS_DEBUG
    "${CMAKE_CXX_FLAGS_DEBUG}")
endif()

set(source "${CMAKE_CURRENT_BINARY_DIR}/dbgfmt.cpp")
file(WRITE "${source}" "int dbgfmt_symbol() { return 0; }\n")

cpp_library(
  TARGET DebugFormatLib
  SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  SOURCES "${source}"
)

get_target_property(options DebugFormatLib COMPILE_OPTIONS)
if(NOT options)
  set(options "")
endif()
get_target_property(format DebugFormatLib MSVC_DEBUG_INFORMATION_FORMAT)
if(NOT format)
  set(format "")
endif()

message(STATUS "DebugFormatLib COMPILE_OPTIONS: ${options}")
message(STATUS "DebugFormatLib MSVC_DEBUG_INFORMATION_FORMAT: ${format}")
message(STATUS "CMAKE_CXX_FLAGS_DEBUG: ${CMAKE_CXX_FLAGS_DEBUG}")

# Assert that nothing asks for edit-and-continue, in any of its spellings: a bare /ZI, a
# Debug-gated one, or the property's EditAndContinue. CONTEXT names the scenario in the
# diagnostic, OPTIONS and FORMAT are the target's inspected values.
function(assert_no_edit_and_continue CONTEXT OPTIONS FORMAT)
  if(OPTIONS MATCHES "/ZI" OR FORMAT MATCHES "EditAndContinue")
    message(FATAL_ERROR
      "${CONTEXT}: edit-and-continue debug info survived a configured compiler launcher: "
      "options=${OPTIONS} format=${FORMAT}")
  endif()
endfunction()

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
  # None of these settings may reach a toolchain other than MSVC, whatever the scenario.
  # CMake initializes the property from CMAKE_MSVC_DEBUG_INFORMATION_FORMAT on every
  # platform, so the scenario that sets that variable must find exactly its own value here.
  if(options MATCHES "/ZI" OR options MATCHES "/Z7"
     OR NOT format STREQUAL "${CMAKE_MSVC_DEBUG_INFORMATION_FORMAT}")
    message(FATAL_ERROR
      "MSVC-only debug-format settings leaked to ${CMAKE_CXX_COMPILER_ID}: "
      "options=${options} format=${format}")
  endif()

elseif(SCENARIO STREQUAL "launcher_property")
  # CMP0141 NEW: the format is the property's to decide, and Debug must read Embedded (/Z7).
  if(NOT format MATCHES "Embedded")
    message(FATAL_ERROR
      "launcher_property: expected Embedded debug info under a compiler launcher, "
      "MSVC_DEBUG_INFORMATION_FORMAT is '${format}'")
  endif()
  # A configuration the property does not name compiles with no debug information at all, so
  # a Debug-only expression would silently strip RelWithDebInfo's.
  if(NOT format MATCHES "RelWithDebInfo")
    message(FATAL_ERROR
      "launcher_property: MSVC_DEBUG_INFORMATION_FORMAT '${format}' leaves RelWithDebInfo "
      "with no debug information")
  endif()
  assert_no_edit_and_continue("launcher_property" "${options}" "${format}")

elseif(SCENARIO STREQUAL "launcher_flags")
  # CMP0141 OLD: CMake spells the format in the configuration flags, out of the property's
  # reach, and only a later flag overrides it.
  if(NOT CMAKE_CXX_FLAGS_DEBUG MATCHES "(^| )[/-]Z[iI]( |$)")
    message(FATAL_ERROR
      "launcher_flags: CMAKE_CXX_FLAGS_DEBUG is '${CMAKE_CXX_FLAGS_DEBUG}', which carries no "
      "debug-info flag for /Z7 to override, so this scenario proves nothing")
  endif()
  if(NOT "$<$<CONFIG:Debug>:/Z7>" IN_LIST options)
    message(FATAL_ERROR
      "launcher_flags: expected a Debug-gated /Z7 in COMPILE_OPTIONS: ${options}")
  endif()
  assert_no_edit_and_continue("launcher_flags" "${options}" "${format}")

elseif(SCENARIO STREQUAL "launcher_flags_stripped")
  # CMP0141 is OLD here whatever the configuration flags say, so the property stays ignored
  # and only an appended flag can move Debug off the format CMake chose.
  if(CMAKE_CXX_FLAGS_DEBUG MATCHES "(^| )[/-]Z[iI]( |$)")
    message(FATAL_ERROR
      "launcher_flags_stripped: CMAKE_CXX_FLAGS_DEBUG is '${CMAKE_CXX_FLAGS_DEBUG}', which "
      "still carries a debug-info flag, so this scenario is not the one it claims to be")
  endif()
  if(NOT "$<$<CONFIG:Debug>:/Z7>" IN_LIST options)
    message(FATAL_ERROR
      "launcher_flags_stripped: expected a Debug-gated /Z7 in COMPILE_OPTIONS: ${options}")
  endif()
  assert_no_edit_and_continue("launcher_flags_stripped" "${options}" "${format}")

elseif(SCENARIO STREQUAL "launcher_user_format")
  # A project that named a format for the whole build keeps it, cacheable or not.
  if(NOT format STREQUAL "${CMAKE_MSVC_DEBUG_INFORMATION_FORMAT}")
    message(FATAL_ERROR
      "launcher_user_format: MSVC_DEBUG_INFORMATION_FORMAT is '${format}', expected the "
      "project's own '${CMAKE_MSVC_DEBUG_INFORMATION_FORMAT}'")
  endif()
  if(options MATCHES "/Z7")
    message(FATAL_ERROR
      "launcher_user_format: /Z7 injected over the project's own debug format: ${options}")
  endif()

elseif(SCENARIO STREQUAL "launcher_edit_and_continue_off")
  # The option only ever governed /ZI, so turning it off does not opt out of the format a
  # cache can serve.
  if(NOT format MATCHES "Embedded")
    message(FATAL_ERROR
      "launcher_edit_and_continue_off: expected Embedded debug info under a compiler "
      "launcher, MSVC_DEBUG_INFORMATION_FORMAT is '${format}'")
  endif()
  assert_no_edit_and_continue("launcher_edit_and_continue_off" "${options}" "${format}")

elseif(SCENARIO STREQUAL "no_launcher")
  # With no launcher configured the edit-and-continue behavior is untouched: /ZI on x86/x64,
  # nothing on ARM, and no claim on the debug format either way.
  if(NOT format STREQUAL "")
    message(FATAL_ERROR
      "no_launcher: MSVC_DEBUG_INFORMATION_FORMAT was set to '${format}' with no compiler "
      "launcher configured")
  endif()
  if(options MATCHES "/Z7")
    message(FATAL_ERROR
      "no_launcher: /Z7 injected with no compiler launcher configured: ${options}")
  endif()
  if(TARGETS_MSVC_EDIT_AND_CONTINUE
     AND NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(ARM|ARM64|ARM64EC)$")
    if(NOT "$<$<CONFIG:Debug>:/ZI>" IN_LIST options)
      message(FATAL_ERROR
        "no_launcher: expected the Debug-gated /ZI generator expression in COMPILE_OPTIONS: "
        "${options}")
    endif()
  elseif(options MATCHES "/ZI")
    message(FATAL_ERROR
      "no_launcher: /ZI present despite opt-out or non-x86/x64 arch: ${options}")
  endif()
endif()
