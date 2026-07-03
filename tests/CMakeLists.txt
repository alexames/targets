# Tests for Targets library

# Script-mode unit tests (pure CMake, no compiler required).
add_test(
  NAME parse_platforms
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_DIR}/unit/test_parse_platforms.cmake"
)

# A trailing LITERAL escape marker with no value must FATAL_ERROR (issue #12).
# Same script, driven with -DSCENARIO=escape_error; passes iff the diagnostic
# is emitted.
add_test(
  NAME parse_platforms_escape_error
  COMMAND "${CMAKE_COMMAND}" -DSCENARIO=escape_error
    -P "${CMAKE_CURRENT_LIST_DIR}/unit/test_parse_platforms.cmake"
)
set_tests_properties(parse_platforms_escape_error PROPERTIES
  PASS_REGULAR_EXPRESSION "escape marker 'LITERAL'")

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

# BUILD_TESTING opt-out and include-time side effects (regression tests for issue #9).
# cpp_test.cmake used to call enable_testing() at module-include time (directory-scoped,
# so tests were dropped when Targets was first included from a subdirectory) and ignored
# the standard CTest BUILD_TESTING option. With BUILD_TESTING=OFF, cpp_test() must create
# no target and acquire no Google Test; and a bare include(Targets) must not enable
# testing as a side effect. Each scenario prints a sentinel on success.
add_test(
  NAME cpp_test_build_testing_off
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=off
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_build_testing"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_build_testing_off"
)
set_tests_properties(cpp_test_build_testing_off PROPERTIES
  PASS_REGULAR_EXPRESSION "BUILD_TESTING_OFF_OK")

add_test(
  NAME cpp_test_no_enable_testing_side_effect
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=no_side_effect
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_build_testing"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_build_testing_no_side_effect"
)
set_tests_properties(cpp_test_no_enable_testing_side_effect PROPERTIES
  PASS_REGULAR_EXPRESSION "NO_SIDE_EFFECT_OK")

# FetchContent googletest install/ALL hygiene (regression test for issue #10). When
# Google Test is acquired via FetchContent, INSTALL_GTEST must be OFF before
# FetchContent_MakeAvailable (so gtest/gmock install rules never leak into a consumer's
# install tree) and the googletest subdirectory must be added EXCLUDE_FROM_ALL (so its
# targets do not build as part of ALL). The FetchContent branch is forced offline and its
# entry points stubbed, so the assertions run network-free and compiler-free.
add_test(
  NAME cpp_test_install_gtest_hygiene
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_install_gtest"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_install_gtest"
)
set_tests_properties(cpp_test_install_gtest_hygiene PROPERTIES
  PASS_REGULAR_EXPRESSION "INSTALL_GTEST_OFF_OK")

# Header-only INTERFACE semantics (regression tests for issue #13). The INTERFACE
# (header-only) branch used to apply only PUBLIC usage-requirements and silently drop
# FOLDER, PROPERTIES, PRIVATE usage-requirements, VERSION/SOVERSION, PRECOMPILE_HEADERS,
# and UNITY_BUILD. It must now apply what is valid on an INTERFACE target (PUBLIC
# usage-requirements, FOLDER, PROPERTIES) and warn about anything that only applies to a
# compiled target. The "apply" scenario configures cleanly (any FATAL_ERROR assertion
# fails the test); the "ignored" scenario passes iff the warning is emitted.
add_test(
  NAME cpp_target_interface_apply
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=apply
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_interface_semantics"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_interface_semantics_apply"
)
# No PASS_REGULAR_EXPRESSION, so the exit code decides: any FATAL_ERROR assertion in the
# scenario fails the test. FAIL_REGULAR_EXPRESSION additionally fails it if the ignored-
# argument warning is emitted for the all-valid inputs (the warning must not fire here).
set_tests_properties(cpp_target_interface_apply PROPERTIES
  FAIL_REGULAR_EXPRESSION "only apply to a compiled target and were ignored")

