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
