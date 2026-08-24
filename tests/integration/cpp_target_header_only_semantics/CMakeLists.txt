# Configure-mode regression tests for what cpp_target() applies to a header-only library --
# one with public files and no private translation unit.
#
# Such a library is a compiled target like any other: it archives the shipped placeholder
# translation unit, so every argument that describes a compile step or a built artifact
# means something on it. Two scenarios cover the two halves of that: "apply" pins the
# settings that reach the target itself, and "private_applies" pins that PRIVATE
# usage-requirements reach its own compile step without leaking into what consumers see.
#
# A single scenario is selected via -DSCENARIO=... . Both configure cleanly on success and
# FATAL_ERROR on any missing or leaked value, so the exit code decides the CTest.
#
# CXX is enabled because the target is compiled: the placeholder TU needs a real compiler.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetHeaderOnlySemantics LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

if(SCENARIO STREQUAL "apply")
  # PUBLIC usage-requirements, plus the settings that describe the target itself: FOLDER, a
  # user PROPERTY, VERSION, a precompiled header and a unity build. All must be applied.
  add_library(PublicDep INTERFACE)
  cpp_library(
    TARGET HeaderOnlyLib
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
    VERSION "1.2.3"
    PRECOMPILE_HEADERS "${CMAKE_CURRENT_LIST_DIR}/Include/iface.h"
    UNITY_BUILD
  )

  get_target_property(_type HeaderOnlyLib TYPE)
  if(NOT _type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "apply: expected STATIC_LIBRARY, got '${_type}'")
  endif()

  get_target_property(_folder HeaderOnlyLib FOLDER)
  if(NOT _folder STREQUAL "TestGroup/Sub")
    message(FATAL_ERROR "apply: FOLDER not applied, got '${_folder}'")
  endif()

  get_target_property(_incs HeaderOnlyLib INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT _incs MATCHES "public_inc")
    message(FATAL_ERROR "apply: PUBLIC include missing from INTERFACE_INCLUDE_DIRECTORIES: '${_incs}'")
  endif()

  get_target_property(_defs HeaderOnlyLib INTERFACE_COMPILE_DEFINITIONS)
  if(NOT _defs MATCHES "IFACE_PUBLIC_DEF")
    message(FATAL_ERROR "apply: PUBLIC definition missing from INTERFACE_COMPILE_DEFINITIONS: '${_defs}'")
  endif()

  get_target_property(_libs HeaderOnlyLib INTERFACE_LINK_LIBRARIES)
  if(NOT _libs MATCHES "PublicDep")
    message(FATAL_ERROR "apply: PUBLIC dependency missing from INTERFACE_LINK_LIBRARIES: '${_libs}'")
  endif()

  get_target_property(_prop HeaderOnlyLib MY_TEST_PROP)
  if(NOT _prop STREQUAL "hello")
    message(FATAL_ERROR "apply: user PROPERTY not applied, got '${_prop}'")
  endif()

  get_target_property(_version HeaderOnlyLib VERSION)
  if(NOT _version STREQUAL "1.2.3")
    message(FATAL_ERROR "apply: VERSION not applied, got '${_version}'")
  endif()

  get_target_property(_pch HeaderOnlyLib PRECOMPILE_HEADERS)
  if(NOT _pch MATCHES "iface\\.h")
    message(FATAL_ERROR "apply: PRECOMPILE_HEADERS not applied, got '${_pch}'")
  endif()

  get_target_property(_unity HeaderOnlyLib UNITY_BUILD)
  if(NOT _unity)
    message(FATAL_ERROR "apply: UNITY_BUILD not applied, got '${_unity}'")
  endif()

  message(STATUS "cpp_target header-only apply test passed")
elseif(SCENARIO STREQUAL "private_applies")
  # PRIVATE usage-requirements describe the target's own compile step, which a header-only
  # library has. Each must land on the target and none may reach the INTERFACE_* properties
  # a consumer reads.
  add_library(PrivateDep INTERFACE)
  cpp_library(
    TARGET HeaderOnlyPrivateLib
    HEADERS iface.h
    INCLUDES
      PRIVATE "${CMAKE_CURRENT_LIST_DIR}/private_inc"
    DEFINITIONS
      PRIVATE IFACE_PRIVATE_DEF=1
    DEPENDENCIES
      PRIVATE PrivateDep
  )

  get_target_property(_incs HeaderOnlyPrivateLib INCLUDE_DIRECTORIES)
  if(NOT _incs MATCHES "private_inc")
    message(FATAL_ERROR
      "private_applies: PRIVATE include missing from INCLUDE_DIRECTORIES: '${_incs}'")
  endif()

  get_target_property(_defs HeaderOnlyPrivateLib COMPILE_DEFINITIONS)
  if(NOT _defs MATCHES "IFACE_PRIVATE_DEF")
    message(FATAL_ERROR
      "private_applies: PRIVATE definition missing from COMPILE_DEFINITIONS: '${_defs}'")
  endif()

  get_target_property(_libs HeaderOnlyPrivateLib LINK_LIBRARIES)
  if(NOT _libs MATCHES "PrivateDep")
    message(FATAL_ERROR
      "private_applies: PRIVATE dependency missing from LINK_LIBRARIES: '${_libs}'")
  endif()

  get_target_property(_iface_incs HeaderOnlyPrivateLib INTERFACE_INCLUDE_DIRECTORIES)
  if(_iface_incs MATCHES "private_inc")
    message(FATAL_ERROR
      "private_applies: PRIVATE include leaked to consumers: '${_iface_incs}'")
  endif()

  get_target_property(_iface_defs HeaderOnlyPrivateLib INTERFACE_COMPILE_DEFINITIONS)
  if(_iface_defs MATCHES "IFACE_PRIVATE_DEF")
    message(FATAL_ERROR
      "private_applies: PRIVATE definition leaked to consumers: '${_iface_defs}'")
  endif()

  # CMake records a static library's PRIVATE dependency in INTERFACE_LINK_LIBRARIES wrapped
  # in $<LINK_ONLY:...>, so it still reaches the final link without carrying its usage
  # requirements to consumers. An unwrapped entry would be the leak.
  get_target_property(_iface_libs HeaderOnlyPrivateLib INTERFACE_LINK_LIBRARIES)
  if(_iface_libs MATCHES "PrivateDep" AND NOT _iface_libs MATCHES "LINK_ONLY:PrivateDep")
    message(FATAL_ERROR
      "private_applies: PRIVATE dependency leaked to consumers unwrapped: '${_iface_libs}'")
  endif()

  message(STATUS "cpp_target header-only PRIVATE usage-requirement test passed")
else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
