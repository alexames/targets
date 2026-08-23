# Build-mode test for targets_enable_compiler_cache(): a compile in one checkout must be
# served from the cache entry an identical compile in a different checkout stored.
#
# The configure-mode tests beside this one assert on launcher properties and flags. This one
# compiles, because a launcher that is set and a cache that hits are different claims: every
# ccache counter reads zero under a generator that accepts the launcher and drops it, which
# is indistinguishable from a working cache.
#
# Run with `cmake -P`. Every argument is required:
#   TARGETS_CMAKE_DIR   Directory holding Targets.cmake; the fixture's module path.
#   FIXTURE_DIR         Project copied into each of the two checkouts.
#   SHARED_INCLUDE_SRC  Headers copied to a directory outside both checkouts.
#   WORK_DIR            Scratch tree; erased and rebuilt on every run.
#   TEST_GENERATOR      Generator for the inner builds. Must run a compiler launcher, so
#                       Ninja or a Makefile generator.
#   TEST_MAKE_PROGRAM   Absolute path to the build tool for TEST_GENERATOR.

cmake_minimum_required(VERSION 3.20)

foreach(argument
    TARGETS_CMAKE_DIR
    FIXTURE_DIR
    SHARED_INCLUDE_SRC
    WORK_DIR
    TEST_GENERATOR
    TEST_MAKE_PROGRAM)
  if(NOT DEFINED ${argument})
    message(FATAL_ERROR "cross_checkout: -D${argument} is required")
  endif()
endforeach()

# CTest turns this marker into a skipped result through SKIP_REGULAR_EXPRESSION. A missing
# prerequisite must not report a pass: this test is the only measurement of cross-checkout
# sharing, so a pass here would claim a property nothing checked.
#
# It must stay a macro. return() has to leave the script; from a function it would leave only
# the helper and let the run continue past the missing prerequisite.
macro(skip_test REASON)
  message(STATUS "TARGETS_TEST_SKIP: ${REASON}")
  return()
endmacro()

# Only Makefiles and Ninja run a compiler launcher, so the harness passes the build tool for
# one of them; with none installed there is nothing this test can measure.
if(NOT EXISTS "${TEST_MAKE_PROGRAM}")
  skip_test("no build tool for the '${TEST_GENERATOR}' generator")
endif()

# sccache is deliberately not accepted: it implements no CCACHE_BASEDIR, so the path rewriting
# this test measures does not happen under it.
find_program(cache_program NAMES ccache)
if(NOT cache_program)
  skip_test("no ccache on PATH; nothing here can observe a cache hit")
endif()

# The counters this test compares are global to a CCACHE_DIR, so it uses one of its own and
# starts it empty. Every inherited CCACHE_* setting goes first: the launcher
# targets_enable_compiler_cache() writes has to be the only thing configuring the cache, or a
# developer who exports CCACHE_BASEDIR gets a verdict the build rules did not earn. The whole
# namespace is cleared rather than a list of names, because the settings that would quietly
# invalidate the measurement are not a closed set.
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E environment
  OUTPUT_VARIABLE ambient_environment
  OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX MATCHALL "(^|\n)CCACHE_[A-Za-z0-9_]+=" inherited_settings "${ambient_environment}")
foreach(setting IN LISTS inherited_settings)
  string(REGEX REPLACE "^\n" "" setting "${setting}")
  string(REGEX REPLACE "=$" "" setting "${setting}")
  unset(ENV{${setting}})
endforeach()

set(cache_dir "${WORK_DIR}/ccache")
set(ENV{CCACHE_DIR} "${cache_dir}")

# Pinned against a system-wide ccache.conf, which clearing the environment does not reach.
# Statistics off would strand the comparison at zero; direct mode off would leave the
# direct-miss assertion below comparing 0 against 0 and still reporting a pass; depend mode
# changes which lookup runs, and the default is the one the launcher is built around.
set(ENV{CCACHE_STATS} "1")
set(ENV{CCACHE_DIRECT} "1")
set(ENV{CCACHE_NODEPEND} "1")

# Pull one counter's value out of PRINTED, the output of `ccache --print-stats`, which prints
# one `name<TAB>value` line per counter. NAME is the counter; its value lands in OUT_VAR in
# the caller's scope. A counter that is not present is a FATAL_ERROR, not a zero.
function(read_counter PRINTED NAME OUT_VAR)
  if(NOT PRINTED MATCHES "(^|\n)${NAME}[ \t]+([0-9]+)")
    message(FATAL_ERROR "cross_checkout: no '${NAME}' counter in:\n${PRINTED}")
  endif()
  set(${OUT_VAR} "${CMAKE_MATCH_2}" PARENT_SCOPE)
