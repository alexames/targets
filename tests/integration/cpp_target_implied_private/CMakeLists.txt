# Configure-mode tests for the visibility grammar of leaf targets.
#
# Nothing links a cpp_binary or a cpp_test, so every entry of a visibility-taking argument is
# private there and the keyword is implied: a bare list is the ordinary spelling, an explicit
# PRIVATE is redundant but legal, and PUBLIC is rejected, because on a leaf target it can only
# name an interface nothing can use. A library keeps the grammar it has -- every entry under a
# keyword -- and the library scenarios here are what says the two grammars did not merge.
#
# Each of the six arguments is checked on its own. Each reaches the target through a different
# command, and one of them quietly taking the public path would put a leaf target's usage
# requirements somewhere nothing reads them while the declaration still looks right.
#
# A single scenario is selected via -DSCENARIO=... and paired with PASS_REGULAR_EXPRESSION and
# FAIL_REGULAR_EXPRESSION in the enclosing CTest harness. An accepting scenario asserts the
# resolved target properties and halts on its own marker. A rejecting scenario halts on the
# word ACCEPTED, which the harness fails on, so a diagnostic demoted to a warning fails the
# test instead of passing it: a PASS pattern alone makes CTest ignore the exit code, and every
# scenario here exits non-zero by design.
#
# No language is enabled, so no toolchain is needed and every scenario halts during
# configuration, before generation would ask for a linker language.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetImpliedPrivate LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)
enable_testing()

if(NOT DEFINED SCENARIO)
  message(FATAL_ERROR "This test project requires -DSCENARIO=<name>")
endif()

# Stub Google Test so the cpp_test scenarios run network- and compiler-free. Providing
# GTest::gtest makes _targets_acquire_gtest() take its "already available" path, and
# GTest::gtest_main satisfies the link cpp_test() performs on its own. The helper still runs
# include(GoogleTest) after that skip, so neutralize just that include and stub
# gtest_discover_tests to a no-op: these scenarios check argument handling, not discovery.
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

# Separate private and public roots, so a file resolved against the wrong base names a path
# that is not there. The files live in the build tree to keep source_group(TREE) happy.
set(_source_dir "${CMAKE_CURRENT_BINARY_DIR}/src")
set(_header_dir "${CMAKE_CURRENT_BINARY_DIR}/include")
file(WRITE "${_source_dir}/main.cpp" "int main() { return 0; }\n")
file(WRITE "${_header_dir}/pub.hpp" "#pragma once\nint pub();\n")
set(_include_dir "${CMAKE_CURRENT_BINARY_DIR}/extra_include")
file(MAKE_DIRECTORY "${_include_dir}")

# A dependency for the DEPENDENCIES scenarios. import_dependencies skips a name that is
# already a target, and target_link_libraries needs it to exist.
add_library(LeafDep INTERFACE)
add_library(LeafDepTwo INTERFACE)

# Assert that TARGET's PROP holds VALUE, and that INTERFACE_PROP does not -- the pair is what
# says an entry took the private path rather than the public one. CONTEXT names the scenario;
# every failure here is prefixed LEAF_ASSERT, which the harness fails on, so a tripped
# assertion is never mistaken for the scenario's own halt.
function(assert_private CONTEXT TARGET PROP INTERFACE_PROP VALUE)
  get_target_property(private_value ${TARGET} ${PROP})
  if(NOT "${VALUE}" IN_LIST private_value)
    message(FATAL_ERROR
      "LEAF_ASSERT ${CONTEXT}: ${TARGET}'s ${PROP} does not hold '${VALUE}': ${private_value}")
  endif()
  get_target_property(interface_value ${TARGET} ${INTERFACE_PROP})
  if("${VALUE}" IN_LIST interface_value)
    message(FATAL_ERROR
      "LEAF_ASSERT ${CONTEXT}: ${TARGET}'s ${INTERFACE_PROP} holds '${VALUE}', so the entry "
      "took the public path: ${interface_value}")
  endif()
endfunction()

# Assert that TARGET's file list holds the SOURCE_DIR-resolved path and not the HEADER_DIR one.
# A bare file entry on a leaf target is private, which is what picks the base directory.
function(assert_private_file CONTEXT TARGET NAME)
  get_target_property(files ${TARGET} SOURCES)
  if(NOT "${_source_dir}/${NAME}" IN_LIST files)
    message(FATAL_ERROR
      "LEAF_ASSERT ${CONTEXT}: ${TARGET} did not resolve '${NAME}' against SOURCE_DIR: "
      "${files}")
  endif()
  if("${_header_dir}/${NAME}" IN_LIST files)
    message(FATAL_ERROR
      "LEAF_ASSERT ${CONTEXT}: ${TARGET} resolved '${NAME}' against HEADER_DIR: ${files}")
  endif()