add_test(
  NAME cpp_target_interface_ignored_warns
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=ignored
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_interface_semantics"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_interface_semantics_ignored"
)
# PASS requires the warning to be emitted; FAIL_REGULAR_EXPRESSION makes the scenario's
# leak assertion effective -- with PASS_REGULAR_EXPRESSION set, CTest ignores the exit
# code, so the FATAL_ERROR raised if the ignored PRIVATE dependency leaks onto the
# INTERFACE target is only honored via this FAIL regex (FAIL takes precedence over PASS).
# CMake word-wraps the warning across console lines, so match the key phrase with
# whitespace-tolerant separators (as cpp_target_hygiene_interface_warns does) rather than a
# fixed-space string that a line break could split.
set_tests_properties(cpp_target_interface_ignored_warns PROPERTIES
  PASS_REGULAR_EXPRESSION "only[ \t\r\n]+apply[ \t\r\n]+to[ \t\r\n]+a[ \t\r\n]+compiled[ \t\r\n]+target[ \t\r\n]+and[ \t\r\n]+were[ \t\r\n]+ignored"
  FAIL_REGULAR_EXPRESSION "PRIVATE[ \t\r\n]+dependency[ \t\r\n]+must[ \t\r\n]+not[ \t\r\n]+be[ \t\r\n]+applied")

# Library linkage selection (regression tests for issue #14). STATIC and SHARED are
# mutually exclusive; passing both used to silently build SHARED instead of erroring
# (executables already rejected the same contradiction). The "conflict" scenario passes
# iff the FATAL_ERROR is emitted; the "shared" and "default" scenarios assert the
# preserved behavior (SHARED -> SHARED_LIBRARY, no flag -> STATIC_LIBRARY) and halt with a
# sentinel the harness matches.
add_test(
  NAME cpp_library_static_shared_conflict
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=conflict
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_conflict"
)
set_tests_properties(cpp_library_static_shared_conflict PROPERTIES
  PASS_REGULAR_EXPRESSION "STATIC and SHARED cannot both be specified")

add_test(
  NAME cpp_library_shared_type
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=shared
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_shared"
)
set_tests_properties(cpp_library_shared_type PROPERTIES
  PASS_REGULAR_EXPRESSION "SHARED_OK")

add_test(
  NAME cpp_library_default_type
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=default
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_default"
)
set_tests_properties(cpp_library_default_type PROPERTIES
  PASS_REGULAR_EXPRESSION "DEFAULT_OK")

# cpp_test() FOLDER/PROPERTIES robustness (regression tests for issue #15). cpp_test() used
# to re-parse only TARGET/FOLDER/WORKING_DIRECTORY over the full argument list, naming none
# of the multi-value keywords, so tokens were mis-associated by argument order and the
# default-folder decision used a truthiness check that broke on falsey-but-valid folder
# names. cpp_test() now parses the full cpp_target signature and delegates FOLDER/PROPERTIES
# to cpp_target. Each scenario places FOLDER/PROPERTIES after a multi-value list (the
# previously-broken ordering) and asserts the resulting target properties; the sentinel is
# matched by PASS_REGULAR_EXPRESSION and any FATAL_ERROR assertion fails the test.
add_test(
  NAME cpp_test_default_folder
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=default_folder
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_folder"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_folder_default"
)
set_tests_properties(cpp_test_default_folder PROPERTIES
  PASS_REGULAR_EXPRESSION "DEFAULT_FOLDER_OK")

add_test(
  NAME cpp_test_falsey_folder
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=falsey_folder
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_folder"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_folder_falsey"
)
set_tests_properties(cpp_test_falsey_folder PROPERTIES
  PASS_REGULAR_EXPRESSION "FALSEY_FOLDER_OK")

add_test(
  NAME cpp_test_explicit_folder
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=explicit_folder
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_folder"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_folder_explicit"
)
set_tests_properties(cpp_test_explicit_folder PROPERTIES
  PASS_REGULAR_EXPRESSION "EXPLICIT_FOLDER_OK")

# Install/export rule generation (regression test for issue #20). cpp_library(... INSTALL
# EXPORT ...) must make the target export-safe (public include dirs wrapped in
# BUILD/INSTALL_INTERFACE) and generate the install(TARGETS)/install(EXPORT)/package-config
# rules. Configuring runs the generate step too, so CMake validates the emitted
# install(EXPORT) at generate time; a leaked source path would make generation fail. The
# exit code decides: any FATAL_ERROR (from the project's assertions or from generation)
# fails the test. The full install -> find_package -> link -> run round trip is exercised
# by the install-export CI job against tests/consume_install.
add_test(
  NAME cpp_library_install_export
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_install_export"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_install_export"
)

