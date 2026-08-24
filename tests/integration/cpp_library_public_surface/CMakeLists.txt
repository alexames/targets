# Configure-mode tests for the rule that a library must offer consumers something.
#
# A library with no public surface and no translation unit of its own archives only the
# placeholder translation unit, so linking it cannot affect a consumer in any configuration;
# cpp_library rejects it. A library with private translation units and no public surface is a
# different case and stays legal, because its object code is a contribution in itself.
#
# Every public surface is checked on its own, because each is an independent path to
# false-rejecting a working library: one missed surface turns a legitimate declaration into a
# configure error. A single scenario is selected via -DSCENARIO=... and paired with
# PASS_REGULAR_EXPRESSION and FAIL_REGULAR_EXPRESSION in the enclosing CTest harness.
#
# The rejection scenarios print a marker after the rule returns. A FATAL_ERROR never reaches
# it, so the enclosing harness fails on that marker: the test then distinguishes a rejection
# from a diagnostic that was demoted to a warning, which a PASS pattern alone cannot do
# because CTest ignores the exit code once one is set.
#
# No language is enabled, so no toolchain is needed and generation is never reached: a target
# created here has no linker language and would fail to generate. Each accepting scenario
# therefore asserts that its target exists rather than relying on reaching the end of the
# file, so the test measures that the rule accepted the declaration and not merely that
# nothing aborted before the marker.

