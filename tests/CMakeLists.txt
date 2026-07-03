# Tests for Targets library

# Script-mode unit tests (pure CMake, no compiler required).
add_test(
  NAME parse_platforms
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_DIR}/unit/test_parse_platforms.cmake"
)

# Configure-mode integration tests: each configures a small project that exercises a
# rule and asserts the result. A non-zero configure exit (e.g. a FATAL_ERROR) fails
# the test.

# embed_binary() must configure without error (regression test for issue #1).
add_test(
  NAME embed_binary_configure
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/embed_binary"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/embed_binary"
)

# include(Targets) with zero cpp_test() calls must not acquire Google Test
# (regression test for issue #3). Configures offline-clean: no network access.
add_test(
  NAME cpp_test_lazy_gtest_configure
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_lazy_gtest"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_lazy_gtest"
)

# Argument validation (regression tests for issue #4). Values placed before the
# first PUBLIC/PRIVATE keyword, and unknown/misspelled keywords, must produce a
# FATAL_ERROR rather than being silently dropped. The negative scenarios pass iff
# the expected diagnostic is emitted; the "valid" scenario must configure cleanly.
add_test(
  NAME cpp_target_pre_keyword_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=pre_keyword
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_pre_keyword"
)
set_tests_properties(cpp_target_pre_keyword_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "must be grouped under PUBLIC or PRIVATE")

add_test(
  NAME cpp_target_unknown_arg_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=unknown_arg
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_unknown_arg"
)
set_tests_properties(cpp_target_unknown_arg_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "unrecognized argument")

add_test(
  NAME cpp_target_valid_visibility
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=valid
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_valid"
)
set_tests_properties(cpp_target_valid_visibility PROPERTIES
  PASS_REGULAR_EXPRESSION "VALID_OK")