endfunction()

# Hits are summed across both of ccache's lookup modes, because either one means the compiler
# did not run. direct_cache_miss is read separately: it counts the direct-mode lookups that
# missed and fell back to the preprocessor, so a fresh one in the second checkout means the
# two compiles' direct-mode keys differ even where the preprocessed fallback still landed a
# hit.
function(read_stats HITS_VAR MISSES_VAR DIRECT_MISSES_VAR)
  execute_process(
    COMMAND "${cache_program}" --print-stats
    OUTPUT_VARIABLE printed
    RESULT_VARIABLE query_result
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT query_result EQUAL 0)
    message(FATAL_ERROR
      "cross_checkout: '${cache_program} --print-stats' failed (${query_result})")
  endif()

  read_counter("${printed}" direct_cache_hit direct_hits)
  read_counter("${printed}" preprocessed_cache_hit preprocessed_hits)
  read_counter("${printed}" cache_miss misses)
  read_counter("${printed}" direct_cache_miss direct_misses)
  math(EXPR total_hits "${direct_hits} + ${preprocessed_hits}")

  set(${HITS_VAR} "${total_hits}" PARENT_SCOPE)
  set(${MISSES_VAR} "${misses}" PARENT_SCOPE)
  set(${DIRECT_MISSES_VAR} "${direct_misses}" PARENT_SCOPE)
endfunction()

execute_process(
  COMMAND "${cache_program}" --print-stats
  OUTPUT_VARIABLE preflight
  RESULT_VARIABLE preflight_result
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT preflight_result EQUAL 0)
  skip_test("${cache_program} cannot --print-stats, so no hit can be counted")
endif()
foreach(counter direct_cache_hit preprocessed_cache_hit cache_miss direct_cache_miss)
  if(NOT preflight MATCHES "(^|\n)${counter}[ \t]")
    skip_test("${cache_program} --print-stats reports no '${counter}' counter")
  endif()
endforeach()

# cl.exe reads INCLUDE and LIB from the environment, so `cmake -G Ninja` cannot even identify
# it outside a developer command prompt. The generator that arranges that environment itself
# is Visual Studio, which is one of the generators that drops a compiler launcher, so this
# test cannot fall back to it.
set(dev_env_script "")
set(dev_env_arch "")
if(WIN32 AND NOT DEFINED ENV{VCINSTALLDIR})
  # vswhere.exe is installed under %ProgramFiles(x86)% whatever the rest of Windows is
  # localized to, and it is not on PATH. A parenthesis is not legal in a variable name written
  # literally inside $ENV{}, so the name is expanded indirectly.
  set(installer_root "ProgramFiles(x86)")
  find_program(vswhere
    NAMES vswhere
    HINTS "$ENV{${installer_root}}/Microsoft Visual Studio/Installer")
  if(NOT vswhere)
    skip_test("no developer environment: vswhere.exe was not found")
  endif()

  execute_process(
    COMMAND "${vswhere}"
      -latest
      -products *
      -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
      -property installationPath
    OUTPUT_VARIABLE visual_studio_dir
    RESULT_VARIABLE vswhere_result
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT vswhere_result EQUAL 0 OR NOT visual_studio_dir)
    skip_test("no developer environment: vswhere.exe found no C++ toolset")
  endif()

  set(dev_env_script "${visual_studio_dir}/VC/Auxiliary/Build/vcvarsall.bat")
  if(NOT EXISTS "${dev_env_script}")
    skip_test("no developer environment: '${dev_env_script}' does not exist")
  endif()

  # vcvarsall.bat takes the target architecture first. Cross-compiling is not this test's
  # subject, so it builds for the host.
  if("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "ARM64")
    set(dev_env_arch arm64)
  else()
    set(dev_env_arch x64)
  endif()
endif()

# Run one command, under the developer environment where the compiler needs one. The command
# goes into a batch file rather than a `cmd /c` argument string because cmd re-parses its own
# quoting and these paths can contain spaces.
function(run_step LABEL RESULT_VAR)
  if(dev_env_script)
    set(quoted_command "")
    foreach(argument IN LISTS ARGN)
      string(APPEND quoted_command " \"${argument}\"")
    endforeach()
    set(step_script "${WORK_DIR}/${LABEL}.bat")
    file(WRITE "${step_script}"
      "@echo off\n"
      "call \"${dev_env_script}\" ${dev_env_arch} >NUL\n"
      "if errorlevel 1 exit /b 1\n"
      "${quoted_command}\n")
    execute_process(COMMAND cmd /c "${step_script}" RESULT_VARIABLE step_result)
  else()
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE step_result)
  endif()
  set(${RESULT_VAR} "${step_result}" PARENT_SCOPE)
