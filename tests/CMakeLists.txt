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

# Argument validation for a library, whose every visibility-taking list requires the keyword.
# Values placed before the first PUBLIC/PRIVATE keyword, and unknown or misspelled keywords,
# must produce a FATAL_ERROR rather than being silently dropped. Each rejection scenario halts
# on its own "was accepted" message if the call goes through, and the FAIL expression matches
# that: a PASS expression alone makes CTest ignore the exit code, so a diagnostic demoted to a
# warning would otherwise still print the wording the PASS expression looks for.
add_test(
  NAME cpp_target_pre_keyword_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=pre_keyword
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_pre_keyword"
)
set_tests_properties(cpp_target_pre_keyword_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "must be grouped under PUBLIC or PRIVATE"
  FAIL_REGULAR_EXPRESSION "was[ 	
]+accepted")

add_test(
  NAME cpp_target_unknown_arg_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=unknown_arg
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_unknown_arg"
)
set_tests_properties(cpp_target_unknown_arg_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "unrecognized argument"
  FAIL_REGULAR_EXPRESSION "was[ 	
]+accepted")

# The fully-qualified form configures cleanly and splits visibility as declared. Every
# assertion in that scenario names it ("valid: ..."), which its own halt does not, so the FAIL
# expression tells a tripped assertion from the halt the PASS expression is looking for.
add_test(
  NAME cpp_target_valid_visibility
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=valid
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_valid"
)
set_tests_properties(cpp_target_valid_visibility PROPERTIES
  PASS_REGULAR_EXPRESSION "VALID_OK"
  FAIL_REGULAR_EXPRESSION "valid:")

# The banner message(DEPRECATION) prints. Matching the banner rather than the message text
# is what proves a report is the kind -Werror=deprecated promotes to a configure error; the
# text alone would match a STATUS message just as well. CMake 4.4 renamed it -- "CMake
# Deprecation Warning at" became "CMake Warning (deprecated) at" when CMP0218 reworked
# diagnostics -- so an expression carrying one spelling tests nothing on half the CMake
# versions this project supports.
set(_targets_deprecation_banner
  "CMake[ \t]+(Deprecation[ \t]+Warning|Warning[ \t]+[(]deprecated[)])[ \t]+at")

# SOURCES spelling (issue #66). SOURCES takes either PUBLIC/PRIVATE groups or the deprecated
# bare list, told apart by its first entry; anything between the two is rejected. Each
# negative scenario halts with its own "was accepted" message if the call it makes goes
# through, and the FAIL expression matches that -- a PASS expression alone makes CTest ignore
# the exit code, so a diagnostic demoted from FATAL_ERROR to a warning would otherwise still
# print the wording the PASS expression looks for. CMake word-wraps both, so the phrases are
# matched with whitespace-tolerant separators.
add_test(
  NAME cpp_target_sources_mixed_spelling_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sources_mixed
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_sources_mixed"
)
set_tests_properties(cpp_target_sources_mixed_spelling_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "mixes[ \t\r\n]+the[ \t\r\n]+two[ \t\r\n]+spellings"
  FAIL_REGULAR_EXPRESSION "was[ \t\r\n]+accepted")

add_test(
  NAME cpp_target_sources_grouped_with_headers_rejected
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sources_grouped_with_headers
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_grouped_headers"
)
set_tests_properties(cpp_target_sources_grouped_with_headers_rejected PROPERTIES
  PASS_REGULAR_EXPRESSION "two[ \t\r\n]+spellings[ \t\r\n]+of[ \t\r\n]+the[ \t\r\n]+same"
  FAIL_REGULAR_EXPRESSION "was[ \t\r\n]+accepted")

# The deprecated spelling has to keep working unchanged, and has to say it is deprecated.
# Both facts come from one scenario, read by two tests. Every assertion in that scenario
# names it ("sources_legacy: ..."), which its own halt does not, so the FAIL expression
# tells a tripped assertion from the halt the PASS expression is looking for.
add_test(
  NAME cpp_target_sources_legacy_configures
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sources_legacy
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_sources_legacy"
)
set_tests_properties(cpp_target_sources_legacy_configures PROPERTIES
  PASS_REGULAR_EXPRESSION "LEGACY_SOURCES_OK"
  FAIL_REGULAR_EXPRESSION "sources_legacy:")

add_test(
  NAME cpp_target_sources_legacy_deprecated
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sources_legacy
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_legacy_deprecated"
)
set_tests_properties(cpp_target_sources_legacy_deprecated PROPERTIES
  PASS_REGULAR_EXPRESSION "${_targets_deprecation_banner}[^\n]*cpp_target[.]cmake"
  FAIL_REGULAR_EXPRESSION "sources_legacy:")

