# Configure-mode tests for targets_enable_compiler_cache().
#
# A single scenario is selected via -DSCENARIO=... and paired with the CTest properties in
# the enclosing harness. The project enables no languages, so no scenario needs a C++
# toolchain; the scenarios that must reach the generate step do so with nothing to compile.
#
# Most positive scenarios name ${CMAKE_COMMAND} as the cache PROGRAM. The rule only requires
# that find_program() resolve the name -- it never runs the binary -- and cmake is the one
# executable guaranteed to exist on every machine that can run this test, so the assertions
# do not depend on ccache being installed.

cmake_minimum_required(VERSION 3.20)
project(TestCompilerCache LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# Assert that nothing was wired: the two launchers and the resolved-program variable are all
# still undefined. CONTEXT names the scenario in the diagnostic.
function(assert_no_launcher CONTEXT)
  foreach(variable
      CMAKE_C_COMPILER_LAUNCHER
      CMAKE_CXX_COMPILER_LAUNCHER
      TARGETS_COMPILER_CACHE)
    if(DEFINED ${variable})
      message(FATAL_ERROR
        "${CONTEXT}: ${variable} is set to '${${variable}}', expected it to be left unset")
    endif()
  endforeach()
endfunction()

# Assert that both launchers were wired around PROGRAM with BASE_DIR as CCACHE_BASEDIR.
# CONTEXT names the scenario in the diagnostic. Fails outright unless the generator runs
# launchers, so a scenario using this must select Ninja or a Makefile generator.
function(assert_launcher CONTEXT PROGRAM BASE_DIR)
  if(NOT CMAKE_GENERATOR MATCHES "Makefiles|Ninja")
    message(FATAL_ERROR
      "${CONTEXT}: the '${CMAKE_GENERATOR}' generator does not run compiler launchers, so "
      "this scenario cannot assert that one was set")
  endif()
  if(NOT "${TARGETS_COMPILER_CACHE}" STREQUAL "${PROGRAM}")
    message(FATAL_ERROR
      "${CONTEXT}: TARGETS_COMPILER_CACHE is '${TARGETS_COMPILER_CACHE}', expected "
      "'${PROGRAM}'")
  endif()
  foreach(variable CMAKE_C_COMPILER_LAUNCHER CMAKE_CXX_COMPILER_LAUNCHER)
    set(launcher "${${variable}}")
    if(NOT launcher)
      message(FATAL_ERROR "${CONTEXT}: ${variable} is unset")
    endif()

    # `cmake -E env` must wrap the cache binary, or the settings below travel in the
    # developer's environment instead of the build tree.
    list(GET launcher 0 argv0)
    list(SUBLIST launcher 1 2 env_flags)
    if(NOT "${argv0}" STREQUAL "${CMAKE_COMMAND}" OR NOT "${env_flags}" STREQUAL "-E;env")
      message(FATAL_ERROR
        "${CONTEXT}: ${variable} does not start with 'cmake -E env': ${launcher}")
    endif()

    if(NOT "CCACHE_BASEDIR=${BASE_DIR}" IN_LIST launcher)
      message(FATAL_ERROR
        "${CONTEXT}: ${variable} lacks CCACHE_BASEDIR=${BASE_DIR}: ${launcher}")
    endif()
    if(NOT "CCACHE_NOHASHDIR=1" IN_LIST launcher)
      message(FATAL_ERROR
        "${CONTEXT}: ${variable} lacks CCACHE_NOHASHDIR=1: ${launcher}")
    endif()

    list(GET launcher -1 launched)
    if(NOT "${launched}" STREQUAL "${PROGRAM}")
      message(FATAL_ERROR
        "${CONTEXT}: ${variable} launches '${launched}', expected '${PROGRAM}': ${launcher}")
    endif()
    message(STATUS "${CONTEXT}: ${variable}=${launcher}")
  endforeach()
endfunction()

if(SCENARIO STREQUAL "required_missing")
  # REQUIRED must turn a missing cache binary into a hard configure failure.
  targets_enable_compiler_cache(PROGRAM targets_no_such_compiler_cache REQUIRED)
  message(FATAL_ERROR "required_missing: REQUIRED did not fail on a missing cache binary")

elseif(SCENARIO STREQUAL "optional_missing")
  # Without REQUIRED the same missing binary must warn, leave the build uncached, and
  # configure to the end.
  targets_enable_compiler_cache(PROGRAM targets_no_such_compiler_cache)
  assert_no_launcher("optional_missing")

elseif(SCENARIO STREQUAL "foreign_launcher_kept")
  # A launcher the project wired up for itself is not this rule's to remove. Declining to
  # enable caching clears what the rule left in an earlier configure, and nothing else.
  if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
    message(FATAL_ERROR
      "foreign_launcher_kept: the harness must supply a launcher for the rule to leave alone")
  endif()
  set(foreign "${CMAKE_CXX_COMPILER_LAUNCHER}")
  targets_enable_compiler_cache(PROGRAM targets_no_such_compiler_cache)
  if(NOT "${CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "${foreign}")
    message(FATAL_ERROR
      "foreign_launcher_kept: CMAKE_CXX_COMPILER_LAUNCHER is now "
      "'${CMAKE_CXX_COMPILER_LAUNCHER}', expected '${foreign}'")
  endif()

elseif(SCENARIO STREQUAL "unknown_arg")
  # A misspelled keyword must be rejected rather than silently ignored, the same as in every
  # other rule.
  targets_enable_compiler_cache(PROGRAMS "${CMAKE_COMMAND}")
  message(FATAL_ERROR "unknown_arg: a misspelled keyword was accepted")

elseif(SCENARIO STREQUAL "launcher_set")
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}")
  assert_launcher("launcher_set" "${CMAKE_COMMAND}" "${CMAKE_SOURCE_DIR}")

elseif(SCENARIO STREQUAL "base_dir")
  # An explicit BASE_DIR above the source tree, which is what a project embedded in a larger
  # checkout needs so the whole checkout is rewritten and not just this subdirectory.
  get_filename_component(outer_dir "${CMAKE_SOURCE_DIR}" PATH)
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}" BASE_DIR "${outer_dir}")
  assert_launcher("base_dir" "${CMAKE_COMMAND}" "${outer_dir}")

