# Multi-directory Google Test visibility regression test (issue #62).
#
# Lazy Google Test acquisition (issue #3) runs at most once per configure, behind a GLOBAL
# run-once guard, on the first cpp_test() call. The acquisition used a plain
# find_package(GTest), which creates the GTest::gtest_main IMPORTED target in the DIRECTORY
# scope that acquired it. Every cpp_test() in a DIFFERENT directory then hit the run-once
# guard, skipped acquisition, and could not see GTest::gtest_main, so its automatic
# target_link_libraries(<target> PRIVATE GTest::gtest_main) failed at GENERATE time with
# "links to GTest::gtest_main but the target was not found". That broke any project whose
# tests span sibling directories (worked in 0.9.0, which acquired GTest at include time).
#
# This project reproduces the failure: a top-level project that add_subdirectory's two
# SIBLING directories, each defining a cpp_test target. The first directory triggers
# acquisition; the second must still be able to link GTest::gtest_main. Because `cmake -B -S`
# runs the generate step (where the bug surfaces) after configure, a clean exit 0 proves both
# directories resolve the target. Before the fix, generation fails for the second directory;
# after the fix (find_package(GTest ... GLOBAL) / IMPORTED_GLOBAL promotion) it succeeds.
#
# A fake FindGTest.cmake (cmake/FindGTest.cmake, ahead of Targets on CMAKE_MODULE_PATH and of
# CMake's builtin module) supplies non-global INTERFACE IMPORTED GTest targets, so the test
# needs no network and no installed Google Test. LANGUAGES CXX is required to reproduce the
# real link path; each CI runner's default compiler covers it, and nothing is ever built --
# the test only configures and generates.

cmake_minimum_required(VERSION 3.20)
project(TestCppTestMultidir LANGUAGES CXX)

# The fake FindGTest.cmake must win over CMake's builtin FindGTest, so its directory is placed
# on CMAKE_MODULE_PATH ahead of the real cmake/ directory that provides Targets.cmake.
list(APPEND CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_LIST_DIR}/cmake"
  "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")

include(Targets)
enable_testing()

add_subdirectory(dir_a)
add_subdirectory(dir_b)