endfunction()

# Spliced into every declaration below, so one pair of base directories serves them all.
set(_dirs SOURCE_DIR "${_source_dir}" HEADER_DIR "${_header_dir}")

# ---------------------------------------------------------------------------------------
# A bare list on cpp_binary: one scenario per visibility-taking argument.
# ---------------------------------------------------------------------------------------

if(SCENARIO STREQUAL "sources_bare_binary")
  cpp_binary(TARGET SourcesBareBinary ${_dirs} SOURCES "main.cpp")
  assert_private_file("${SCENARIO}" SourcesBareBinary "main.cpp")
  message(FATAL_ERROR "SOURCES_BARE_BINARY_OK")

elseif(SCENARIO STREQUAL "includes_bare_binary")
  cpp_binary(TARGET IncludesBareBinary ${_dirs} SOURCES "main.cpp" INCLUDES "${_include_dir}")
  assert_private("${SCENARIO}" IncludesBareBinary
    INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}")
  message(FATAL_ERROR "INCLUDES_BARE_BINARY_OK")

elseif(SCENARIO STREQUAL "definitions_bare_binary")
  cpp_binary(TARGET DefinitionsBareBinary ${_dirs} SOURCES "main.cpp" DEFINITIONS LEAF_FLAG=1)
  assert_private("${SCENARIO}" DefinitionsBareBinary
    COMPILE_DEFINITIONS INTERFACE_COMPILE_DEFINITIONS "LEAF_FLAG=1")
  message(FATAL_ERROR "DEFINITIONS_BARE_BINARY_OK")

elseif(SCENARIO STREQUAL "copts_bare_binary")
  cpp_binary(TARGET CoptsBareBinary ${_dirs} SOURCES "main.cpp" COPTS "-DFromCopts")
  assert_private("${SCENARIO}" CoptsBareBinary
    COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS "-DFromCopts")
  message(FATAL_ERROR "COPTS_BARE_BINARY_OK")

elseif(SCENARIO STREQUAL "linkopts_bare_binary")
  cpp_binary(TARGET LinkoptsBareBinary ${_dirs} SOURCES "main.cpp" LINKOPTS "-L/nowhere")
  assert_private("${SCENARIO}" LinkoptsBareBinary
    LINK_OPTIONS INTERFACE_LINK_OPTIONS "-L/nowhere")
  message(FATAL_ERROR "LINKOPTS_BARE_BINARY_OK")

elseif(SCENARIO STREQUAL "dependencies_bare_binary")
  cpp_binary(TARGET DependenciesBareBinary ${_dirs} SOURCES "main.cpp" DEPENDENCIES LeafDep)
  assert_private("${SCENARIO}" DependenciesBareBinary
    LINK_LIBRARIES INTERFACE_LINK_LIBRARIES "LeafDep")
  message(FATAL_ERROR "DEPENDENCIES_BARE_BINARY_OK")

# ---------------------------------------------------------------------------------------
# The same six on cpp_test, which forwards its own parse to cpp_target. GTest::gtest_main is
# linked by the rule itself, so the DEPENDENCIES scenario asserts on LeafDep alone.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "sources_bare_test")
  cpp_test(TARGET SourcesBareTest ${_dirs} SOURCES "main.cpp")
  assert_private_file("${SCENARIO}" SourcesBareTest "main.cpp")
  message(FATAL_ERROR "SOURCES_BARE_TEST_OK")

elseif(SCENARIO STREQUAL "includes_bare_test")
  cpp_test(TARGET IncludesBareTest ${_dirs} SOURCES "main.cpp" INCLUDES "${_include_dir}")
  assert_private("${SCENARIO}" IncludesBareTest
    INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}")
  message(FATAL_ERROR "INCLUDES_BARE_TEST_OK")

elseif(SCENARIO STREQUAL "definitions_bare_test")
  cpp_test(TARGET DefinitionsBareTest ${_dirs} SOURCES "main.cpp" DEFINITIONS LEAF_FLAG=1)
  assert_private("${SCENARIO}" DefinitionsBareTest
    COMPILE_DEFINITIONS INTERFACE_COMPILE_DEFINITIONS "LEAF_FLAG=1")
  message(FATAL_ERROR "DEFINITIONS_BARE_TEST_OK")