elseif(SCENARIO STREQUAL "base_dir_case_normalized")
  # The case trap documented on targets_enable_compiler_cache(): an upper-cased path opens
  # the same directory on Windows, so only ccache notices. The rule must hand it the on-disk
  # spelling whatever case it was given.
  if(NOT WIN32)
    message(FATAL_ERROR
      "base_dir_case_normalized: paths are case sensitive here, so an upper-cased BASE_DIR "
      "names a different directory and there is nothing to normalize")
  endif()
  string(TOUPPER "${CMAKE_SOURCE_DIR}" shouting_dir)
  if("${shouting_dir}" STREQUAL "${CMAKE_SOURCE_DIR}")
    message(FATAL_ERROR
      "base_dir_case_normalized: '${CMAKE_SOURCE_DIR}' has no lowercase letters to change, "
      "so this scenario cannot build a case-mismatched base directory")
  endif()
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}" BASE_DIR "${shouting_dir}")
  assert_launcher("base_dir_case_normalized" "${CMAKE_COMMAND}" "${CMAKE_SOURCE_DIR}")

elseif(SCENARIO STREQUAL "base_dir_outside")
  # Pointing BASE_DIR at a subdirectory instead of the checkout root leaves the sources
  # outside it, so ccache rewrites nothing. That costs hits rather than correctness, so the
  # rule warns and still wires the launcher.
  set(inner_dir "${CMAKE_SOURCE_DIR}/not_an_ancestor")
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}" BASE_DIR "${inner_dir}")
  assert_launcher("base_dir_outside" "${CMAKE_COMMAND}" "${inner_dir}")

elseif(SCENARIO STREQUAL "base_dir_sibling_prefix")
  # A directory whose name merely starts the same way as the source tree's is not an ancestor
  # of it, and a plain string-prefix test would call it one.
  string(REGEX REPLACE ".$" "" truncated_dir "${CMAKE_SOURCE_DIR}")
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}" BASE_DIR "${truncated_dir}")
  assert_launcher("base_dir_sibling_prefix" "${CMAKE_COMMAND}" "${truncated_dir}")

elseif(SCENARIO STREQUAL "sccache_warning")
  # An empty file named sccache is enough: only its name reaches the rule, which matches on
  # the basename and never runs the binary. No real sccache installation is involved.
  set(fake_sccache "${CMAKE_CURRENT_BINARY_DIR}/fake_bin/sccache")
  file(WRITE "${fake_sccache}" "")
  file(CHMOD "${fake_sccache}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)
  targets_enable_compiler_cache(PROGRAM "${fake_sccache}")
  assert_launcher("sccache_warning" "${fake_sccache}" "${CMAKE_SOURCE_DIR}")

elseif(SCENARIO STREQUAL "generator_guard")
  if(CMAKE_GENERATOR MATCHES "Makefiles|Ninja")
    message(FATAL_ERROR
      "generator_guard: the '${CMAKE_GENERATOR}' generator runs compiler launchers, so this "
      "scenario would pass against unguarded code")
  endif()
  targets_enable_compiler_cache(PROGRAM "${CMAKE_COMMAND}")
  assert_no_launcher("generator_guard")

else()
  message(FATAL_ERROR "test harness: unknown or unset SCENARIO '${SCENARIO}'")
endif()
