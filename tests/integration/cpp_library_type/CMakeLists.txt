# Configure-mode regression tests for the kind of target cpp_library() creates: STATIC vs
# SHARED linkage (issue #14), and compiled vs header-only INTERFACE (issue #66).
#
# STATIC and SHARED select a library's linkage and are mutually exclusive. Passing both
# used to silently build SHARED (the SHARED branch won), even though the EXECUTABLE path
# already rejected the same contradiction. cpp_target now errors on STATIC+SHARED for a
# library too. The positive scenarios pin the preserved behavior: SHARED alone ->
# SHARED_LIBRARY, neither flag -> STATIC_LIBRARY (default).
#
# A library is header-only when it exposes public files and no PRIVATE entry is a
# translation unit, so listing a private header does not make it compiled. The two grouped
# scenarios pin both directions of that decision. A single scenario is selected via
# -DSCENARIO=... and paired with a PASS_REGULAR_EXPRESSION in the enclosing CTest harness.
#
# The project enables no languages so the tests need no C++ toolchain: each scenario
# reaches its assertion during configuration and deliberately halts before generation.

cmake_minimum_required(VERSION 3.20)
project(TestCppLibraryType LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A translation unit so a compiled (STATIC/SHARED) library is not reinterpreted as a
# header-only INTERFACE library. It is never compiled (no languages are enabled);
# configuration halts before generation. It lives in the build tree, so SOURCE_DIR is
# pointed there to keep source_group(TREE) happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/lib.cpp")
file(WRITE "${_src}" "int answer() { return 42; }\n")

# Separate private and public roots for the grouped-spelling scenarios, so an entry
# resolved against the wrong base would name a file that is not there.
set(_private_dir "${CMAKE_CURRENT_BINARY_DIR}/private")
set(_public_dir "${CMAKE_CURRENT_BINARY_DIR}/public")
file(WRITE "${_private_dir}/impl.cpp" "int impl() { return 1; }\n")
file(WRITE "${_private_dir}/detail.hpp" "#pragma once\nint impl();\n")
file(WRITE "${_public_dir}/pub.hpp" "#pragma once\nint pub();\n")

if(SCENARIO STREQUAL "conflict")
  # STATIC and SHARED together are contradictory and must be rejected with a FATAL_ERROR.
  cpp_library(
    TARGET ConflictLib
    STATIC
    SHARED
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
  )
elseif(SCENARIO STREQUAL "shared")
  # SHARED alone must produce a SHARED_LIBRARY.
  cpp_library(
    TARGET SharedLib
    SHARED
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
  )
  get_target_property(_type SharedLib TYPE)
  if(NOT _type STREQUAL "SHARED_LIBRARY")
    message(FATAL_ERROR "shared: expected SHARED_LIBRARY, got '${_type}'")
  endif()
  # Halt before generation (no C++ compiler is configured). The harness matches
  # SHARED_OK to confirm the assertion above was reached and passed.
  message(FATAL_ERROR "SHARED_OK: SHARED selects a SHARED_LIBRARY")
elseif(SCENARIO STREQUAL "default")
  # Neither STATIC nor SHARED must default to a STATIC_LIBRARY.
  cpp_library(
    TARGET DefaultLib
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
  )
  get_target_property(_type DefaultLib TYPE)
  if(NOT _type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "default: expected STATIC_LIBRARY, got '${_type}'")
  endif()
  message(FATAL_ERROR "DEFAULT_OK: no linkage flag defaults to a STATIC_LIBRARY")
elseif(SCENARIO STREQUAL "grouped_interface")
  # Nothing under PRIVATE is a translation unit, so this is the same header-only library
  # `HEADERS pub.hpp` with no SOURCES produces -- the private header adds no compile step.
  cpp_library(
    TARGET GroupedInterfaceLib
    SOURCE_DIR "${_private_dir}"
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        pub.hpp
      PRIVATE
        detail.hpp
  )
  get_target_property(_type GroupedInterfaceLib TYPE)
  if(NOT _type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "grouped_interface: expected INTERFACE_LIBRARY, got '${_type}'")
  endif()
  # The placeholder TU would flip the library to STATIC and change what linking to it means.
  get_target_property(_files GroupedInterfaceLib SOURCES)
  if(_files AND _files MATCHES "dummy\\.cpp")
    message(FATAL_ERROR
      "grouped_interface: an INTERFACE library must not carry the dummy.cpp TU: ${_files}")
  endif()
  message(FATAL_ERROR
    "GROUPED_INTERFACE_OK: private headers alone leave a library header-only")
elseif(SCENARIO STREQUAL "grouped_static")
  # One PRIVATE translation unit is what makes the same library compiled.
  cpp_library(
    TARGET GroupedStaticLib
    SOURCE_DIR "${_private_dir}"
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        pub.hpp
      PRIVATE
        impl.cpp
  )
  get_target_property(_type GroupedStaticLib TYPE)
  if(NOT _type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "grouped_static: expected STATIC_LIBRARY, got '${_type}'")
  endif()
  message(FATAL_ERROR
    "GROUPED_STATIC_OK: a private translation unit makes a library compiled")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