# How many reports a configure produces, which is the point of the once-per-configure guard
# and is what a CTest regex cannot tell: a regex says a report appeared, not that a consumer
# with hundreds of targets got one rather than hundreds. The script drives two configures of
# a two-legacy-target scenario -- one plain, one with TARGETS_WARN_ALL_LEGACY_SOURCES=ON --
# and counts the banners in each. Its assertions are all FATAL_ERROR, so the exit code
# decides and no PASS expression may be attached.
add_test(
  NAME cpp_target_legacy_warning_volume
  COMMAND "${CMAKE_COMMAND}"
    "-DFIXTURE_DIR=${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    "-DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_legacy_warning_volume"
    -P "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation/legacy_warning_volume.cmake"
)

# The grouped spelling reaches the same place and must not report itself deprecated, so the
# deprecation banner joins the tripped-assertion phrase in the FAIL expression.
add_test(
  NAME cpp_target_sources_grouped
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=sources_grouped
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_arg_validation"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_arg_validation_sources_grouped"
)
set_tests_properties(cpp_target_sources_grouped PROPERTIES
  PASS_REGULAR_EXPRESSION "GROUPED_SOURCES_OK"
  FAIL_REGULAR_EXPRESSION "sources_grouped:;${_targets_deprecation_banner}")


# Source grouping robustness (regression test for issue #6). A generated source/header in
# an out-of-source build tree (outside SOURCE_DIR/HEADER_DIR) must not fail configuration:
# source_group(TREE ...) errors on out-of-root files, so those files are grouped flat
# instead. The build dir is a sibling of the source dir here, so the generated files are
# genuinely out of root; configuration must complete cleanly (exit 0). Before the fix the
# out-of-root source_group made configuration exit non-zero and this test fails.
add_test(
  NAME cpp_target_source_group_out_of_root
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=out_of_root
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_source_group"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_source_group"
)

# The two grouping roots are also the two base directories (issue #66): a PRIVATE entry
# resolves against SOURCE_DIR and a PUBLIC one against HEADER_DIR. The fixture asserts the
# resolved paths, and the files it names exist under one base only, so a swap makes
# generation fail on a missing source. The exit code decides, hence no PASS expression.
add_test(
  NAME cpp_target_source_group_visibility_base_dirs
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=visibility_base_dirs
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_source_group"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_source_group_base_dirs"
)

# The IDE groups those files land in. source_group() leaves nothing a configure-time
# assertion can read, so this drives its own configure and reads the .vcxproj.filters file --
# which only a Visual Studio generator writes. The outer generator is reused because it is
# the Visual Studio known to be installed.
if(CMAKE_GENERATOR MATCHES "Visual Studio")
  add_test(
    NAME cpp_target_source_group_ide_groups
    COMMAND "${CMAKE_COMMAND}"
      "-DFIXTURE_DIR=${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_source_group"
      "-DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_source_group_ide_groups"
      "-DTEST_GENERATOR=${CMAKE_GENERATOR}"
      -P "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_source_group/ide_source_groups.cmake"
  )
endif()

# The placeholder translation unit cpp_target() injects (issue #7). A library with nothing
# of its own to compile -- HEADERS but no SOURCES, or neither -- must be a STATIC library
# carrying the shipped dummy.cpp. A FATAL_ERROR in any assertion fails the test.
add_test(
  NAME cpp_target_dummy_source
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_dummy_source"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_dummy_source"
)