cmake_minimum_required(VERSION 3.20)
project(TestCppLibraryPublicSurface LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# Separate private and public roots, so an entry resolved against the wrong base would name a
# file that is not there. The files live in the build tree to keep source_group(TREE) happy.
set(_private_dir "${CMAKE_CURRENT_BINARY_DIR}/private")
set(_public_dir "${CMAKE_CURRENT_BINARY_DIR}/public")
set(_include_dir "${CMAKE_CURRENT_BINARY_DIR}/extra_include")
file(WRITE "${_private_dir}/impl.cpp" "int impl() { return 1; }\n")
file(WRITE "${_private_dir}/detail.hpp" "#pragma once\nint impl();\n")
file(WRITE "${_public_dir}/pub.hpp" "#pragma once\nint pub();\n")
file(MAKE_DIRECTORY "${_include_dir}")

# A dependency for the PUBLIC DEPENDENCIES scenario. It carries a translation unit of its own,
# so it satisfies the rule independently and cannot be what the scenario is measuring.
cpp_library(
  TARGET PublicSurfaceDep
  SOURCE_DIR "${_private_dir}"
  SOURCES
    PRIVATE
      "impl.cpp"
)

if(SCENARIO STREQUAL "inert_empty")
  # No files, no usage requirements: nothing to compile and nothing exposed.
  cpp_library(TARGET InertEmpty)
  message(STATUS "inert_empty: REACHED_END")

elseif(SCENARIO STREQUAL "inert_private_header")
  # A private header is not a translation unit and is not visible to consumers, so a library
  # holding only one is inert.
  cpp_library(
    TARGET InertPrivateHeader
    SOURCE_DIR "${_private_dir}"
    SOURCES
      PRIVATE
        "detail.hpp"
  )
  message(STATUS "inert_private_header: REACHED_END")

elseif(SCENARIO STREQUAL "private_tu")
  # Object code with no exposed interface is a legitimate library: symbols may be declared by
  # another target's header, or registered by a static initializer.
  cpp_library(
    TARGET PrivateTuOnly
    SOURCE_DIR "${_private_dir}"
    SOURCES
      PRIVATE
        "impl.cpp"
  )
  if(NOT TARGET PrivateTuOnly)
    message(FATAL_ERROR "PrivateTuOnly was not created")
  endif()
  message(STATUS "PRIVATE_TU_OK")

elseif(SCENARIO STREQUAL "public_file")
  cpp_library(
    TARGET PublicFileOnly
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        "pub.hpp"
  )
  if(NOT TARGET PublicFileOnly)
    message(FATAL_ERROR "PublicFileOnly was not created")
  endif()
  message(STATUS "PUBLIC_FILE_OK")

elseif(SCENARIO STREQUAL "public_dependencies")
  cpp_library(
    TARGET PublicDepsOnly
    DEPENDENCIES
      PUBLIC
        PublicSurfaceDep
  )
  if(NOT TARGET PublicDepsOnly)
    message(FATAL_ERROR "PublicDepsOnly was not created")
  endif()
  message(STATUS "PUBLIC_DEPENDENCIES_OK")

elseif(SCENARIO STREQUAL "public_includes")
  cpp_library(
    TARGET PublicIncludesOnly
    INCLUDES
      PUBLIC
        "${_include_dir}"
  )
  if(NOT TARGET PublicIncludesOnly)
    message(FATAL_ERROR "PublicIncludesOnly was not created")
  endif()
  message(STATUS "PUBLIC_INCLUDES_OK")

elseif(SCENARIO STREQUAL "public_definitions")
  cpp_library(
    TARGET PublicDefinitionsOnly
    DEFINITIONS
      PUBLIC
        PUBLIC_SURFACE_FLAG=1
  )
  if(NOT TARGET PublicDefinitionsOnly)
    message(FATAL_ERROR "PublicDefinitionsOnly was not created")
  endif()
  message(STATUS "PUBLIC_DEFINITIONS_OK")

elseif(SCENARIO STREQUAL "public_copts")
  cpp_library(
    TARGET PublicCoptsOnly
    COPTS
      PUBLIC
        "-DFromCopts"
  )
  if(NOT TARGET PublicCoptsOnly)
    message(FATAL_ERROR "PublicCoptsOnly was not created")
  endif()
  message(STATUS "PUBLIC_COPTS_OK")

elseif(SCENARIO STREQUAL "public_linkopts")
  cpp_library(
    TARGET PublicLinkoptsOnly
    LINKOPTS
      PUBLIC
        "-L/nowhere"
  )
  if(NOT TARGET PublicLinkoptsOnly)
    message(FATAL_ERROR "PublicLinkoptsOnly was not created")
  endif()
  message(STATUS "PUBLIC_LINKOPTS_OK")

elseif(SCENARIO STREQUAL "platform_public_file")
  # A public file behind a sentinel for another platform. The author declared an interface, so
  # the library is accepted here even though nothing survives filtering on this platform.
  cpp_library(
    TARGET PlatformPublicFile
    HEADER_DIR "${_public_dir}"
    SOURCES
      PUBLIC
        LINUX
          "pub.hpp"
  )
  if(NOT TARGET PlatformPublicFile)
    message(FATAL_ERROR "PlatformPublicFile was not created")
  endif()
  message(STATUS "PLATFORM_PUBLIC_FILE_OK")

elseif(SCENARIO STREQUAL "platform_private_tu")
  # A translation unit behind a sentinel for another platform, the shape a single-platform
  # implementation library takes when declared unconditionally.
  cpp_library(
    TARGET PlatformPrivateTu
    SOURCE_DIR "${_private_dir}"
    SOURCES
      PRIVATE
        LINUX
          "impl.cpp"
  )
  if(NOT TARGET PlatformPrivateTu)
    message(FATAL_ERROR "PlatformPrivateTu was not created")
  endif()
  message(STATUS "PLATFORM_PRIVATE_TU_OK")

elseif(SCENARIO STREQUAL "legacy_headers")
  # The deprecated spelling: every HEADERS entry is public, so it is an interface.
  cpp_library(
    TARGET LegacyHeadersOnly
    HEADER_DIR "${_public_dir}"
    HEADERS
      "pub.hpp"
  )
  if(NOT TARGET LegacyHeadersOnly)
    message(FATAL_ERROR "LegacyHeadersOnly was not created")
  endif()
  message(STATUS "LEGACY_HEADERS_OK")

elseif(SCENARIO STREQUAL "platform_legacy_headers")
  # The deprecated spelling behind a sentinel for another platform. Platform filtering empties
  # the list here, so only the raw declaration shows that an interface was declared at all.
  cpp_library(
    TARGET PlatformLegacyHeaders
    HEADER_DIR "${_public_dir}"
    HEADERS
      LINUX
        "pub.hpp"
  )
  if(NOT TARGET PlatformLegacyHeaders)
    message(FATAL_ERROR "PlatformLegacyHeaders was not created")
  endif()
  message(STATUS "PLATFORM_LEGACY_HEADERS_OK")

elseif(SCENARIO STREQUAL "private_dependencies")
  # A private dependency reaches the consumer's link line as a LINK_ONLY usage requirement, so
  # a library that only forwards one is not inert.
  cpp_library(
    TARGET PrivateDepsOnly
    DEPENDENCIES
      PRIVATE
        PublicSurfaceDep
  )
  if(NOT TARGET PrivateDepsOnly)
    message(FATAL_ERROR "PrivateDepsOnly was not created")
  endif()
  message(STATUS "PRIVATE_DEPENDENCIES_OK")

elseif(SCENARIO STREQUAL "binary_nothing_public")
  # A leaf target has no consumers, so having nothing to offer them is not a defect.
  cpp_binary(TARGET NothingPublicBinary)
  if(NOT TARGET NothingPublicBinary)
    message(FATAL_ERROR "NothingPublicBinary was not created")
  endif()
  message(STATUS "BINARY_OK")

else()
  message(FATAL_ERROR "Unknown SCENARIO '${SCENARIO}'")
endif()
