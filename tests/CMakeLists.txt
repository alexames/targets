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

# Source grouping robustness (regression test for issue #6). A generated source/header in
# an out-of-source build tree (outside SOURCE_DIR/HEADER_DIR) must not fail configuration:
# source_group(TREE ...) errors on out-of-root files, so those files are grouped flat
# instead. The build dir is a sibling of the source dir here, so the generated files are
# genuinely out of root; configuration must complete cleanly (exit 0). Before the fix the
# out-of-root source_group made configuration exit non-zero and this test fails.
add_test(
  NAME cpp_target_source_group_out_of_root
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_source_group"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_source_group"
)

# dummy.cpp fallback and header-only INTERFACE detection (regression test for issue #7).
# A library with HEADERS but no SOURCES must be an INTERFACE library with no dummy TU;
# a library with neither SOURCES nor HEADERS must be a STATIC library carrying the shipped
# dummy.cpp placeholder TU. A FATAL_ERROR in any assertion fails the test.
add_test(
  NAME cpp_target_dummy_source
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_dummy_source"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_dummy_source"
)

# MSVC compile/link flag scoping (regression test for issue #5). /ZI must never be
# injected as an unconditional (Release-reaching) option and /SAFESEH:NO must not reach
# non-x86 architectures, while /utf-8 stays unconditional. A FATAL_ERROR in any assertion
# fails the test. On non-MSVC toolchains the flags are absent and the test still passes.
add_test(
  NAME cpp_target_msvc_flags_default
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_msvc_flags"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_msvc_flags_default"
)

# Same project with the edit-and-continue opt-out: /ZI must be absent in every form.
add_test(
  NAME cpp_target_msvc_flags_no_edit_continue
  COMMAND "${CMAKE_COMMAND}"
    -DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_msvc_flags"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_msvc_flags_no_edit_continue"
)

# Embedded-subproject namespace derivation (regression test for issue #8). An outer
# project(Outer) embeds an inner project(Inner) that calls cpp_library() under its own
# Source/Core tree. The alias and IDE folder must be derived from the enclosing project
# (Inner::Core::InnerLib, folder "Inner/Core"), not the top-level CMAKE_PROJECT_NAME
# (Outer). A FATAL_ERROR in any assertion fails the test.
add_test(
  NAME cpp_target_embedded_subproject
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_embedded_subproject"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_embedded_subproject"
)