# The placeholder must resolve from any directory scope. cpp_target.cmake runs its body only
# in the first scope that includes Targets, so a sibling directory that includes Targets for
# itself -- what every example does -- sees none of the variables that body set.
add_test(
  NAME cpp_target_dummy_source_sibling_scope
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_dummy_source_sibling_scope"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_dummy_source_sibling_scope"
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

# What cpp_target applies to a header-only library. It is a compiled target like any other,
# so the settings that describe a compile step or a built artifact all mean something on it:
# "apply" covers the ones that reach the target itself, "private_applies" the PRIVATE
# usage-requirements that reach its own compile step without leaking to consumers. Neither
# sets PASS_REGULAR_EXPRESSION, so the exit code decides: any FATAL_ERROR assertion in the
# scenario fails the test.
add_test(
  NAME cpp_target_header_only_apply
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=apply
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_header_only_semantics"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_header_only_semantics_apply"
)

add_test(
  NAME cpp_target_header_only_private_applies
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=private_applies
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_header_only_semantics"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_header_only_semantics_private"
)

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

# A translation unit under SOURCES PUBLIC. PUBLIC says where an entry resolves and that
# consumers see it; it never meant the file is left out of the build.
add_test(
  NAME cpp_library_public_translation_unit
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=public_translation_unit
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_public_translation_unit"
)
set_tests_properties(cpp_library_public_translation_unit PROPERTIES
  PASS_REGULAR_EXPRESSION "PUBLIC_TU_OK"
  FAIL_REGULAR_EXPRESSION "public_translation_unit:")

# SHARED on a header-only library. Nothing about having no translation unit of its own makes
# a library's linkage contradictory, so the rule does not second-guess the request: it builds
# the placeholder TU into a shared library. What that library exports is the caller's problem
# (on Windows, a library exporting nothing produces no import library for consumers to link).
add_test(
  NAME cpp_library_shared_header_only_type
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=shared_header_only
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_shared_header_only"
)
set_tests_properties(cpp_library_shared_header_only_type PROPERTIES
  PASS_REGULAR_EXPRESSION "SHARED_HEADER_ONLY_OK"
  FAIL_REGULAR_EXPRESSION "shared_header_only:")

# Whether a library is given the placeholder TU, under the PUBLIC/PRIVATE spelling (issue
# #66). The decision is made on whether any PRIVATE entry is a translation unit, so these two
# calls differ in one private file: one is given the placeholder and one must not be. Each
# scenario names itself in its assertions ("grouped_header_only: ...") but not in its halt, so
# the FAIL expression tells a tripped assertion from the halt the PASS expression looks for.
add_test(
  NAME cpp_library_grouped_header_only_type
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=grouped_header_only
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_grouped_header_only"
)
set_tests_properties(cpp_library_grouped_header_only_type PROPERTIES
  PASS_REGULAR_EXPRESSION "GROUPED_HEADER_ONLY_OK"
  FAIL_REGULAR_EXPRESSION "grouped_header_only:")

add_test(
  NAME cpp_library_grouped_static_type
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=grouped_static
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_type"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_type_grouped_static"
)
set_tests_properties(cpp_library_grouped_static_type PROPERTIES
  PASS_REGULAR_EXPRESSION "GROUPED_STATIC_OK"
  FAIL_REGULAR_EXPRESSION "grouped_static:")

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

# A header-only library compiles the placeholder TU, so the hygiene knobs describe a compile
# step it really has and must land on it.
add_test(
  NAME cpp_target_hygiene_header_only
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=header_only
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_hygiene"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_hygiene_header_only"
)
set_tests_properties(cpp_target_hygiene_header_only PROPERTIES
  PASS_REGULAR_EXPRESSION "HYGIENE_HEADER_ONLY_OK"
  FAIL_REGULAR_EXPRESSION "header_only:")

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
# filtering; DATA must configure its POST_BUILD staging cleanly for a file and a directory.
# All three reach a header-only library too. Each positive scenario asserts the result and
# halts before generation with a sentinel matched by PASS_REGULAR_EXPRESSION; the runtime DATA
# staging is proven end-to-end by the examples/data_files example in CI.
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
  NAME cpp_target_options_header_only
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=header_only
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_options"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_options_header_only"
)
set_tests_properties(cpp_target_options_header_only PROPERTIES
  PASS_REGULAR_EXPRESSION "OPTS_HEADER_ONLY_OK"
  FAIL_REGULAR_EXPRESSION "header_only:")

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

# Multi-directory Google Test visibility (regression test for issue #62). Lazy GTest
# acquisition (#3) runs once per configure behind a global run-once guard, but the plain
# find_package(GTest) it used created a directory-scoped GTest::gtest_main imported target. Any
# cpp_test() in a directory OTHER than the one that first acquired GTest then failed at GENERATE
# time with "links to GTest::gtest_main but the target was not found". This project
# add_subdirectory's two sibling directories, each defining a cpp_test; a plain configure runs
# the generate step too, so exit 0 proves both directories can link the now globally-promoted
# GTest::gtest_main. A fake FindGTest supplies non-global imported GTest targets (no network, no
# real Google Test); the exit code decides, so no PASS_REGULAR_EXPRESSION. LANGUAGES CXX is
# needed to reproduce the real link path and is covered by each CI runner's default compiler --
# the project only configures and generates, it is never built.
add_test(
  NAME cpp_test_multidir_gtest_visibility
  COMMAND "${CMAKE_COMMAND}"
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_test_multidir"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_test_multidir"
)

