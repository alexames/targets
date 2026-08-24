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
#
# The scenarios whose name carries "lto" add a second library that opts into LTO, because
# /GL and /ZI cannot appear on one compile line: they pin which of the two stands down, and
# that a cache configured on top of LTO still leaves one debug format in force.

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
  launcher_lto
  launcher_lto_property
  lto
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

# The LTO scenarios put an opted-in library beside the plain one above: edit-and-continue
# has to stand down on the target carrying /GL and stay on its neighbour.
if(SCENARIO MATCHES "lto")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT ipo_supported OUTPUT ipo_unsupported_reason LANGUAGES CXX)
  cpp_library(
    TARGET DebugFormatLtoLib
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${source}"
    LTO
  )
  get_target_property(lto_options DebugFormatLtoLib COMPILE_OPTIONS)
  if(NOT lto_options)
    set(lto_options "")
  endif()
  get_target_property(lto_format DebugFormatLtoLib MSVC_DEBUG_INFORMATION_FORMAT)
  if(NOT lto_format)
    set(lto_format "")
  endif()
  get_target_property(lto_ipo DebugFormatLtoLib INTERPROCEDURAL_OPTIMIZATION)
  if(NOT lto_ipo)
    set(lto_ipo "")
  endif()
  message(STATUS "DebugFormatLtoLib COMPILE_OPTIONS: ${lto_options}")
  message(STATUS "DebugFormatLtoLib MSVC_DEBUG_INFORMATION_FORMAT: ${lto_format}")
  message(STATUS "DebugFormatLtoLib INTERPROCEDURAL_OPTIMIZATION: ${lto_ipo}")
endif()

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

# The single form in which cpp_target may ask for edit-and-continue: Debug, and only where
# the target is not compiled with whole-program optimization, read the way CMake reads it --
# the per-config property wherever it has a value, the plain one otherwise. cl.exe rejects
# /ZI together with /GL (D8016), so any other entry naming /ZI is one a target with
# interprocedural optimization could still be handed.
set(per_config "$<TARGET_PROPERTY:INTERPROCEDURAL_OPTIMIZATION_DEBUG>")
string(CONCAT whole_program
  "$<IF:$<STREQUAL:${per_config},>,"
  "$<BOOL:$<TARGET_PROPERTY:INTERPROCEDURAL_OPTIMIZATION>>,"
  "$<BOOL:${per_config}>>")
set(guarded_edit_and_continue "$<$<AND:$<CONFIG:Debug>,$<NOT:${whole_program}>>:/ZI>")

# Assert that every edit-and-continue entry a target carries is EXPECTED, the guarded form.
# CONTEXT names the scenario and TARGET_NAME the inspected target for the diagnostic;
# OPTIONS is that target's COMPILE_OPTIONS.
function(assert_edit_and_continue_is_guarded CONTEXT TARGET_NAME OPTIONS EXPECTED)
  foreach(entry IN LISTS OPTIONS)
    if(entry MATCHES "/ZI" AND NOT entry STREQUAL "${EXPECTED}")
      message(FATAL_ERROR
        "${CONTEXT}: ${TARGET_NAME} carries an edit-and-continue entry that whole-program "
        "optimization cannot switch off: '${entry}'")
    endif()
  endforeach()
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

  # GCC and Clang spell interprocedural optimization -flto, which conflicts with no debug
  # format, so an LTO target there differs from any other only in the property.
  if(SCENARIO MATCHES "lto")
    if(lto_options MATCHES "/ZI" OR lto_options MATCHES "/Z7"
       OR NOT lto_format STREQUAL "${CMAKE_MSVC_DEBUG_INFORMATION_FORMAT}")
      message(FATAL_ERROR
        "MSVC-only debug-format settings leaked to ${CMAKE_CXX_COMPILER_ID} on the LTO "
        "target: options=${lto_options} format=${lto_format}")
    endif()
    if(ipo_supported AND NOT lto_ipo)
      message(FATAL_ERROR
        "LTO left INTERPROCEDURAL_OPTIMIZATION unset on ${CMAKE_CXX_COMPILER_ID}, which "
        "reports interprocedural optimization as supported")
    endif()
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
    if(NOT "${guarded_edit_and_continue}" IN_LIST options)
      message(FATAL_ERROR
        "no_launcher: expected the guarded /ZI generator expression in COMPILE_OPTIONS: "
        "${options}")
    endif()
  elseif(options MATCHES "/ZI")
    message(FATAL_ERROR
      "no_launcher: /ZI present despite opt-out or non-x86/x64 arch: ${options}")
  endif()

