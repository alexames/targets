# Configure-mode regression tests for BUILD_TESTING / include-time enable_testing().
#
# Regression tests for https://github.com/alexames/targets/issues/9:
#   1. cpp_test.cmake called enable_testing() at module-include time. enable_testing() is
#      directory-scoped and this file is include-guarded, so when Targets was first
#      included from a subdirectory, tests registered in sibling/parent scopes were
#      silently dropped from CTest. The fix removes the include-time side effect and
#      requires the consumer to enable testing at the top level.
#   2. The standard CTest BUILD_TESTING opt-out was ignored. The fix makes cpp_test()
#      early-out (creating no target and acquiring no Google Test) when BUILD_TESTING=OFF.
#
# Driven by -DSCENARIO=<off|no_side_effect>. Each scenario asserts with FATAL_ERROR
# (which fails the test) and prints a sentinel string on success that the CTest wrapper
# matches with PASS_REGULAR_EXPRESSION. LANGUAGES NONE keeps this offline and
# compiler-free: on fixed code no scenario ever creates an executable target.

cmake_minimum_required(VERSION 3.20)
project(TestBuildTesting LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")

if(NOT DEFINED SCENARIO)
  message(FATAL_ERROR "This test project requires -DSCENARIO=<off|no_side_effect>")
endif()

if(SCENARIO STREQUAL "off")
  # BUILD_TESTING=OFF must make cpp_test() a no-op: no target, no Google Test.
  set(BUILD_TESTING OFF)
  include(Targets)

  cpp_test(
    TARGET SkippedTest
    SOURCES does_not_exist.cpp
  )

  if(TARGET SkippedTest)
    message(FATAL_ERROR
      "cpp_test() created a target while BUILD_TESTING=OFF (issue #9).")
  endif()

  get_property(_acquired GLOBAL PROPERTY _TARGETS_GTEST_ACQUIRED)
  if(_acquired OR COMMAND gtest_discover_tests
      OR TARGET gtest OR TARGET GTest::gtest)
    message(FATAL_ERROR
      "cpp_test() acquired Google Test while BUILD_TESTING=OFF (issue #9).")
  endif()

  message(STATUS "BUILD_TESTING_OFF_OK")

elseif(SCENARIO STREQUAL "no_side_effect")
  # Including Targets must NOT enable testing on its own. A consumer that has not called
  # enable_testing()/include(CTest) must still see testing disabled after the include;
  # the old include-time enable_testing() flipped CMAKE_TESTING_ENABLED on here.
  include(Targets)

  if(CMAKE_TESTING_ENABLED)
    message(FATAL_ERROR
      "include(Targets) enabled testing as a side effect; enable_testing() must be "
      "left to the consumer's top level (issue #9).")
  endif()

  message(STATUS "NO_SIDE_EFFECT_OK")

else()
  message(FATAL_ERROR "Unknown SCENARIO '${SCENARIO}'")
endif()