# C++20 module-scanning suppression. cpp_target defaults to C++23, which under CMP0155 NEW makes
# CMake dependency-scan every translation unit for module imports; Targets can declare no module
# interface unit, so that scan never finds one. The fixture needs CMP0155 to be NEW, so it
# declares cmake_minimum_required(VERSION 3.28) and these tests are registered only when the
# CMake running them is that new -- on an older one the inner configure would abort before
# reaching a single assertion.
#
# The default scenario asserts CXX_SCAN_FOR_MODULES reads back OFF on a cpp_library and a
# cpp_binary and then configures and generates to the end, so the exit code decides. The two
# override scenarios assert that asking for scanning wins -- project-wide via
# TARGETS_SCAN_FOR_MODULES (which leaves the property unset for CMP0155 to decide) and via
# CMake's own CMAKE_CXX_SCAN_FOR_MODULES variable (which sets it). Both halt before generation
# with the sentinel matched below, because whether CMake can then actually scan depends on the
# generator.
if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.28)
  add_test(
    NAME cpp_target_scan_for_modules_default
    COMMAND "${CMAKE_COMMAND}"
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_scan_for_modules"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_scan_for_modules_default"
  )

  add_test(
    NAME cpp_target_scan_for_modules_opt_in
    COMMAND "${CMAKE_COMMAND}"
      -DTARGETS_SCAN_FOR_MODULES=ON
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_scan_for_modules"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_scan_for_modules_opt_in"
  )
  set_tests_properties(cpp_target_scan_for_modules_opt_in PROPERTIES
    PASS_REGULAR_EXPRESSION "SCAN_FOR_MODULES_OVERRIDE_OK")

  add_test(
    NAME cpp_target_scan_for_modules_cmake_variable
    COMMAND "${CMAKE_COMMAND}"
      -DCMAKE_CXX_SCAN_FOR_MODULES=ON
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_scan_for_modules"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_scan_for_modules_cmake_variable"
  )
  set_tests_properties(cpp_target_scan_for_modules_cmake_variable PROPERTIES
    PASS_REGULAR_EXPRESSION "SCAN_FOR_MODULES_OVERRIDE_OK")
endif()

# targets_enable_compiler_cache(). The rule must refuse to claim success where a compiler
# launcher would be dropped, and must carry the ccache settings that make cross-checkout hits
# possible in the build rules rather than the ambient environment.
#
# The scenarios up to the Ninja search are generator-independent: a missing cache binary is
# resolved before any generator question is asked, and a misspelled keyword never gets that
# far. Each pairs its PASS expression with a FAIL expression, because a PASS expression alone
# makes CTest ignore the exit code -- and a rule that merely warned where it should have
# failed would still print the wording the PASS expression looks for.
add_test(
  NAME compiler_cache_required_missing
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=required_missing
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_required_missing"
)
set_tests_properties(compiler_cache_required_missing PROPERTIES
  PASS_REGULAR_EXPRESSION "REQUIRED,[ \t\r\n]+but[ \t\r\n]+no[ \t\r\n]+compiler[ \t\r\n]+cache"
  FAIL_REGULAR_EXPRESSION "did[ \t\r\n]+not[ \t\r\n]+fail")

# The same missing binary without REQUIRED must configure and generate to the end with the
# launchers left unset, so the exit code decides -- and it can only decide while no PASS
# expression is attached, which is why the warning that same run prints is asserted by the
# separate test below instead of here.
add_test(
  NAME compiler_cache_optional_missing
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=optional_missing
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_optional_missing"
)

# The PASS expression matches CMake's own "CMake Warning at ... compiler_cache.cmake" banner
# rather than the message text, because the text alone would match just as well if the rule
# were demoted to a STATUS message. Spelling out the "at" excludes the "CMake Warning (dev)
# at" banner an AUTHOR_WARNING would print, which -Wno-dev suppresses entirely.
add_test(
  NAME compiler_cache_optional_missing_warns
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=optional_missing
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_optional_missing_warns"
)
set_tests_properties(compiler_cache_optional_missing_warns PROPERTIES
  PASS_REGULAR_EXPRESSION "CMake[ \t]+Warning[ \t]+at[^\n]*compiler_cache[.]cmake"
  FAIL_REGULAR_EXPRESSION "CMake[ \t\r\n]+Error")

# Declining must clear only what this rule wired in. A launcher the project set for itself
# has to survive, or enabling the rule would disarm a distcc setup on any machine without
# ccache installed.
add_test(
  NAME compiler_cache_foreign_launcher_kept
  COMMAND "${CMAKE_COMMAND}"
    "-DCMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_COMMAND}"
    -DSCENARIO=foreign_launcher_kept
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_foreign_launcher_kept"
)

add_test(
  NAME compiler_cache_unknown_arg
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=unknown_arg
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_unknown_arg"
)
set_tests_properties(compiler_cache_unknown_arg PROPERTIES
  PASS_REGULAR_EXPRESSION "unrecognized[ \t\r\n]+argument"
  FAIL_REGULAR_EXPRESSION "was[ \t\r\n]+accepted")

# Only the Makefile generators and Ninja run a compiler launcher, so the scenarios that
# assert one was set have to name such a generator instead of inheriting the default -- on
# Windows the default is Visual Studio, which the rule deliberately refuses. Visual Studio
# ships a Ninja that is not on PATH, and CMAKE_GENERATOR_INSTANCE points at the installation
# whenever the outer build uses a Visual Studio generator; in CI, lukka/get-cmake installs
# Ninja alongside CMake on all three runners. Without a Ninja none of the scenarios below can
# be expressed, and none are registered.
find_program(TARGETS_TEST_NINJA
  NAMES ninja ninja-build
  HINTS "${CMAKE_GENERATOR_INSTANCE}/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja"
  DOC "Ninja used by the compiler-cache tests to get a launcher-running generator")
