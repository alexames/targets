# Configure-mode regression tests for SHARED-library export ergonomics (issue #21).
#
# cpp_library gained two mutually exclusive symbol-export strategies plus visibility parity:
#
#   * EXPORT_HEADER runs GenerateExportHeader for the target, sets CXX_VISIBILITY_PRESET
#     hidden / VISIBILITY_INLINES_HIDDEN, and puts the generated header's directory on the
#     target's PUBLIC include path.
#   * WINDOWS_EXPORT_ALL_SYMBOLS sets the target property of the same name.
#   * The two together, or either on an executable, are rejected.
#
# A single scenario is selected via -DSCENARIO=... and paired (in the enclosing CTest harness)
# with a PASS_REGULAR_EXPRESSION. Each positive scenario asserts the resulting target
# properties and then halts with a sentinel FATAL_ERROR before generation, so no build is
# needed; the negative scenarios pass iff the expected diagnostic is emitted.
#
# CXX is enabled because GenerateExportHeader probes the compiler; the tiny source below is
# never actually compiled (configuration halts before generation).

cmake_minimum_required(VERSION 3.20)
project(TestCppLibraryExportHeader VERSION 1.0.0 LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A translation unit so the library is a compiled SHARED target (not a header-only INTERFACE
# library) and GenerateExportHeader can infer its linker language. It lives in the build tree,
# so SOURCE_DIR points there to keep source_group(TREE) happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/lib.cpp")
file(WRITE "${_src}" "int answer() { return 42; }\n")

if(SCENARIO STREQUAL "export_header")
  # EXPORT_HEADER must set the visibility presets and add the generated header's directory to
  # the target's PUBLIC include directories.
  cpp_library(
    TARGET ExportHeaderLib
    SHARED
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    EXPORT_HEADER
  )
  get_target_property(_vis ExportHeaderLib CXX_VISIBILITY_PRESET)
  if(NOT _vis STREQUAL "hidden")
    message(FATAL_ERROR "export_header: expected CXX_VISIBILITY_PRESET hidden, got '${_vis}'")
  endif()
  get_target_property(_inl ExportHeaderLib VISIBILITY_INLINES_HIDDEN)
  if(NOT _inl)
    message(FATAL_ERROR "export_header: expected VISIBILITY_INLINES_HIDDEN to be set")
  endif()
  get_target_property(_inc ExportHeaderLib INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT _inc MATCHES "\\.export")
    message(FATAL_ERROR "export_header: generated export-header dir missing from includes: ${_inc}")
  endif()
  message(FATAL_ERROR "EXPORT_HEADER_OK: EXPORT_HEADER wires up GenerateExportHeader")
elseif(SCENARIO STREQUAL "export_all_symbols")
  # WINDOWS_EXPORT_ALL_SYMBOLS must set the identically named target property.
  cpp_library(
    TARGET ExportAllLib
    SHARED
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    WINDOWS_EXPORT_ALL_SYMBOLS
  )
  get_target_property(_all ExportAllLib WINDOWS_EXPORT_ALL_SYMBOLS)
  if(NOT _all)
    message(FATAL_ERROR "export_all_symbols: expected WINDOWS_EXPORT_ALL_SYMBOLS property set")
  endif()
  message(FATAL_ERROR "EXPORT_ALL_OK: WINDOWS_EXPORT_ALL_SYMBOLS sets the property")
elseif(SCENARIO STREQUAL "conflict")
  # The two export strategies are mutually exclusive and must be rejected.
  cpp_library(
    TARGET ConflictLib
    SHARED
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    EXPORT_HEADER
    WINDOWS_EXPORT_ALL_SYMBOLS
  )
elseif(SCENARIO STREQUAL "on_executable")
  # Neither export control is valid on an executable.
  cpp_binary(
    TARGET ExportExe
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    EXPORT_HEADER
  )
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
