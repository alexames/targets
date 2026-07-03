# Configure-mode regression tests for cpp_target()'s header-only INTERFACE branch
# (issue #13).
#
# When cpp_library() resolves to an INTERFACE (header-only) library -- HEADERS but no
# SOURCES -- the INTERFACE code path used to apply only the PUBLIC usage-requirements and
# silently drop everything else: PRIVATE includes/definitions/dependencies, FOLDER,
# VERSION/SOVERSION, PROPERTIES, PRECOMPILE_HEADERS, and UNITY_BUILD. cpp_target now:
#   * applies what is valid on an INTERFACE target -- the PUBLIC/INTERFACE
#     usage-requirements, FOLDER, and user PROPERTIES; and
#   * emits a WARNING naming each argument that only applies to a compiled target
#     (PRIVATE usage-requirements, VERSION/SOVERSION, PRECOMPILE_HEADERS, UNITY_BUILD)
#     rather than dropping it silently.
#
# A single scenario is selected via -DSCENARIO=... . The "apply" scenario configures
# cleanly (exit 0) and FATAL_ERRORs if any expected value is missing. The "ignored"
# scenario is paired with a PASS_REGULAR_EXPRESSION in the enclosing CTest harness that
# matches the warning.
#
# CXX is enabled because the INTERFACE branch calls target_compile_features(cxx_std_...),
# which requires a known C++ compiler -- the same reason the issue #7 test enables it.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetInterfaceSemantics LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

if(SCENARIO STREQUAL "apply")
  # A header-only library specifying only things valid on an INTERFACE target: PUBLIC
  # usage-requirements, an explicit FOLDER, and a benign user PROPERTY. All must be
  # applied, and no ignored-argument warning must be triggered.
  add_library(PublicDep INTERFACE)
  cpp_library(
    TARGET IfaceLib
    HEADERS iface.h
    INCLUDES
      PUBLIC "${CMAKE_CURRENT_LIST_DIR}/public_inc"
    DEFINITIONS
      PUBLIC IFACE_PUBLIC_DEF=1
    DEPENDENCIES
      PUBLIC PublicDep
    FOLDER "TestGroup/Sub"
    PROPERTIES
      MY_TEST_PROP hello
  )

  get_target_property(_type IfaceLib TYPE)
  if(NOT _type STREQUAL "INTERFACE_LIBRARY")
    message(FATAL_ERROR "apply: expected INTERFACE_LIBRARY, got '${_type}'")
  endif()

  get_target_property(_folder IfaceLib FOLDER)
  if(NOT _folder STREQUAL "TestGroup/Sub")
    message(FATAL_ERROR "apply: FOLDER not applied to INTERFACE lib, got '${_folder}'")
  endif()

  get_target_property(_incs IfaceLib INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT _incs MATCHES "public_inc")
    message(FATAL_ERROR "apply: PUBLIC include missing from INTERFACE_INCLUDE_DIRECTORIES: '${_incs}'")
  endif()

  get_target_property(_defs IfaceLib INTERFACE_COMPILE_DEFINITIONS)
  if(NOT _defs MATCHES "IFACE_PUBLIC_DEF")
    message(FATAL_ERROR "apply: PUBLIC definition missing from INTERFACE_COMPILE_DEFINITIONS: '${_defs}'")
  endif()

  get_target_property(_libs IfaceLib INTERFACE_LINK_LIBRARIES)
  if(NOT _libs MATCHES "PublicDep")
    message(FATAL_ERROR "apply: PUBLIC dependency missing from INTERFACE_LINK_LIBRARIES: '${_libs}'")
  endif()

  get_target_property(_prop IfaceLib MY_TEST_PROP)
  if(NOT _prop STREQUAL "hello")
    message(FATAL_ERROR "apply: user PROPERTY not applied to INTERFACE lib, got '${_prop}'")
  endif()

  # Configures cleanly on success; the harness treats exit 0 as a pass.
  message(STATUS "cpp_target INTERFACE apply test passed (issue #13)")
elseif(SCENARIO STREQUAL "ignored")
  # A header-only library specifying arguments that only apply to a compiled target. Each
  # must be reported by a single warning rather than dropped silently. The warning is
  # non-fatal, so configuration still completes.
  add_library(PrivateDep INTERFACE)
  cpp_library(
    TARGET IfaceIgnoredLib
    HEADERS iface.h
    DEPENDENCIES
      PRIVATE PrivateDep
    VERSION "1.2.3"
    PRECOMPILE_HEADERS iface.h
    UNITY_BUILD
  )

  # The ignored PRIVATE dependency must not have leaked onto the INTERFACE target.
  get_target_property(_libs IfaceIgnoredLib INTERFACE_LINK_LIBRARIES)
  if(_libs AND _libs MATCHES "PrivateDep")
    message(FATAL_ERROR
      "ignored: PRIVATE dependency must not be applied to an INTERFACE lib: '${_libs}'")
  endif()
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