if(TARGETS_TEST_NINJA)
  add_test(
    NAME compiler_cache_launcher_set
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=launcher_set
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_launcher_set"
  )

  add_test(
    NAME compiler_cache_base_dir
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=base_dir
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_base_dir"
  )

  # A launcher wired into a build tree outlives the configure that wired it, so a later
  # configure of the same tree that finds no cache binary must drop it rather than leave the
  # build pointing at a program that may no longer exist. These two share one build tree and
  # are ordered by the fixture: the first wires a launcher in, the second asks for a program
  # that does not exist and asserts nothing survived.
  add_test(
    NAME compiler_cache_stale_seed
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=launcher_set
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_stale"
  )
  set_tests_properties(compiler_cache_stale_seed PROPERTIES
    FIXTURES_SETUP compiler_cache_stale)

  add_test(
    NAME compiler_cache_stale_cleared
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=optional_missing
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_stale"
  )
  set_tests_properties(compiler_cache_stale_cleared PROPERTIES
    FIXTURES_REQUIRED compiler_cache_stale)

  # Registered only where case-insensitive paths make a BASE_DIR case mismatch possible; the
  # exit code decides.
  if(WIN32)
    add_test(
      NAME compiler_cache_base_dir_case_normalized
      COMMAND "${CMAKE_COMMAND}"
        -G Ninja
        "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
        -DSCENARIO=base_dir_case_normalized
        -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
        -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_base_dir_case_normalized"
    )
  endif()

  # The two ways a cache can be wired in and still never hit, which the rule warns about
  # rather than leaving silent: a BASE_DIR the sources are not under, and sccache, which
  # ignores CCACHE_BASEDIR altogether. Both keep the launcher -- the cost is hits, not
  # correctness -- so the PASS expression proves the warning fired and the FAIL expression
  # keeps a tripped assertion from hiding behind it.
  add_test(
    NAME compiler_cache_base_dir_outside
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=base_dir_outside
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_base_dir_outside"
  )
  set_tests_properties(compiler_cache_base_dir_outside PROPERTIES
    PASS_REGULAR_EXPRESSION "is[ \t\r\n]+not[ \t\r\n]+a[ \t\r\n]+prefix[ \t\r\n]+of[ \t\r\n]+the[ \t\r\n]+source"
    FAIL_REGULAR_EXPRESSION "CMake[ \t\r\n]+Error")

  add_test(
    NAME compiler_cache_base_dir_sibling_prefix
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=base_dir_sibling_prefix
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_base_dir_sibling_prefix"
  )
  set_tests_properties(compiler_cache_base_dir_sibling_prefix PROPERTIES
    PASS_REGULAR_EXPRESSION "is[ \t\r\n]+not[ \t\r\n]+a[ \t\r\n]+prefix[ \t\r\n]+of[ \t\r\n]+the[ \t\r\n]+source"
    FAIL_REGULAR_EXPRESSION "CMake[ \t\r\n]+Error")

  add_test(
    NAME compiler_cache_sccache_warning
    COMMAND "${CMAKE_COMMAND}"
      -G Ninja
      "-DCMAKE_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
      -DSCENARIO=sccache_warning
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_sccache_warning"
  )
  set_tests_properties(compiler_cache_sccache_warning PROPERTIES
    PASS_REGULAR_EXPRESSION "does[ \t\r\n]+not[ \t\r\n]+implement[ \t\r\n]+CCACHE_BASEDIR"
    FAIL_REGULAR_EXPRESSION "CMake[ \t\r\n]+Error")
endif()

# The compiler-cache tests above assert that a launcher was wired; this one compiles, which
# is the only way to tell a cache that hits from a launcher a generator accepted and dropped.
#
# Registered unconditionally: a machine lacking ccache, Ninja, or a developer environment
# gets a skip, which is visible in the CTest report, where a test omitted at configure time
# is not. The script's assertions are all FATAL_ERROR, so the exit code decides -- a
# PASS_REGULAR_EXPRESSION here would make CTest ignore that exit code.
add_test(
  NAME compiler_cache_cross_checkout
  COMMAND "${CMAKE_COMMAND}"
    "-DTARGETS_CMAKE_DIR=${CMAKE_CURRENT_LIST_DIR}/../cmake"
    "-DFIXTURE_DIR=${CMAKE_CURRENT_LIST_DIR}/integration/cache_cross_checkout/fixture"
    "-DSHARED_INCLUDE_SRC=${CMAKE_CURRENT_LIST_DIR}/integration/cache_cross_checkout/shared_include"
    "-DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/integration/cache_cross_checkout"
    -DTEST_GENERATOR=Ninja
    "-DTEST_MAKE_PROGRAM=${TARGETS_TEST_NINJA}"
    -P "${CMAKE_CURRENT_LIST_DIR}/integration/cache_cross_checkout/cross_checkout.cmake"
)
set_tests_properties(compiler_cache_cross_checkout PROPERTIES
  SKIP_REGULAR_EXPRESSION "TARGETS_TEST_SKIP")