# SHARED-library export ergonomics (regression tests for issue #21). EXPORT_HEADER must wire
# up GenerateExportHeader (visibility presets + the generated header's dir on the PUBLIC
# include path); WINDOWS_EXPORT_ALL_SYMBOLS must set the matching target property; the two
# strategies together, or either on an executable, must FATAL_ERROR. Each positive scenario
# asserts target properties and halts before generation with a sentinel; the negative
# scenarios pass iff the diagnostic is emitted. CXX is enabled (GenerateExportHeader probes
# the compiler), so these run where a C++ toolchain is available.
add_test(
  NAME cpp_library_export_header
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=export_header
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_export_header"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_export_header_header"
)
set_tests_properties(cpp_library_export_header PROPERTIES
  PASS_REGULAR_EXPRESSION "EXPORT_HEADER_OK")

add_test(
  NAME cpp_library_export_all_symbols
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=export_all_symbols
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_export_header"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_export_header_all"
)
set_tests_properties(cpp_library_export_all_symbols PROPERTIES
  PASS_REGULAR_EXPRESSION "EXPORT_ALL_OK")

add_test(
  NAME cpp_library_export_conflict
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=conflict
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_export_header"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_export_header_conflict"
)
set_tests_properties(cpp_library_export_conflict PROPERTIES
  PASS_REGULAR_EXPRESSION "mutually[ \t\r\n]+exclusive")

add_test(
  NAME cpp_library_export_on_executable
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=on_executable
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_export_header"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_export_header_on_exe"
)
set_tests_properties(cpp_library_export_on_executable PROPERTIES
  PASS_REGULAR_EXPRESSION "apply only to[ \t\r\n]+libraries")

# Opt-in toolchain hygiene: WARNINGS / WERROR / SANITIZERS / LTO (issue #23). Each knob is
# OFF by default and, when opted into, injects compiler-gated flags (via CXX_COMPILER_ID
# generator expressions) into COMPILE_OPTIONS/LINK_OPTIONS or sets the
# INTERPROCEDURAL_OPTIMIZATION property. Each scenario asserts the expected result and halts
# before generation with a sentinel matched by PASS_REGULAR_EXPRESSION; the negative
# scenarios pass iff the expected diagnostic is emitted. The "default" scenario proves no
# knob changes an opt-out target.
add_test(
  NAME cpp_target_hygiene_default
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=default
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_default"
)
set_tests_properties(cpp_target_hygiene_default PROPERTIES
  PASS_REGULAR_EXPRESSION "DEFAULT_OK")

add_test(
  NAME cpp_target_hygiene_warnings_strict
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=warnings_strict
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_warnings_strict"
)
set_tests_properties(cpp_target_hygiene_warnings_strict PROPERTIES
  PASS_REGULAR_EXPRESSION "WARNINGS_STRICT_OK")

add_test(
  NAME cpp_target_hygiene_warnings_off
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=warnings_off
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_warnings_off"
)
set_tests_properties(cpp_target_hygiene_warnings_off PROPERTIES
  PASS_REGULAR_EXPRESSION "WARNINGS_OFF_OK")

add_test(
  NAME cpp_target_hygiene_warnings_invalid
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=warnings_invalid
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_warnings_invalid"
)
set_tests_properties(cpp_target_hygiene_warnings_invalid PROPERTIES
  PASS_REGULAR_EXPRESSION "is not a valid level")

add_test(
  NAME cpp_target_hygiene_werror
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=werror
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_werror"
)
set_tests_properties(cpp_target_hygiene_werror PROPERTIES
  PASS_REGULAR_EXPRESSION "WERROR_OK")

add_test(
  NAME cpp_target_hygiene_sanitizers
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sanitizers
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_sanitizers"
)
set_tests_properties(cpp_target_hygiene_sanitizers PROPERTIES
  PASS_REGULAR_EXPRESSION "SANITIZERS_OK")

# LTO enables CXX (check_ipo_supported probes the compiler), so this scenario needs a C++
# toolchain like the MSVC-flags test. It asserts the property is ON when IPO is supported
# and skipped otherwise, so it is robust across toolchains.
add_test(
  NAME cpp_target_hygiene_lto
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=lto
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_lto"
)
set_tests_properties(cpp_target_hygiene_lto PROPERTIES
  PASS_REGULAR_EXPRESSION "LTO_OK")

add_test(
  NAME cpp_target_hygiene_interface_warns
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=interface_warns
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_interface_warns"
)
# The warning message is word-wrapped by CMake, so match the key phrase with whitespace-
# tolerant separators (as the export-conflict tests above do) rather than a fixed-space
# string that a line break could split.
set_tests_properties(cpp_target_hygiene_interface_warns PROPERTIES
  PASS_REGULAR_EXPRESSION "compiled[ \t\r\n]+target[ \t\r\n]+and[ \t\r\n]+were[ \t\r\n]+ignored")

