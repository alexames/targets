# Fake FindGTest for the multi-directory cpp_test regression test (issue #62).
#
# Stands in for an installed Google Test with no network access and no compiler: it creates
# GTest::gtest and GTest::gtest_main as NON-global INTERFACE IMPORTED targets -- exactly the
# shape a real find_package(GTest) produces. Being IMPORTED (not regular) and non-global, they
# are visible only in the directory scope that ran find_package() unless that scope promotes
# them. That is precisely what makes the bug reproducible here: without the GLOBAL promotion
# the fix adds, the sibling directory that did not acquire GTest cannot see the targets and
# generation fails. With the fix, find_package(GTest ... GLOBAL) (or the IMPORTED_GLOBAL
# fallback) promotes them and both directories link successfully.
#
# This file must be found ahead of CMake's builtin FindGTest.cmake, which the enclosing project
# arranges by putting this directory first on CMAKE_MODULE_PATH.

if(NOT TARGET GTest::gtest)
  add_library(GTest::gtest INTERFACE IMPORTED)
endif()
if(NOT TARGET GTest::gtest_main)
  add_library(GTest::gtest_main INTERFACE IMPORTED)
endif()

set(GTest_FOUND TRUE)