# The guard itself, against a real Visual Studio generator rather than a simulated one. The
# outer generator is reused because it is the Visual Studio known to be installed.
if(CMAKE_GENERATOR MATCHES "Visual Studio")
  add_test(
    NAME compiler_cache_generator_guard
    COMMAND "${CMAKE_COMMAND}"
      -G "${CMAKE_GENERATOR}"
      -DSCENARIO=generator_guard
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/compiler_cache"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/compiler_cache_generator_guard"
  )
  set_tests_properties(compiler_cache_generator_guard PROPERTIES
    PASS_REGULAR_EXPRESSION "ignores[ \t\r\n]+compiler[ \t\r\n]+launchers"
    FAIL_REGULAR_EXPRESSION "CMake[ \t\r\n]+Error")
endif()

# MSVC Debug debug-information format. A compile cache rejects a translation unit whose debug
# info lands in a shared .pdb (/Zi, /ZI), so a configured compiler launcher has to move Debug
# to the embedded format (/Z7) -- and has to leave the edit-and-continue behavior alone where
# no launcher is configured. Every assertion is a FATAL_ERROR, so the exit code decides and
# no scenario needs a PASS expression that would make CTest ignore it. The scenarios run on
# every toolchain: off MSVC they assert none of these flags leaked there.
add_test(
  NAME cpp_target_debug_format_no_launcher
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=no_launcher
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_no_launcher"
)

# CMP0141 left OLD, so CMake spells the debug format in CMAKE_CXX_FLAGS_DEBUG and only a
# later flag can override it. The stripped variant takes that /Zi back out: the policy, not
# the flags it happens to produce, is what decides whether the property is honored, and a
# project that edits its own Debug flags must not strand Debug on a property CMake ignores.
add_test(
  NAME cpp_target_debug_format_launcher_flags
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=launcher_flags
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_launcher_flags"
)

add_test(
  NAME cpp_target_debug_format_launcher_flags_stripped
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=launcher_flags_stripped
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_launcher_flags_stripped"
)

# The scenarios that need CMP0141 NEW, where MSVC_DEBUG_INFORMATION_FORMAT is the route.
# Registered only when the CMake running them knows that policy, since the fixture sets it
# explicitly. Besides the property itself they pin the two ways the override stands down: a
# format the project named for itself is kept, while TARGETS_MSVC_EDIT_AND_CONTINUE=OFF is
# not an opt-out, having only ever governed /ZI.
if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.25)
  add_test(
    NAME cpp_target_debug_format_launcher_property
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=launcher_property
      -DDEBUG_FORMAT_POLICY=NEW
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_launcher_property"
  )

  add_test(
    NAME cpp_target_debug_format_launcher_user_format
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=launcher_user_format
      -DDEBUG_FORMAT_POLICY=NEW
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_launcher_user_format"
  )

  add_test(
    NAME cpp_target_debug_format_launcher_edit_and_continue_off
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=launcher_edit_and_continue_off
      -DDEBUG_FORMAT_POLICY=NEW
      -DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_debug_format"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_debug_format_edit_and_continue_off"
  )
endif()

# Target-wide settings must reach every compiled target, not only the ones cpp_target creates.
# flatbuffer_cpp_library, protobuf_cpp_library and embed_binary each build their target with
# their own add_library(), so they carry only what they apply themselves.
#
# The coverage scan reads the shipped CMake sources, so it covers a rule no test exercises;
# self_check reruns it against a copy in the build tree with one call deleted. Both decide by
# exit code, so neither needs a PASS expression.
add_test(
  NAME common_target_defaults_coverage
  COMMAND "${CMAKE_COMMAND}"
    -P "${CMAKE_CURRENT_LIST_DIR}/unit/test_common_target_defaults_coverage.cmake"
)

add_test(
  NAME common_target_defaults_coverage_self_check
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=self_check
    "-DMUTATED_DIR=${CMAKE_CURRENT_BINARY_DIR}/unit/common_target_defaults_mutated"
    -P "${CMAKE_CURRENT_LIST_DIR}/unit/test_common_target_defaults_coverage.cmake"
)

