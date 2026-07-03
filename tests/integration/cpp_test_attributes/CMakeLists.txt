# Configure-mode wiring tests for cpp_test()'s Bazel-parity test attributes (issue #27):
# SIZE, TIMEOUT, LABELS, ARGS, and DATA-driven working directory.
#
# These attributes are applied to the CTest tests that gtest_discover_tests registers. Because
# discovery happens at BUILD time, the individual tests do not exist at configure time, so
# these tests verify the WIRING cpp_test emits rather than the final CTest properties (the same
# approach the protobuf_cpp_library wiring tests use). Two surfaces are checked:
#   - WORKING_DIRECTORY / EXTRA_ARGS (from DATA / ARGS) pass through gtest_discover_tests, so a
#     stub captures its arguments and the scenarios assert them.
#   - TIMEOUT / SIZE / LABELS are applied via a generated CTest include file
#     (<target>_cpp_test_props.cmake), because gtest_discover_tests' own PROPERTIES option
#     cannot carry a multi-valued LABELS list; those scenarios read that file and assert its
#     set_tests_properties() content.
# A single scenario is selected via -DSCENARIO=... and paired with a PASS_REGULAR_EXPRESSION in
# the enclosing CTest harness. The real end-to-end behaviour (labels/timeout/args/data all
# applied to running gtest tests) is exercised by a live Google Test build during development.
#
# LANGUAGES NONE keeps it compiler-free; a stubbed Google Test keeps it network-free.

cmake_minimum_required(VERSION 3.20)
project(TestCppTestAttributes LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)
enable_testing()

if(NOT DEFINED SCENARIO)
  message(FATAL_ERROR
    "This test project requires -DSCENARIO=<timeout|size|size_override|labels|args|data_workdir|bad_size>")
endif()

# Stub Google Test so cpp_test() runs network- and compiler-free (as cpp_test_folder does):
# providing GTest::gtest makes _targets_acquire_gtest() take its "already available" path, and
# GTest::gtest_main satisfies the automatic link. Neutralize just the include(GoogleTest) call.
add_library(_stub_gtest INTERFACE)
add_library(GTest::gtest ALIAS _stub_gtest)
add_library(_stub_gtest_main INTERFACE)
add_library(GTest::gtest_main ALIAS _stub_gtest_main)
macro(include _module)
  if(NOT "${_module}" STREQUAL "GoogleTest")
    _include(${ARGV})
  endif()
endmacro()

# Capture the arguments cpp_test() passes to gtest_discover_tests into a global property so the
# scenarios can assert the wiring (this replaces the real, post-build discovery).
function(gtest_discover_tests)
  set_property(GLOBAL PROPERTY _DISCOVER_ARGS "${ARGV}")
endfunction()

# A translation unit so the test executable is not source-less; never compiled (LANGUAGES
# NONE). It lives in the build tree, so SOURCE_DIR is pointed there to keep source_group happy.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/test_main.cpp")
file(WRITE "${_src}" "int main() { return 0; }\n")

# Assert that the captured discover args (joined as a ';' list) contain the substring NEEDLE.
function(_expect_match needle)
  get_property(_a GLOBAL PROPERTY _DISCOVER_ARGS)
  if(NOT "${_a}" MATCHES "${needle}")
    message(FATAL_ERROR "${SCENARIO}: expected discover args to match '${needle}': ${_a}")
  endif()
endfunction()

# Read the generated per-test property include file for TARGET and assert its content matches
# NEEDLE. This is the file cpp_test emits to apply TIMEOUT/LABELS over the discovered tests.
function(_expect_props_file target needle)
  set(_pf "${CMAKE_CURRENT_BINARY_DIR}/${target}_cpp_test_props.cmake")
  if(NOT EXISTS "${_pf}")
    message(FATAL_ERROR "${SCENARIO}: expected props include file '${_pf}' was not generated")
  endif()
  file(READ "${_pf}" _c)
  if(NOT "${_c}" MATCHES "${needle}")
    message(FATAL_ERROR "${SCENARIO}: expected props file to match '${needle}', got:\n${_c}")
  endif()
endfunction()

if(SCENARIO STREQUAL "timeout")
  cpp_test(TARGET TimeoutTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    TIMEOUT 42)
  _expect_props_file(TimeoutTest "TIMEOUT 42")
  message(FATAL_ERROR "TIMEOUT_OK")