elseif(SCENARIO STREQUAL "copts_bare_test")
  cpp_test(TARGET CoptsBareTest ${_dirs} SOURCES "main.cpp" COPTS "-DFromCopts")
  assert_private("${SCENARIO}" CoptsBareTest
    COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS "-DFromCopts")
  message(FATAL_ERROR "COPTS_BARE_TEST_OK")

elseif(SCENARIO STREQUAL "linkopts_bare_test")
  cpp_test(TARGET LinkoptsBareTest ${_dirs} SOURCES "main.cpp" LINKOPTS "-L/nowhere")
  assert_private("${SCENARIO}" LinkoptsBareTest
    LINK_OPTIONS INTERFACE_LINK_OPTIONS "-L/nowhere")
  message(FATAL_ERROR "LINKOPTS_BARE_TEST_OK")

elseif(SCENARIO STREQUAL "dependencies_bare_test")
  cpp_test(TARGET DependenciesBareTest ${_dirs} SOURCES "main.cpp" DEPENDENCIES LeafDep)
  assert_private("${SCENARIO}" DependenciesBareTest
    LINK_LIBRARIES INTERFACE_LINK_LIBRARIES "LeafDep")
  message(FATAL_ERROR "DEPENDENCIES_BARE_TEST_OK")

# ---------------------------------------------------------------------------------------
# PUBLIC on a leaf target, one scenario per argument, plus one on cpp_test to show the
# rejection reaches the rule that forwards rather than only the one that parses.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "sources_public_binary")
  cpp_binary(TARGET SourcesPublicBinary ${_dirs} SOURCES PUBLIC "pub.hpp" PRIVATE "main.cpp")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "includes_public_binary")
  cpp_binary(TARGET IncludesPublicBinary ${_dirs} SOURCES "main.cpp"
    INCLUDES PUBLIC "${_include_dir}")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "definitions_public_binary")
  cpp_binary(TARGET DefinitionsPublicBinary ${_dirs} SOURCES "main.cpp"
    DEFINITIONS PUBLIC LEAF_FLAG=1)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "copts_public_binary")
  cpp_binary(TARGET CoptsPublicBinary ${_dirs} SOURCES "main.cpp" COPTS PUBLIC "-DFromCopts")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "linkopts_public_binary")
  cpp_binary(TARGET LinkoptsPublicBinary ${_dirs} SOURCES "main.cpp"
    LINKOPTS PUBLIC "-L/nowhere")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "dependencies_public_binary")
  cpp_binary(TARGET DependenciesPublicBinary ${_dirs} SOURCES "main.cpp"
    DEPENDENCIES PUBLIC LeafDep)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "dependencies_public_test")
  cpp_test(TARGET DependenciesPublicTest ${_dirs} SOURCES "main.cpp"
    DEPENDENCIES PUBLIC LeafDep)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

# ---------------------------------------------------------------------------------------
# An explicit PRIVATE on a leaf target: redundant, and legal. Forbidding it would make the
# leaf and library grammars differ for no reason, and one shared spelling is what lets a
# declaration move between the two rules.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "private_spelled_binary")
  cpp_binary(
    TARGET PrivateSpelledBinary
    ${_dirs}
    SOURCES PRIVATE "main.cpp"
    INCLUDES PRIVATE "${_include_dir}"
    DEFINITIONS PRIVATE LEAF_FLAG=1
    COPTS PRIVATE "-DFromCopts"
    LINKOPTS PRIVATE "-L/nowhere"
    DEPENDENCIES PRIVATE LeafDep)
  assert_private_file("${SCENARIO}" PrivateSpelledBinary "main.cpp")
  assert_private("${SCENARIO}" PrivateSpelledBinary
    INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}")
  assert_private("${SCENARIO}" PrivateSpelledBinary
    COMPILE_DEFINITIONS INTERFACE_COMPILE_DEFINITIONS "LEAF_FLAG=1")
  assert_private("${SCENARIO}" PrivateSpelledBinary
    COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS "-DFromCopts")
  assert_private("${SCENARIO}" PrivateSpelledBinary
    LINK_OPTIONS INTERFACE_LINK_OPTIONS "-L/nowhere")
  assert_private("${SCENARIO}" PrivateSpelledBinary
    LINK_LIBRARIES INTERFACE_LINK_LIBRARIES "LeafDep")
  message(FATAL_ERROR "PRIVATE_SPELLED_BINARY_OK")