endfunction()

# Configure and build one checkout. The build directory sits at <checkout>/build in both:
# CCACHE_BASEDIR rewrites the absolute paths under it to paths relative to the compilation's
# working directory, which is that build directory, so the two checkouts only spell those
# paths the same way while their build directories sit at the same place under the root.
#
# Debug is the configuration cpp_target substitutes MSVC's embedded debug format into, so it
# is the one that exercises that substitution.
function(build_checkout NAME)
  set(checkout "${WORK_DIR}/${NAME}")

  run_step("configure_${NAME}" configure_result
    "${CMAKE_COMMAND}"
    -G "${TEST_GENERATOR}"
    "-DCMAKE_MAKE_PROGRAM=${TEST_MAKE_PROGRAM}"
    -DCMAKE_BUILD_TYPE=Debug
    "-DTARGETS_CMAKE_DIR=${TARGETS_CMAKE_DIR}"
    "-DSHARED_INCLUDE_DIR=${WORK_DIR}/shared_include"
    -S "${checkout}"
    -B "${checkout}/build")
  if(NOT configure_result EQUAL 0)
    message(FATAL_ERROR "cross_checkout: configuring ${NAME} failed (${configure_result})")
  endif()

  run_step("build_${NAME}" build_result
    "${CMAKE_COMMAND}" --build "${checkout}/build")
  if(NOT build_result EQUAL 0)
    message(FATAL_ERROR "cross_checkout: building ${NAME} failed (${build_result})")
  endif()
endfunction()

# The trailing slash on each source copies its contents; without one the directory itself
# would be nested inside the destination.
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${cache_dir}")
file(COPY "${SHARED_INCLUDE_SRC}/" DESTINATION "${WORK_DIR}/shared_include")
foreach(checkout treeA treeB)
  file(COPY "${FIXTURE_DIR}/" DESTINATION "${WORK_DIR}/${checkout}")
endforeach()

execute_process(
  COMMAND "${cache_program}" --zero-stats
  RESULT_VARIABLE zero_result
  OUTPUT_QUIET)
if(NOT zero_result EQUAL 0)
  message(FATAL_ERROR "cross_checkout: '${cache_program} --zero-stats' failed (${zero_result})")
endif()

build_checkout(treeA)
read_stats(first_hits first_misses first_direct_misses)
if(NOT first_hits EQUAL 0 OR first_misses EQUAL 0)
  message(FATAL_ERROR
    "cross_checkout: the first checkout recorded ${first_hits} hit(s) and ${first_misses} "
    "miss(es) against an empty cache, expected no hits and at least one miss. A hit in the "
    "second checkout proves nothing unless the first one is what stored the entry.")
endif()

build_checkout(treeB)
read_stats(second_hits second_misses second_direct_misses)

if(NOT second_hits GREATER first_hits)
  message(FATAL_ERROR
    "cross_checkout: the second checkout produced no cache hit (still ${second_hits}), so "
    "nothing it compiled was served from the entry the first checkout stored")
endif()
if(NOT second_misses EQUAL first_misses)
  message(FATAL_ERROR
    "cross_checkout: the second checkout recorded ${second_misses} miss(es) against the "
    "first checkout's ${first_misses}, so at least one compile hashed differently across "
    "the two")
endif()
if(NOT second_direct_misses EQUAL first_direct_misses)
  message(FATAL_ERROR
    "cross_checkout: the second checkout recorded ${second_direct_misses} direct miss(es) "
    "against the first checkout's ${first_direct_misses}. Its compile reached the cache by "
    "preprocessing first, so the two command lines differ somewhere CCACHE_BASEDIR did not "
    "rewrite.")
endif()

message(STATUS
  "cross_checkout: hits ${first_hits} -> ${second_hits}, misses ${first_misses} -> "
  "${second_misses}, direct misses ${first_direct_misses} -> ${second_direct_misses}")
