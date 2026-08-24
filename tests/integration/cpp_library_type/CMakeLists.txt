# Configure-mode regression tests for the kind of target cpp_library() creates: STATIC vs
# SHARED linkage (issue #14), and whether a library is given the placeholder translation
# unit (issue #66).
#
# STATIC and SHARED select a library's linkage and are mutually exclusive. Passing both
# used to silently build SHARED (the SHARED branch won), even though the EXECUTABLE path
# already rejected the same contradiction. cpp_target now errors on STATIC+SHARED for a
# library too. The positive scenarios pin the preserved behavior: SHARED alone ->
# SHARED_LIBRARY, neither flag -> STATIC_LIBRARY (default).
#
# A library with no PRIVATE translation unit is given the shipped dummy.cpp so that it is a
# compiled target like every other library these rules create; listing a private header
# supplies no translation unit and so does not stand in for one. The two grouped scenarios
# pin both directions of that decision. A single scenario is selected via -DSCENARIO=... and
# paired with a PASS_REGULAR_EXPRESSION in the enclosing CTest harness.
#
# The project enables no languages so the tests need no C++ toolchain: each scenario
# reaches its assertion during configuration and deliberately halts before generation.

cmake_minimum_required(VERSION 3.20)
project(TestCppLibraryType LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# A translation unit for the linkage scenarios. It is never compiled (no languages are
# enabled); configuration halts before generation. It lives in the build tree, so SOURCE_DIR
# is pointed there to keep source_group(TREE) happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/lib.cpp")
file(WRITE "${_src}" "int answer() { return 42; }\n")

# Separate private and public roots for the grouped-spelling scenarios, so an entry
# resolved against the wrong base would name a file that is not there.
set(_private_dir "${CMAKE_CURRENT_BINARY_DIR}/private")
set(_public_dir "${CMAKE_CURRENT_BINARY_DIR}/public")
file(WRITE "${_private_dir}/impl.cpp" "int impl() { return 1; }\n")
file(WRITE "${_private_dir}/detail.hpp" "#pragma once\nint impl();\n")
file(WRITE "${_public_dir}/pub.hpp" "#pragma once\nint pub();\n")
file(WRITE "${_public_dir}/pub_impl.cpp" "int pub() { return 2; }\n")

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
elseif(SCENARIO STREQUAL "public_translation_unit")
  # PUBLIC says where an entry resolves and that consumers see it, not that the file is left
  # out of the build -- which is what makes it the place to declare a template implementation
  # consumers include. A translation unit listed there is compiled.
  cpp_library(
    TARGET PublicTuLib
    SOURCE_DIR "${_private_dir}"
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        pub.hpp
        pub_impl.cpp
  )
  get_target_property(_files PublicTuLib SOURCES)
  if(NOT _files MATCHES "pub_impl\\.cpp")
    message(FATAL_ERROR
      "public_translation_unit: the PUBLIC translation unit is not among the target's "
      "sources, so it would never be compiled: ${_files}")
  endif()
  message(FATAL_ERROR "PUBLIC_TU_OK: a translation unit under PUBLIC is compiled")
elseif(SCENARIO STREQUAL "shared_header_only")
  # Having no translation unit of its own does not make a library's linkage contradictory,
  # so SHARED is honored: the placeholder TU is what gets built into the shared library.
  cpp_library(
    TARGET SharedHeaderOnlyLib
    SHARED
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        pub.hpp
  )
  get_target_property(_type SharedHeaderOnlyLib TYPE)
  if(NOT _type STREQUAL "SHARED_LIBRARY")
    message(FATAL_ERROR "shared_header_only: expected SHARED_LIBRARY, got '${_type}'")
  endif()
  get_target_property(_files SharedHeaderOnlyLib SOURCES)
  if(NOT _files MATCHES "dummy\\.cpp")
    message(FATAL_ERROR
      "shared_header_only: expected the dummy.cpp placeholder TU, got: ${_files}")
  endif()
  message(FATAL_ERROR "SHARED_HEADER_ONLY_OK: SHARED is honored with no translation unit")
elseif(SCENARIO STREQUAL "grouped_header_only")
  # Nothing under PRIVATE is a translation unit, so this is the same header-only library
  # `HEADERS pub.hpp` with no SOURCES produces -- the private header adds no compile step.
  cpp_library(
    TARGET GroupedHeaderOnlyLib
    SOURCE_DIR "${_private_dir}"
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        pub.hpp
      PRIVATE
        detail.hpp
  )
  get_target_property(_type GroupedHeaderOnlyLib TYPE)
  if(NOT _type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "grouped_header_only: expected STATIC_LIBRARY, got '${_type}'")
  endif()
  get_target_property(_files GroupedHeaderOnlyLib SOURCES)
  if(NOT _files MATCHES "dummy\\.cpp")
    message(FATAL_ERROR
      "grouped_header_only: expected the dummy.cpp placeholder TU, got: ${_files}")
  endif()
  message(FATAL_ERROR
    "GROUPED_HEADER_ONLY_OK: private headers alone leave a library with nothing to compile")
elseif(SCENARIO STREQUAL "grouped_static")
  # One PRIVATE translation unit is what makes the placeholder unnecessary.
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
  get_target_property(_files GroupedStaticLib SOURCES)
  if(_files MATCHES "dummy\\.cpp")
    message(FATAL_ERROR
      "grouped_static: a library with a translation unit of its own must not be given the "
      "placeholder: ${_files}")
  endif()
  message(FATAL_ERROR
    "GROUPED_STATIC_OK: a private translation unit stands in for the placeholder")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