elseif(SCENARIO STREQUAL "private_spelled_test")
  cpp_test(
    TARGET PrivateSpelledTest
    ${_dirs}
    SOURCES PRIVATE "main.cpp"
    INCLUDES PRIVATE "${_include_dir}"
    DEFINITIONS PRIVATE LEAF_FLAG=1
    COPTS PRIVATE "-DFromCopts"
    LINKOPTS PRIVATE "-L/nowhere"
    DEPENDENCIES PRIVATE LeafDep)
  assert_private_file("${SCENARIO}" PrivateSpelledTest "main.cpp")
  assert_private("${SCENARIO}" PrivateSpelledTest
    INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}")
  assert_private("${SCENARIO}" PrivateSpelledTest
    COMPILE_DEFINITIONS INTERFACE_COMPILE_DEFINITIONS "LEAF_FLAG=1")
  assert_private("${SCENARIO}" PrivateSpelledTest
    COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS "-DFromCopts")
  assert_private("${SCENARIO}" PrivateSpelledTest
    LINK_OPTIONS INTERFACE_LINK_OPTIONS "-L/nowhere")
  assert_private("${SCENARIO}" PrivateSpelledTest
    LINK_LIBRARIES INTERFACE_LINK_LIBRARIES "LeafDep")
  message(FATAL_ERROR "PRIVATE_SPELLED_TEST_OK")

# ---------------------------------------------------------------------------------------
# A leaf list that opens bare and names PRIVATE later. Read bare the keyword becomes a value;
# read as a group the entries ahead of it are dropped. Neither reading keeps what was written.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "bare_then_private_binary")
  cpp_binary(TARGET BareThenPrivateBinary ${_dirs} SOURCES "main.cpp" PRIVATE "pub.hpp")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "bare_then_private_dependencies_binary")
  # SOURCES reaches the leaf grammar through the file-list entry point and the other five
  # through the access-specifier one, so the shape is rejected on both routes.
  cpp_binary(TARGET BareThenPrivateDepsBinary ${_dirs} SOURCES "main.cpp"
    DEPENDENCIES LeafDep PRIVATE LeafDepTwo)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

# ---------------------------------------------------------------------------------------
# HEADERS, the deprecated spelling of SOURCES PUBLIC, is accepted on every rule for as long
# as it lasts, and still reports itself deprecated. A leaf target has no public SOURCES group
# for it to collide with, so grouped SOURCES beside HEADERS -- which a library rejects as two
# spellings of one list -- is a plain declaration here.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "headers_with_grouped_sources_binary")
  cpp_binary(
    TARGET HeadersGroupedBinary
    ${_dirs}
    SOURCES PRIVATE "main.cpp"
    HEADERS "pub.hpp")
  assert_private_file("${SCENARIO}" HeadersGroupedBinary "main.cpp")
  get_target_property(_files HeadersGroupedBinary SOURCES)
  if(NOT "${_header_dir}/pub.hpp" IN_LIST _files)
    message(FATAL_ERROR
      "LEAF_ASSERT ${SCENARIO}: HEADERS did not resolve against HEADER_DIR: ${_files}")
  endif()
  message(FATAL_ERROR "HEADERS_WITH_GROUPED_SOURCES_OK")

# ---------------------------------------------------------------------------------------
# A library keeps the grammar it has: a bare list is still rejected on every argument that
# takes a visibility, so the implied-private rule reached leaf targets and nothing else.
# SOURCES is absent here because a bare SOURCES list is the library's deprecated spelling,
# covered by tests/integration/cpp_target_arg_validation.
# ---------------------------------------------------------------------------------------

elseif(SCENARIO STREQUAL "includes_bare_library")
  cpp_library(TARGET IncludesBareLibrary ${_dirs} SOURCES PRIVATE "main.cpp"
    INCLUDES "${_include_dir}")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "definitions_bare_library")
  cpp_library(TARGET DefinitionsBareLibrary ${_dirs} SOURCES PRIVATE "main.cpp"
    DEFINITIONS LEAF_FLAG=1)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "copts_bare_library")
  cpp_library(TARGET CoptsBareLibrary ${_dirs} SOURCES PRIVATE "main.cpp" COPTS "-DFromCopts")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "linkopts_bare_library")
  cpp_library(TARGET LinkoptsBareLibrary ${_dirs} SOURCES PRIVATE "main.cpp"
    LINKOPTS "-L/nowhere")
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

elseif(SCENARIO STREQUAL "dependencies_bare_library")
  cpp_library(TARGET DependenciesBareLibrary ${_dirs} SOURCES PRIVATE "main.cpp"
    DEPENDENCIES LeafDep)
  message(FATAL_ERROR "${SCENARIO}: ACCEPTED")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
