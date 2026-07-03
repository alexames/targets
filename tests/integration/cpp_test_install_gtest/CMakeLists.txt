# Configure-mode regression test for FetchContent googletest install-tree leakage and
# building as part of ALL (https://github.com/alexames/targets/issues/10).
#
# When Google Test is not found, cpp_test() acquires it via FetchContent. Two hygiene
# requirements the fix must guarantee:
#   1. INSTALL_GTEST must be OFF before FetchContent_MakeAvailable(googletest), so the
#      fetched googletest contributes NO install() rules — otherwise a consumer's
#      `cmake --install` deposits gtest/gmock headers, libraries, and package config into
#      its own install prefix.
#   2. The googletest subdirectory must be added EXCLUDE_FROM_ALL so its targets do not
#      build as part of the default ALL target when no test references them.
#
# Verifying real install rules / ALL membership would need a full network clone plus a
# compiler, which CI deliberately avoids. Instead this test forces the FetchContent branch
# (find_package(GTest) is made to report not-found) and stubs FetchContent's declare/
# make-available commands to observe — network-free, compiler-free — exactly the two
# settings the fix applies: that EXCLUDE_FROM_ALL is passed to FetchContent_Declare and
# that INSTALL_GTEST is defined and OFF at the moment FetchContent_MakeAvailable(googletest)
# runs. A FATAL_ERROR in any assertion fails the test; the sentinel is matched by
# PASS_REGULAR_EXPRESSION.

cmake_minimum_required(VERSION 3.20)
project(TestInstallGTest LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")

# Force the FetchContent fallback branch deterministically, regardless of whether GTest is
# installed on the host: report GTest as not-found and forward every other package to the
# real command. This also keeps the project compiler-free by never letting FindGTest pull
# in FindThreads (which runs try_compile).
macro(find_package _pkg)
  if("${_pkg}" STREQUAL "GTest")
    set(GTest_FOUND FALSE)
  else()
    _find_package(${ARGV})
  endif()
endmacro()

include(Targets)

# Stub FetchContent's two entry points so acquisition runs network-free and creates no
# targets, capturing the arguments/state the fix must guarantee.
function(FetchContent_Declare _name)
  if(_name STREQUAL "googletest")
    set_property(GLOBAL PROPERTY _TEST_GTEST_DECLARE_ARGS "${ARGN}")
  endif()
endfunction()

function(FetchContent_MakeAvailable)
  set_property(GLOBAL PROPERTY _TEST_MAKE_AVAILABLE_CALLED TRUE)
  if(DEFINED INSTALL_GTEST AND NOT INSTALL_GTEST)
    set_property(GLOBAL PROPERTY _TEST_INSTALL_GTEST_OFF TRUE)
  else()
    set_property(GLOBAL PROPERTY _TEST_INSTALL_GTEST_OFF FALSE)
  endif()
  set_property(GLOBAL PROPERTY _TEST_INSTALL_GTEST_RAW "[${INSTALL_GTEST}]")
endfunction()

# FetchContent.cmake has no include guard and redefines its commands on every include, so
# the include(FetchContent) inside _targets_acquire_gtest would overwrite the stubs above.
# Neutralize just that re-include; forward every other include to the real command (the
# helper still needs the real include(GoogleTest) at the end).
macro(include _module)
  if(NOT "${_module}" STREQUAL "FetchContent")
    _include(${ARGV})
  endif()
endmacro()

# Trigger acquisition directly via the private helper — equivalent to the first cpp_test()
# call, without needing real gtest targets to link against.
_targets_acquire_gtest()

get_property(_made GLOBAL PROPERTY _TEST_MAKE_AVAILABLE_CALLED)
if(NOT _made)
  message(FATAL_ERROR
    "FetchContent_MakeAvailable was never reached; the FetchContent fallback branch did "
    "not run, so the install/ALL hygiene settings could not be verified (issue #10).")
endif()

get_property(_install_gtest_off GLOBAL PROPERTY _TEST_INSTALL_GTEST_OFF)
get_property(_install_gtest_raw GLOBAL PROPERTY _TEST_INSTALL_GTEST_RAW)
if(NOT _install_gtest_off)
  message(FATAL_ERROR
    "INSTALL_GTEST must be defined and OFF before FetchContent_MakeAvailable, but was "
    "${_install_gtest_raw}; the fetched googletest would leak install rules into the "
    "consumer's prefix (issue #10).")
endif()

# EXCLUDE_FROM_ALL is only added on CMake >= 3.28 (the version that supports the
# FetchContent_Declare option); assert it there, which is where CI runs. It must also come
# BEFORE the greedy, multi-value FIND_PACKAGE_ARGS keyword, otherwise the real
# FetchContent_Declare would misparse it as a package name rather than an option.
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28")
  get_property(_declare_args GLOBAL PROPERTY _TEST_GTEST_DECLARE_ARGS)
  list(FIND _declare_args "EXCLUDE_FROM_ALL" _exclude_idx)
  if(_exclude_idx EQUAL -1)
    message(FATAL_ERROR
      "FetchContent_Declare(googletest ...) is missing EXCLUDE_FROM_ALL; the fetched "
      "googletest would build as part of the default ALL target (issue #10).")
  endif()
  list(FIND _declare_args "FIND_PACKAGE_ARGS" _fpa_idx)
  if(NOT _fpa_idx EQUAL -1 AND NOT _exclude_idx LESS _fpa_idx)
    message(FATAL_ERROR
      "EXCLUDE_FROM_ALL must precede FIND_PACKAGE_ARGS in FetchContent_Declare(googletest "
      "...); FIND_PACKAGE_ARGS is greedy and would otherwise swallow it (issue #10).")
  endif()
endif()

message(STATUS "INSTALL_GTEST_OFF_OK")
