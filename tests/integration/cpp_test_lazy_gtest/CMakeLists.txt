# Configure-mode regression test for lazy Google Test acquisition.
#
# Regression test for https://github.com/alexames/targets/issues/3: including the
# Targets modules (via include(Targets) / find_package(Targets)) used to acquire
# Google Test — find_package(GTest) and, if absent, a FetchContent clone of
# googletest — at module-include time. A consumer that defined ZERO tests, or
# configured offline, therefore failed to configure. Acquisition is now deferred
# to the first cpp_test() call.
#
# This project includes Targets and defines NO tests, then asserts that no Google
# Test acquisition happened. On the fixed code this performs no network access; on
# the old code it either fails outright (offline) or eagerly defines the artifacts
# checked below (online), so the assertions fail either way.

cmake_minimum_required(VERSION 3.20)
project(TestLazyGTest LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# include(GoogleTest) must NOT have run yet — the discovery command it provides is
# the cheapest network-free signal that acquisition was deferred.
if(COMMAND gtest_discover_tests)
  message(FATAL_ERROR
    "gtest_discover_tests is defined after a bare include(Targets) with no "
    "cpp_test() calls — Google Test was acquired at include time (issue #3).")
endif()

# No Google Test targets should exist from a bare include.
if(TARGET gtest OR TARGET GTest::gtest OR TARGET gtest_main OR TARGET GTest::gtest_main)
  message(FATAL_ERROR
    "A Google Test target exists after a bare include(Targets) with no "
    "cpp_test() calls — Google Test was acquired at include time (issue #3).")
endif()

# The internal run-once guard must stay unset until the first cpp_test() call.
get_property(_acquired GLOBAL PROPERTY _TARGETS_GTEST_ACQUIRED)
if(_acquired)
  message(FATAL_ERROR
    "_TARGETS_GTEST_ACQUIRED is set after a bare include(Targets) with no "
    "cpp_test() calls — acquisition was not deferred (issue #3).")
endif()

message(STATUS "lazy GTest acquisition configure-mode test passed")
