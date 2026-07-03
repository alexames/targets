# Configure-mode regression tests for cpp_test()'s FOLDER / PROPERTIES handling (issue #15).
#
# cpp_test() used to re-parse only TARGET/FOLDER/WORKING_DIRECTORY over the FULL argument
# list, naming none of the multi-value keywords (SOURCES, DEPENDENCIES, PROPERTIES, ...).
# Tokens were therefore mis-associated depending on argument order, and the default-folder
# decision used a truthiness check that mishandled falsey-but-valid folder names. cpp_test()
# now parses the complete cpp_target signature (so nothing is mis-bucketed) and delegates
# applying FOLDER/PROPERTIES to cpp_target (see issue #13), supplying only the "Tests"
# default when the caller gave no FOLDER.
#
# Driven by -DSCENARIO=<default_folder|falsey_folder|explicit_folder>. Each scenario creates
# a cpp_test target with FOLDER/PROPERTIES placed AFTER a multi-value list (the ordering that
# previously mis-parsed), asserts the resulting target properties with FATAL_ERROR, and halts
# before generation with a sentinel matched by the CTest wrapper's PASS_REGULAR_EXPRESSION.
# LANGUAGES NONE keeps it compiler-free; the stubbed Google Test keeps it network-free.

cmake_minimum_required(VERSION 3.20)
project(TestCppTestFolder LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)
enable_testing()

if(NOT DEFINED SCENARIO)
  message(FATAL_ERROR
    "This test project requires -DSCENARIO=<default_folder|falsey_folder|explicit_folder>")
endif()

# Stub Google Test so cpp_test() runs network- and compiler-free. Providing GTest::gtest
# makes _targets_acquire_gtest() take its "already available" path (no find_package, no
# FetchContent); GTest::gtest_main satisfies the automatic link cpp_test() performs. The
# helper still runs include(GoogleTest) after the skip, so neutralize just that include and
# stub gtest_discover_tests to a no-op — this test checks argument handling, not discovery.
add_library(_stub_gtest INTERFACE)
add_library(GTest::gtest ALIAS _stub_gtest)
add_library(_stub_gtest_main INTERFACE)
add_library(GTest::gtest_main ALIAS _stub_gtest_main)
macro(include _module)
  if(NOT "${_module}" STREQUAL "GoogleTest")
    _include(${ARGV})
  endif()
endmacro()
function(gtest_discover_tests)
endfunction()

# A real dependency target so DEPENDENCIES has something to link (import_dependencies skips
# names that are already targets, and target_link_libraries needs the target to exist).
add_library(SomeDep INTERFACE)

# A translation unit so the executable is not source-less; never compiled (LANGUAGES NONE),
# and configuration halts before generation. It lives in the build tree, so SOURCE_DIR is
# pointed there to keep source_group(TREE) happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/test_main.cpp")
file(WRITE "${_src}" "int main() { return 0; }\n")

# Assert target property PROP equals EXPECTED, else FATAL_ERROR (which fails the test).
function(_expect_property target prop expected)
  get_target_property(_actual ${target} ${prop})
  if(NOT _actual STREQUAL "${expected}")
    message(FATAL_ERROR
      "${SCENARIO}: expected ${prop}='${expected}' on ${target}, got '${_actual}'")
  endif()
endfunction()

if(SCENARIO STREQUAL "default_folder")
  # No FOLDER given: the "Tests" default must still be applied even though a multi-value
  # DEPENDENCIES list and a PROPERTIES list precede where a FOLDER would go, and the custom
  # PROPERTY must be applied by cpp_target.
  cpp_test(
    TARGET DefaultFolderTest
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEPENDENCIES PUBLIC SomeDep
    PROPERTIES MY_CUSTOM_PROP custom_value
  )
  _expect_property(DefaultFolderTest FOLDER "Tests")
  _expect_property(DefaultFolderTest MY_CUSTOM_PROP "custom_value")
  message(FATAL_ERROR "DEFAULT_FOLDER_OK")

elseif(SCENARIO STREQUAL "falsey_folder")
  # A falsey-but-valid folder name given AFTER a multi-value list. The old truthiness check
  # (if(NOT _test_args_FOLDER)) treated "0" as "no folder" and forced FOLDER="Tests"; it
  # must now be honored verbatim. The custom PROPERTY must also be applied.
  cpp_test(
    TARGET FalseyFolderTest
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEPENDENCIES PUBLIC SomeDep
    PROPERTIES MY_CUSTOM_PROP custom_value
    FOLDER 0
  )
  _expect_property(FalseyFolderTest FOLDER "0")
  _expect_property(FalseyFolderTest MY_CUSTOM_PROP "custom_value")
  message(FATAL_ERROR "FALSEY_FOLDER_OK")

elseif(SCENARIO STREQUAL "explicit_folder")
  # An explicit non-default folder given after multi-value lists must win over the "Tests"
  # default, and the custom PROPERTY must be applied.
  cpp_test(
    TARGET ExplicitFolderTest
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEFINITIONS PUBLIC SOME_MACRO=1
    DEPENDENCIES PUBLIC SomeDep
    FOLDER "Custom/TestGroup"
    PROPERTIES MY_CUSTOM_PROP custom_value
  )
  _expect_property(ExplicitFolderTest FOLDER "Custom/TestGroup")
  _expect_property(ExplicitFolderTest MY_CUSTOM_PROP "custom_value")
  message(FATAL_ERROR "EXPLICIT_FOLDER_OK")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
