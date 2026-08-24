# Configure-mode regression tests for cpp_target argument validation (issues #4 and #66).
#
# Historically, list entries placed before the first PUBLIC/PRIVATE keyword in a
# visibility-taking argument (INCLUDES/DEFINITIONS/DEPENDENCIES) were silently
# discarded, and unknown/misspelled arguments were ignored outright. cpp_target now
# rejects both with a FATAL_ERROR.
#
# SOURCES is the one list that also accepts values outside a PUBLIC/PRIVATE group, because
# the bare list is the deprecated spelling it has to keep honoring. The two readings are
# told apart by the first entry alone, so a list that opens bare and names an access keyword
# later is neither. The scenarios below pin that rejection, the rejection of a call that
# spells its public files both ways at once, and that each accepted spelling resolves what
# it was given.
#
# A single scenario is selected via -DSCENARIO=... and paired with a
# PASS_REGULAR_EXPRESSION in the enclosing CTest harness.
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

# A public header, and a source file consumers include -- the template-implementation case
# that keeps a .cpp legal under PUBLIC. Both are passed as absolute paths, so the SOURCES
# scenarios turn on the spelling alone and not on the base directories, which
# tests/integration/cpp_target_source_group covers.
set(_hdr "${CMAKE_CURRENT_BINARY_DIR}/pub.hpp")
file(WRITE "${_hdr}" "#pragma once\nint pub();\n")
set(_tmpl "${CMAKE_CURRENT_BINARY_DIR}/tmpl.cpp")
file(WRITE "${_tmpl}" "template <typename T> T identity(T v) { return v; }\n")

# Assert that TARGET's file list holds every trailing path. CONTEXT names the scenario in
# the diagnostic, and is also what the harness matches to tell a tripped assertion from the
# scenario's own halt.
function(assert_target_files TARGET CONTEXT)
  get_target_property(files ${TARGET} SOURCES)
  foreach(expected IN LISTS ARGN)
    if(NOT "${expected}" IN_LIST files)
      message(FATAL_ERROR
        "${CONTEXT}: '${expected}' is missing from ${TARGET}'s SOURCES: ${files}")
    endif()
  endforeach()
endfunction()

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
elseif(SCENARIO STREQUAL "sources_mixed")
  # A SOURCES list that opens bare and then names PUBLIC belongs to neither spelling: read
  # as a bare list the keyword becomes a file name, read as a grouped one the entries ahead
  # of it are what issue #4 rejects.
  cpp_binary(
    TARGET MixedSourcesApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES
      "${_src}"
      PUBLIC "${_hdr}"
  )
  message(FATAL_ERROR "sources_mixed: a half-grouped SOURCES list was accepted")
elseif(SCENARIO STREQUAL "sources_grouped_with_headers")
  # Grouped SOURCES and HEADERS are two spellings of the same public file list, and nothing
  # in the call says which one the author meant to keep.
  cpp_binary(
    TARGET GroupedAndHeadersApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES
      PRIVATE "${_src}"
    HEADERS "${_hdr}"
  )
  message(FATAL_ERROR
    "sources_grouped_with_headers: both spellings in one call were accepted")
elseif(SCENARIO STREQUAL "sources_legacy")
  # The deprecated spelling must keep resolving both lists exactly as it did.
  cpp_binary(
    TARGET LegacySourcesApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    HEADERS "${_hdr}"
  )
  assert_target_files(LegacySourcesApp "sources_legacy" "${_src}" "${_hdr}")
  message(FATAL_ERROR "LEGACY_SOURCES_OK: the bare spelling still resolves both lists")
elseif(SCENARIO STREQUAL "legacy_volume")
  # Two targets on the deprecated spelling, so legacy_warning_volume.cmake can count how
  # many reports one configure produces. Nothing here asserts that count -- a configure
  # cannot see its own diagnostics -- so this scenario only has to reach its halt.
  cpp_binary(
    TARGET LegacyVolumeAppOne
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
  )
  cpp_binary(
    TARGET LegacyVolumeAppTwo
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
  )
  message(FATAL_ERROR "LEGACY_VOLUME_OK: two targets used the deprecated spelling")
elseif(SCENARIO STREQUAL "sources_grouped")
  # The grouped spelling must reach the same place, and must not report itself deprecated.
  cpp_binary(
    TARGET GroupedSourcesApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES
      PUBLIC "${_hdr}"
      PRIVATE "${_src}"
  )
  assert_target_files(GroupedSourcesApp "sources_grouped" "${_src}" "${_hdr}")
  message(FATAL_ERROR "GROUPED_SOURCES_OK: the grouped spelling resolves both groups")
elseif(SCENARIO STREQUAL "sources_public_on_executable")
  # An executable has no public interface, but the grammar is the same everywhere: PUBLIC
  # entries are taken without a diagnostic, and a source file is as legal under PUBLIC as a
  # header is.
  cpp_binary(
    TARGET PublicOnExecutableApp
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES
      PUBLIC "${_hdr}" "${_tmpl}"
      PRIVATE "${_src}"
  )
  assert_target_files(
    PublicOnExecutableApp "sources_public_on_executable" "${_src}" "${_hdr}" "${_tmpl}")
  message(FATAL_ERROR
    "PUBLIC_ON_EXECUTABLE_OK: an executable takes PUBLIC files without complaint")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