# The behavior itself, on targets the three rules really create. Both scenarios put those
# targets in module-scanning range and then assert the settings arrived -- CXX_SCAN_FOR_MODULES
# OFF, and /utf-8 on MSVC. Registered only on a CMake that knows CMP0155, which the fixture
# requires: below it CMake never scans and the assertions would hold for the wrong reason.
if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.28)
  add_test(
    NAME codegen_target_defaults_global_standard
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=global_standard
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/codegen_target_defaults"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/codegen_target_defaults_global_standard"
  )

  add_test(
    NAME codegen_target_defaults_interface_propagation
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=interface_propagation
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/codegen_target_defaults"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/codegen_target_defaults_interface_propagation"
  )

  # What the interface_propagation scenario cannot check for itself: that a dependency
  # carrying an INTERFACE compile feature really does raise a codegen target to C++20 or
  # later. The raise happens at generate time and leaves CXX_STANDARD reading whatever the
  # rule set, so this one compiles a probe and lets the compiler report the standard it was
  # given. Without it, interface_propagation asserts scanning is off on a target nothing
  # proved was in scanning range.
  add_test(
    NAME codegen_target_defaults_effective_standard
    COMMAND "${CMAKE_COMMAND}"
      "-DFIXTURE_DIR=${CMAKE_CURRENT_LIST_DIR}/integration/codegen_target_defaults/effective_standard"
      "-DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/integration/codegen_target_defaults_effective_standard"
      "-DTEST_GENERATOR=${CMAKE_GENERATOR}"
      "-DTEST_CONFIG=$<CONFIG>"
      -P "${CMAKE_CURRENT_LIST_DIR}/integration/codegen_target_defaults/effective_standard.cmake"
  )
endif()

# A library must offer consumers something: public files, public dependencies, or public usage
# requirements. One with none of those and no translation unit of its own archives only the
# placeholder and cannot affect a consumer, so it is rejected. Object code with no exposed
# interface stays legal, so the private-translation-unit scenario pins that the rule does not
# over-reach. Each public surface is asserted on its own because each is an independent path
# to false-rejecting a working library.
#
# The rejection scenarios pair their PASS pattern with a FAIL pattern on a marker printed
# after the rule returns: a FATAL_ERROR never reaches it, so a diagnostic demoted to a
# warning fails the test instead of passing it.
foreach(_scenario inert_empty inert_private_header)
  add_test(
    NAME cpp_library_${_scenario}
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=${_scenario}
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_public_surface"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_public_surface_${_scenario}"
  )
  set_tests_properties(cpp_library_${_scenario} PROPERTIES
    PASS_REGULAR_EXPRESSION "offers consumers nothing"
    FAIL_REGULAR_EXPRESSION "REACHED_END")
endforeach()

foreach(_case
    "private_tu;PRIVATE_TU_OK"
    "public_file;PUBLIC_FILE_OK"
    "public_dependencies;PUBLIC_DEPENDENCIES_OK"
    "public_includes;PUBLIC_INCLUDES_OK"
    "public_definitions;PUBLIC_DEFINITIONS_OK"
    "public_copts;PUBLIC_COPTS_OK"
    "public_linkopts;PUBLIC_LINKOPTS_OK"
    "platform_public_file;PLATFORM_PUBLIC_FILE_OK"
    "platform_private_tu;PLATFORM_PRIVATE_TU_OK"
    "legacy_headers;LEGACY_HEADERS_OK"
    "platform_legacy_headers;PLATFORM_LEGACY_HEADERS_OK"
    "private_dependencies;PRIVATE_DEPENDENCIES_OK"
    "binary_nothing_public;BINARY_OK")
  list(GET _case 0 _scenario)
  list(GET _case 1 _marker)
  add_test(
    NAME cpp_library_${_scenario}
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=${_scenario}
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_library_public_surface"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_library_public_surface_${_scenario}"
  )
  set_tests_properties(cpp_library_${_scenario} PROPERTIES
    PASS_REGULAR_EXPRESSION "${_marker}"
    FAIL_REGULAR_EXPRESSION "offers consumers nothing")
endforeach()

# Leaf targets imply PRIVATE. Nothing links a cpp_binary or a cpp_test, so every entry of a
# visibility-taking argument is private there: a bare list is the ordinary spelling, an
# explicit PRIVATE stays legal, and PUBLIC is rejected. Each of the six arguments is
# registered on its own, because each reaches the target through a different command and one
# of them taking the public path would put a leaf target's usage requirements where nothing
# reads them.
#
# The library scenarios are the other half of the claim: a bare list is still a configure
# error there, so the implied-private rule reached leaf targets and nothing else.
set(_targets_leaf_rejections
  "groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
  "must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC"
  "opens[ \t\r\n]+with[ \t\r\n]+the[ \t\r\n]+bare[ \t\r\n]+entry")

# An accepting scenario fails on a tripped assertion, on any of the visibility rejections, and
# on the deprecation banner -- a bare list is this grammar's ordinary spelling on a leaf
# target, not the deprecated one a library's bare SOURCES list is.
set(_targets_leaf_accept_failures
  "LEAF_ASSERT;${_targets_leaf_rejections};${_targets_deprecation_banner}")

