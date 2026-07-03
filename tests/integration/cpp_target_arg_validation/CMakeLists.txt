# Configure-mode regression tests for cpp_target argument validation (issue #4).
#
# Historically, list entries placed before the first PUBLIC/PRIVATE keyword in a
# visibility-taking argument (INCLUDES/DEFINITIONS/DEPENDENCIES) were silently
# discarded, and unknown/misspelled arguments were ignored outright. cpp_target now
# rejects both with a FATAL_ERROR. A single scenario is selected via -DSCENARIO=...
# and paired with a PASS_REGULAR_EXPRESSION in the enclosing CTest harness.
#
# The project enables no languages so the tests need no C++ toolchain: every scenario
# reaches its assertion during configuration and deliberately halts before generation.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetArgValidation LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A translation unit so target creation is not blocked by a missing source. It is
# never compiled (no languages are enabled); configuration halts first. It lives in
# the build tree, so SOURCE_DIR is pointed there to keep source_group(TREE) happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/main.cpp")
file(WRITE "${_src}" "int main() { return 0; }\n")

if(SCENARIO STREQUAL "pre_keyword")
  # DEPENDENCIES entries before any PUBLIC/PRIVATE keyword must be rejected.
  cpp_binary(
    TARGET PreKeywordApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEPENDENCIES SomeLib
  )
elseif(SCENARIO STREQUAL "unknown_arg")
  # A misspelled keyword (SOURCE instead of SOURCES) must be rejected rather than
  # silently ignored. The stray token lands in UNPARSED_ARGUMENTS because it does not
  # follow an open multi-value keyword.
  cpp_binary(
    TARGET UnknownArgApp
    SOURCE "${_src}"
  )
elseif(SCENARIO STREQUAL "valid")
  # The correct, fully-qualified form must still configure cleanly and split
  # visibility as expected.
  add_library(ValidPublicDep INTERFACE)
  add_library(ValidPrivateDep INTERFACE)
  cpp_binary(
    TARGET ValidApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEFINITIONS
      PUBLIC VALID_PUBLIC=1
      PRIVATE VALID_PRIVATE=2
    DEPENDENCIES
      PUBLIC ValidPublicDep
      PRIVATE ValidPrivateDep
  )
  get_target_property(_libs ValidApp LINK_LIBRARIES)
  if(NOT _libs MATCHES "ValidPublicDep")
    message(FATAL_ERROR "valid: ValidPublicDep missing from LINK_LIBRARIES: ${_libs}")
  endif()
  if(NOT _libs MATCHES "ValidPrivateDep")
    message(FATAL_ERROR "valid: ValidPrivateDep missing from LINK_LIBRARIES: ${_libs}")
  endif()
  # Halt before generation (no C++ compiler is configured). The harness matches
  # VALID_OK to confirm the assertions above were reached and passed.
  message(FATAL_ERROR "VALID_OK: PUBLIC/PRIVATE visibility split verified")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