# protobuf_cpp_library / grpc_cpp_library codegen rules (issue #26). These configure-mode
# scenarios run with NO protoc or gRPC plugin installed (CI has neither), so they never
# invoke code generation. Argument validation (missing TARGET/PROTOS, unknown keyword) and
# the point-of-use "tool not found" diagnostics pass iff the expected FATAL_ERROR is emitted.
# The "wiring" scenarios fake protoc/plugin discovery via the executable variables, assert
# the resulting custom-command wiring and target shape, and halt before generation with a
# sentinel. The real end-to-end codegen path is exercised by the guarded
# examples/codegen_protobuf example when protobuf is available.
add_test(
  NAME protobuf_cpp_library_missing_target
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=missing_target
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_missing_target"
)
set_tests_properties(protobuf_cpp_library_missing_target PROPERTIES
  PASS_REGULAR_EXPRESSION "TARGET must be provided")

add_test(
  NAME protobuf_cpp_library_missing_protos
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=missing_protos
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_missing_protos"
)
set_tests_properties(protobuf_cpp_library_missing_protos PROPERTIES
  PASS_REGULAR_EXPRESSION "PROTOS must be provided")

add_test(
  NAME protobuf_cpp_library_unknown_arg
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=unknown_arg
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_unknown_arg"
)
set_tests_properties(protobuf_cpp_library_unknown_arg PROPERTIES
  PASS_REGULAR_EXPRESSION "unrecognized argument")

add_test(
  NAME protobuf_cpp_library_no_protoc
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=no_protoc
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_no_protoc"
)
set_tests_properties(protobuf_cpp_library_no_protoc PROPERTIES
  PASS_REGULAR_EXPRESSION "protoc not found")

add_test(
  NAME grpc_cpp_library_no_plugin
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=no_grpc_plugin
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_no_grpc_plugin"
)
set_tests_properties(grpc_cpp_library_no_plugin PROPERTIES
  PASS_REGULAR_EXPRESSION "grpc_cpp_plugin not found")

add_test(
  NAME protobuf_cpp_library_wiring
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=wiring
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_wiring"
)
set_tests_properties(protobuf_cpp_library_wiring PROPERTIES
  PASS_REGULAR_EXPRESSION "WIRING_OK")

add_test(
  NAME grpc_cpp_library_wiring
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=grpc_wiring
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/protobuf_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/protobuf_cpp_library_grpc_wiring"
)
set_tests_properties(grpc_cpp_library_wiring PROPERTIES
  PASS_REGULAR_EXPRESSION "GRPC_WIRING_OK")

# flatbuffer_cpp_library source grouping robustness (regression test for issue #59). Like
# cpp_target (issue #6), the rule fed generated headers, schema sources, and binary schemas
# straight to source_group(TREE ...), which SEND_ERRORs on any file outside its root -- so a
# schema resolving out of SCHEMA_ROOT_DIR (out-of-source build tree or a `..`-relative schema)
# failed configuration. flatc is faked with CMAKE_COMMAND (CI has no FlatBuffers toolchain), the
# schema is written into the build tree so all three source groups see out-of-root files, and a
# clean configure (exit 0) proves those files are grouped flat instead of aborting. No
# PASS_REGULAR_EXPRESSION: the underlying error is a non-fatal SEND_ERROR, so only the exit code
# is trustworthy (mirroring cpp_target_source_group_out_of_root above).
add_test(
  NAME flatbuffer_cpp_library_source_group_out_of_root
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/flatbuffer_cpp_library"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/flatbuffer_cpp_library_source_group_out_of_root"
)

# Per-target COPTS / LINKOPTS and the DATA attribute (issue #27). COPTS/LINKOPTS carry
# PUBLIC/PRIVATE visibility and the same platform buckets as DEFINITIONS and must land in
# COMPILE_OPTIONS/LINK_OPTIONS (PUBLIC also in the INTERFACE_* variants) with platform
# filtering; DATA must configure its POST_BUILD staging cleanly for a file and a directory and
# be reported as ignored on a header-only INTERFACE library. Each positive scenario asserts the
# result and halts before generation with a sentinel matched by PASS_REGULAR_EXPRESSION; the
# runtime DATA staging is proven end-to-end by the examples/data_files example in CI.
add_test(
  NAME cpp_target_copts
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=copts
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_options"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_options_copts"
)
set_tests_properties(cpp_target_copts PROPERTIES
  PASS_REGULAR_EXPRESSION "COPTS_OK")