elseif(SCENARIO STREQUAL "size")
  # SIZE medium maps to the documented default TIMEOUT of 300 seconds.
  cpp_test(TARGET SizeTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    SIZE medium)
  _expect_props_file(SizeTest "TIMEOUT 300")
  message(FATAL_ERROR "SIZE_OK")

elseif(SCENARIO STREQUAL "size_override")
  # An explicit TIMEOUT overrides the SIZE-derived default.
  cpp_test(TARGET SizeOverrideTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    SIZE small TIMEOUT 5)
  _expect_props_file(SizeOverrideTest "TIMEOUT 5")
  message(FATAL_ERROR "SIZE_OVERRIDE_OK")

elseif(SCENARIO STREQUAL "labels")
  # Multiple labels must be applied as ONE LABELS value ("unit;fast"), so every label survives.
  cpp_test(TARGET LabelsTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    LABELS unit fast)
  _expect_props_file(LabelsTest "LABELS \"unit;fast\"")
  message(FATAL_ERROR "LABELS_OK")

elseif(SCENARIO STREQUAL "args")
  # ARGS become gtest_discover_tests EXTRA_ARGS (passed to the test exe when CTest runs it),
  # NOT cpp_target's COMMAND_ARGUMENTS (VS debugger). Assert EXTRA_ARGS carries them and that
  # ARGS did not leak onto the target as debugger command arguments.
  cpp_test(TARGET ArgsTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    ARGS --shuffle --gtest_repeat=2)
  _expect_match("EXTRA_ARGS;--shuffle;--gtest_repeat=2")
  get_target_property(_dbg ArgsTest VS_DEBUGGER_COMMAND_ARGUMENTS)
  if(_dbg)
    message(FATAL_ERROR "args: ARGS must not set VS_DEBUGGER_COMMAND_ARGUMENTS, got '${_dbg}'")
  endif()
  message(FATAL_ERROR "ARGS_OK")

elseif(SCENARIO STREQUAL "data_workdir")
  # With DATA staged and no explicit WORKING_DIRECTORY, discovered tests run from the binary's
  # directory so they find their data by relative path.
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/testdata.txt" "data\n")
  cpp_test(TARGET DataWorkdirTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    DATA "${CMAKE_CURRENT_BINARY_DIR}/testdata.txt")
  _expect_match("WORKING_DIRECTORY")
  _expect_match("TARGET_FILE_DIR:DataWorkdirTest")
  message(FATAL_ERROR "DATA_WORKDIR_OK")

elseif(SCENARIO STREQUAL "arg_order")
  # Regression: the multi-value test attributes LABELS/ARGS must NOT swallow cpp_target
  # keywords written after them. Here SOURCES and DEFINITIONS follow LABELS/ARGS; they must
  # still reach cpp_target (SOURCES present => a real compiled target, not a source-less
  # dummy) while the attributes are still applied. cpp_test parses the full cpp_target
  # signature so each keyword terminates the preceding attribute list at the right boundary.
  cpp_test(TARGET OrderTest
    LABELS unit fast
    ARGS --shuffle
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCES "${_src}"
    DEFINITIONS PUBLIC ORDER_MACRO=1)
  get_target_property(_srcs OrderTest SOURCES)
  if(NOT "${_srcs}" MATCHES "test_main\\.cpp")
    message(FATAL_ERROR "arg_order: SOURCES after LABELS/ARGS were swallowed: '${_srcs}'")
  endif()
  get_target_property(_defs OrderTest COMPILE_DEFINITIONS)
  if(NOT "${_defs}" MATCHES "ORDER_MACRO=1")
    message(FATAL_ERROR "arg_order: DEFINITIONS after LABELS/ARGS were swallowed: '${_defs}'")
  endif()
  _expect_props_file(OrderTest "LABELS \"unit;fast\"")
  _expect_match("EXTRA_ARGS;--shuffle")
  message(FATAL_ERROR "ARG_ORDER_OK")

elseif(SCENARIO STREQUAL "bad_size")
  # An unknown SIZE must fail fast with a clear message.
  cpp_test(TARGET BadSizeTest SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}" SOURCES "${_src}"
    SIZE gigantic)
  message(FATAL_ERROR "bad_size: expected a FATAL_ERROR for an invalid SIZE")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