foreach(_case
    "sources_bare_binary;SOURCES_BARE_BINARY_OK"
    "includes_bare_binary;INCLUDES_BARE_BINARY_OK"
    "definitions_bare_binary;DEFINITIONS_BARE_BINARY_OK"
    "copts_bare_binary;COPTS_BARE_BINARY_OK"
    "linkopts_bare_binary;LINKOPTS_BARE_BINARY_OK"
    "dependencies_bare_binary;DEPENDENCIES_BARE_BINARY_OK"
    "sources_bare_test;SOURCES_BARE_TEST_OK"
    "includes_bare_test;INCLUDES_BARE_TEST_OK"
    "definitions_bare_test;DEFINITIONS_BARE_TEST_OK"
    "copts_bare_test;COPTS_BARE_TEST_OK"
    "linkopts_bare_test;LINKOPTS_BARE_TEST_OK"
    "dependencies_bare_test;DEPENDENCIES_BARE_TEST_OK"
    "private_spelled_binary;PRIVATE_SPELLED_BINARY_OK"
    "private_spelled_test;PRIVATE_SPELLED_TEST_OK")
  list(GET _case 0 _scenario)
  list(GET _case 1 _marker)
  add_test(
    NAME cpp_target_leaf_${_scenario}
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=${_scenario}
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_implied_private"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_implied_private_${_scenario}"
  )
  set_tests_properties(cpp_target_leaf_${_scenario} PROPERTIES
    PASS_REGULAR_EXPRESSION "${_marker}"
    FAIL_REGULAR_EXPRESSION "${_targets_leaf_accept_failures}")
endforeach()

# A rejecting scenario halts on ACCEPTED when the call it makes goes through, and the FAIL
# expression matches that. A PASS expression alone makes CTest ignore the exit code, so a
# FATAL_ERROR demoted to a warning would print the wording the PASS expression looks for and
# pass -- and whether these diagnostics are errors is the whole of what is being tested.
foreach(_case
    "sources_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "includes_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "definitions_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "copts_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "linkopts_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "dependencies_public_binary;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "dependencies_public_test;groups[ \t\r\n]+entries[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "bare_then_private_binary;entry[ \t\r\n]+on[ \t\r\n]+an[ \t\r\n]+executable[ \t\r\n]+is[ \t\r\n]+private"
    "bare_then_private_dependencies_binary;entry[ \t\r\n]+on[ \t\r\n]+an[ \t\r\n]+executable[ \t\r\n]+is[ \t\r\n]+private"
    "includes_bare_library;must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "definitions_bare_library;must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "copts_bare_library;must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "linkopts_bare_library;must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC"
    "dependencies_bare_library;must[ \t\r\n]+be[ \t\r\n]+grouped[ \t\r\n]+under[ \t\r\n]+PUBLIC")
  list(GET _case 0 _scenario)
  list(GET _case 1 _diagnostic)
  add_test(
    NAME cpp_target_leaf_${_scenario}
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=${_scenario}
      -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_implied_private"
      -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_implied_private_${_scenario}"
  )
  set_tests_properties(cpp_target_leaf_${_scenario} PROPERTIES
    PASS_REGULAR_EXPRESSION "${_diagnostic}"
    FAIL_REGULAR_EXPRESSION "ACCEPTED")
endforeach()

# HEADERS is the deprecated spelling of SOURCES PUBLIC and stays accepted on every rule. A
# leaf target has no public SOURCES group for it to collide with, so grouped SOURCES beside
# HEADERS -- two spellings of one list on a library, and rejected there -- is a plain
# declaration here, and that library rejection joins the FAIL expression to say so. Two tests
# read the one scenario, because the deprecation report and the resolved file list are
# separate claims.
add_test(
  NAME cpp_target_leaf_headers_with_grouped_sources
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=headers_with_grouped_sources_binary
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_implied_private"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_implied_private_headers_grouped"
)
set_tests_properties(cpp_target_leaf_headers_with_grouped_sources PROPERTIES
  PASS_REGULAR_EXPRESSION "HEADERS_WITH_GROUPED_SOURCES_OK"
  FAIL_REGULAR_EXPRESSION
    "LEAF_ASSERT;${_targets_leaf_rejections};two[ \t\r\n]+spellings[ \t\r\n]+of[ \t\r\n]+the[ \t\r\n]+same")

add_test(
  NAME cpp_target_leaf_headers_deprecated
  COMMAND "${CMAKE_COMMAND}"
    -DSCENARIO=headers_with_grouped_sources_binary
    -S "${CMAKE_CURRENT_LIST_DIR}/integration/cpp_target_implied_private"
    -B "${CMAKE_CURRENT_BINARY_DIR}/integration/cpp_target_implied_private_headers_deprecated"
)
set_tests_properties(cpp_target_leaf_headers_deprecated PROPERTIES
  PASS_REGULAR_EXPRESSION "${_targets_deprecation_banner}[^\n]*cpp_target[.]cmake"
  FAIL_REGULAR_EXPRESSION "LEAF_ASSERT;${_targets_leaf_rejections}")