elseif(SCENARIO STREQUAL "lto")
  # Two facts together put /ZI out of the LTO target's reach: the only entry that asks for it
  # stands down where interprocedural optimization is on, and the LTO keyword turns that
  # property on. The plain library beside it keeps edit-and-continue, so what stands down is
  # the target's own flag rather than the whole project's.
  assert_edit_and_continue_is_guarded(
    "lto" DebugFormatLtoLib "${lto_options}" "${guarded_edit_and_continue}")
  assert_edit_and_continue_is_guarded(
    "lto" DebugFormatLib "${options}" "${guarded_edit_and_continue}")
  if(ipo_supported AND NOT lto_ipo)
    message(FATAL_ERROR
      "lto: interprocedural optimization is supported here, but DebugFormatLtoLib does not "
      "carry INTERPROCEDURAL_OPTIMIZATION, so nothing switches /ZI off on it")
  endif()
  if(TARGETS_MSVC_EDIT_AND_CONTINUE
     AND NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(ARM|ARM64|ARM64EC)$")
    if(NOT "${guarded_edit_and_continue}" IN_LIST options)
      message(FATAL_ERROR
        "lto: the library without LTO lost edit-and-continue too: ${options}")
    endif()
  endif()
  # Debug keeps the .pdb debug info CMake gives it by default, which /GL accepts: with no
  # cache to serve, nothing here claims the debug format.
  if(NOT lto_format STREQUAL "")
    message(FATAL_ERROR
      "lto: MSVC_DEBUG_INFORMATION_FORMAT was set to '${lto_format}' with no compiler "
      "launcher configured")
  endif()
  if(lto_options MATCHES "/Z7")
    message(FATAL_ERROR
      "lto: /Z7 injected with no compiler launcher configured: ${lto_options}")
  endif()

elseif(SCENARIO MATCHES "^launcher_lto")
  # A compile cache and LTO on one target resolve to a single answer: the launcher moves
  # Debug to the format a cache can serve, and edit-and-continue is absent for both reasons
  # at once, with no second override layered on top.
  assert_no_edit_and_continue("${SCENARIO}" "${lto_options}" "${lto_format}")
  assert_no_edit_and_continue("${SCENARIO}" "${options}" "${format}")
  if(ipo_supported AND NOT lto_ipo)
    message(FATAL_ERROR
      "${SCENARIO}: interprocedural optimization is supported here, but DebugFormatLtoLib "
      "does not carry INTERPROCEDURAL_OPTIMIZATION")
  endif()
  if(SCENARIO STREQUAL "launcher_lto_property")
    if(NOT lto_format MATCHES "Embedded")
      message(FATAL_ERROR
        "launcher_lto_property: expected Embedded debug info on the LTO target under a "
        "compiler launcher, MSVC_DEBUG_INFORMATION_FORMAT is '${lto_format}'")
    endif()
    if(lto_options MATCHES "/Z7")
      message(FATAL_ERROR
        "launcher_lto_property: /Z7 appended on top of the property that already names the "
        "format: ${lto_options}")
    endif()
  else()
    if(NOT "$<$<CONFIG:Debug>:/Z7>" IN_LIST lto_options)
      message(FATAL_ERROR
        "launcher_lto: expected a Debug-gated /Z7 on the LTO target: ${lto_options}")
    endif()
  endif()
endif()