add_test(
  NAME cpp_target_linkopts
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=linkopts
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_options"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_options_linkopts"
)
set_tests_properties(cpp_target_linkopts PROPERTIES
  PASS_REGULAR_EXPRESSION "LINKOPTS_OK")

add_test(
  NAME cpp_target_data_stage
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=data_stage
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_options"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_options_data_stage"
)
set_tests_properties(cpp_target_data_stage PROPERTIES
  PASS_REGULAR_EXPRESSION "DATA_STAGE_OK")

add_test(
  NAME cpp_target_options_interface_warns
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=interface_warns
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_options"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_options_interface_warns"
)
# CMake word-wraps the warning across console lines, so match the key phrase with whitespace-
# tolerant separators (as the hygiene/interface tests above do).
set_tests_properties(cpp_target_options_interface_warns PROPERTIES
  PASS_REGULAR_EXPRESSION "compiled[ \t\r\n]+target[ \t\r\n]+and[ \t\r\n]+were[ \t\r\n]+ignored")

# cpp_test() Bazel-parity test attributes: SIZE / TIMEOUT / LABELS / ARGS / DATA (issue #27).
# These are applied to the CTest tests gtest_discover_tests registers; since discovery is a
# build-time step, the scenarios stub gtest_discover_tests to capture the exact arguments
# cpp_test passes it and assert the wiring (TIMEOUT from TIMEOUT/SIZE, LABELS, EXTRA_ARGS from
# ARGS, and the DATA-driven working directory). Each positive scenario halts with a sentinel
# matched by PASS_REGULAR_EXPRESSION; bad_size passes iff the invalid-size diagnostic fires.
add_test(
  NAME cpp_test_timeout
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=timeout
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_timeout"
)
set_tests_properties(cpp_test_timeout PROPERTIES
  PASS_REGULAR_EXPRESSION "TIMEOUT_OK")

add_test(
  NAME cpp_test_size
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=size
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_size"
)
set_tests_properties(cpp_test_size PROPERTIES
  PASS_REGULAR_EXPRESSION "SIZE_OK")

add_test(
  NAME cpp_test_size_override
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=size_override
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_size_override"
)
set_tests_properties(cpp_test_size_override PROPERTIES
  PASS_REGULAR_EXPRESSION "SIZE_OVERRIDE_OK")

add_test(
  NAME cpp_test_labels
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=labels
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_labels"
)
set_tests_properties(cpp_test_labels PROPERTIES
  PASS_REGULAR_EXPRESSION "LABELS_OK")

add_test(
  NAME cpp_test_args
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=args
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_args"
)
set_tests_properties(cpp_test_args PROPERTIES
  PASS_REGULAR_EXPRESSION "ARGS_OK")

add_test(
  NAME cpp_test_data_workdir
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=data_workdir
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_data_workdir"
)
set_tests_properties(cpp_test_data_workdir PROPERTIES
  PASS_REGULAR_EXPRESSION "DATA_WORKDIR_OK")

add_test(
  NAME cpp_test_arg_order
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=arg_order
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_arg_order"
)
set_tests_properties(cpp_test_arg_order PROPERTIES
  PASS_REGULAR_EXPRESSION "ARG_ORDER_OK")

add_test(
  NAME cpp_test_bad_size
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=bad_size
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_bad_size"
)
set_tests_properties(cpp_test_bad_size PROPERTIES
  PASS_REGULAR_EXPRESSION "is not a valid size")

# Empty-suite guard (issue #28). A cpp_test whose binary registers zero GoogleTest cases must
# make `ctest` fail rather than silently pass. Because discovery is a build-time step, cpp_test
# emits the zero-count check into the generated CTest include file that CTest runs at test time;
# the "no_tests_guard" scenario asserts that file registers an always-failing test (its
# EXISTENCE, so CI stays green), and "allow_no_tests" asserts ALLOW_NO_TESTS suppresses the guard
# while still applying per-test properties. Each halts with a sentinel matched below.
add_test(
  NAME cpp_test_no_tests_guard
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=no_tests_guard
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_no_tests_guard"
)
set_tests_properties(cpp_test_no_tests_guard PROPERTIES
  PASS_REGULAR_EXPRESSION "NO_TESTS_GUARD_OK")

add_test(
  NAME cpp_test_allow_no_tests
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=allow_no_tests
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_attributes"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_attributes_allow_no_tests"
)
set_tests_properties(cpp_test_allow_no_tests PROPERTIES
  PASS_REGULAR_EXPRESSION "ALLOW_NO_TESTS_OK")
