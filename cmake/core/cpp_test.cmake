# cpp_test.cmake
# Wrapper for creating C++ test targets with Google Test integration

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Acquire Google Test lazily, on the first cpp_test() call.
#
# Merely including this module (via include(Targets) / find_package(Targets))
# must have no side effects: consumers that define zero tests — or configure
# offline — must not trigger find_package(GTest) or a FetchContent clone of
# googletest. See https://github.com/alexames/targets/issues/3. A GLOBAL
# property guards the work so it runs at most once per configure.
function(_targets_acquire_gtest)
  get_property(_targets_gtest_acquired GLOBAL PROPERTY _TARGETS_GTEST_ACQUIRED)
  if(_targets_gtest_acquired)
    return()
  endif()

  # Check if Google Test is already available
  if(NOT TARGET GTest::gtest AND NOT TARGET gtest)
    # Try to find Google Test, promoting the imported targets it creates to GLOBAL scope.
    # Acquisition runs at most once per configure (guarded by _TARGETS_GTEST_ACQUIRED), but a
    # plain find_package(GTest) creates directory-scoped IMPORTED targets — visible only in the
    # directory that first called cpp_test() and its subdirectories. Every OTHER directory then
    # hits the run-once guard, skips acquisition, and cannot see GTest::gtest_main, so its
    # target_link_libraries(... GTest::gtest_main) fails at generate time. That broke any project
    # whose tests span sibling directories. See https://github.com/alexames/targets/issues/62.
    #
    # find_package's GLOBAL keyword (CMake >= 3.24) promotes the imported targets to global scope.
    # On older CMake we promote each imported target explicitly via IMPORTED_GLOBAL, which is only
    # settable from the directory that created the target — here, this very directory, where
    # find_package just created them (guarding the already-global case, which cannot be re-set).
    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
      find_package(GTest QUIET GLOBAL)
    else()
      find_package(GTest QUIET)
      if(GTest_FOUND)
        foreach(_targets_gtest_target
            GTest::gtest GTest::gtest_main GTest::gmock GTest::gmock_main)
          if(TARGET ${_targets_gtest_target})
            get_target_property(_targets_gtest_is_global
              ${_targets_gtest_target} IMPORTED_GLOBAL)
            if(NOT _targets_gtest_is_global)
              set_target_properties(${_targets_gtest_target}
                PROPERTIES IMPORTED_GLOBAL TRUE)
            endif()
          endif()
        endforeach()
      endif()
    endif()

    if(NOT GTest_FOUND)
      # Fall back to FetchContent if absent.
      #
      # This path needs no GLOBAL promotion. Unlike find_package's IMPORTED targets (directory
      # scoped, hence the promotion above — issue #62), FetchContent_MakeAvailable(googletest)
      # creates gtest/gtest_main — and the GTest::* ALIASes cpp_test() links — as REAL,
      # add_subdirectory-defined targets. Regular buildsystem target names and their ALIASes
      # resolve globally at generate time, so cpp_test() targets in sibling directories link
      # GTest::gtest_main without issue. IMPORTED_GLOBAL does not apply to these non-imported
      # targets, and is not needed. See https://github.com/alexames/targets/issues/62.
      include(FetchContent)

      # Add the fetched googletest with EXCLUDE_FROM_ALL so its targets are NOT part of the
      # default ALL build — they compile only when a cpp_test target actually links them.
      # Without this the fetched gtest/gmock pollute a consumer's default build even when no
      # test is ever built. FetchContent_Declare gained the EXCLUDE_FROM_ALL option in CMake
      # 3.28; on older CMake we omit it (configuration still succeeds) rather than break.
      # See https://github.com/alexames/targets/issues/10.
      set(_targets_gtest_exclude_from_all "")
      if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28")
        set(_targets_gtest_exclude_from_all EXCLUDE_FROM_ALL)
      endif()

      FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.2
        ${_targets_gtest_exclude_from_all}
        FIND_PACKAGE_ARGS NAMES GTest
      )

      # On Windows/MSVC, build googletest against the shared CRT so it matches the default
      # consumer runtime and avoids CRT-mismatch link errors.
      set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

      # Do not let the fetched googletest contribute install() rules: a consumer running
      # `cmake --install` must not deposit gtest/gmock headers, libraries, or package config
      # into its install prefix. Must be set before FetchContent_MakeAvailable so
      # googletest's option(INSTALL_GTEST ...) picks up the forced OFF value.
      # See https://github.com/alexames/targets/issues/10.
      set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)

      FetchContent_MakeAvailable(googletest)

      # Organize Google Test targets in IDE
      if(TARGET gtest)
        set_target_properties(gtest PROPERTIES FOLDER "ThirdParty/GoogleTest")
      endif()
      if(TARGET gtest_main)
        set_target_properties(gtest_main PROPERTIES FOLDER "ThirdParty/GoogleTest")
      endif()
      if(TARGET gmock)
        set_target_properties(gmock PROPERTIES FOLDER "ThirdParty/GoogleTest")
      endif()
      if(TARGET gmock_main)
        set_target_properties(gmock_main PROPERTIES FOLDER "ThirdParty/GoogleTest")
      endif()
    endif()
  endif()

  # Include GoogleTest module for test discovery (provides gtest_discover_tests)
  include(GoogleTest)

  set_property(GLOBAL PROPERTY _TARGETS_GTEST_ACQUIRED TRUE)
endfunction()

# Map a Bazel-style test SIZE to a default CTest TIMEOUT (in seconds), returned in OUT_VAR.
# The mapping mirrors Bazel's default per-size test timeout (small=60, medium=300, large=900,
# enormous=3600). An explicit TIMEOUT on cpp_test always overrides this size-derived default.
# An unknown size fails fast with a clear message (issue #27).
function(_targets_test_size_timeout SIZE OUT_VAR)
  string(TOLOWER "${SIZE}" _size)
  if(_size STREQUAL "small")
    set(${OUT_VAR} 60 PARENT_SCOPE)
  elseif(_size STREQUAL "medium")
    set(${OUT_VAR} 300 PARENT_SCOPE)
  elseif(_size STREQUAL "large")
    set(${OUT_VAR} 900 PARENT_SCOPE)
  elseif(_size STREQUAL "enormous")
    set(${OUT_VAR} 3600 PARENT_SCOPE)
  else()
    message(FATAL_ERROR
      "cpp_test: SIZE '${SIZE}' is not a valid size. Choose one of: small, medium, large, "
      "enormous.")
  endif()
endfunction()

# Define a C++ test target.
#
# Testing must be enabled at the CONSUMER'S TOP LEVEL: call include(CTest) (which also
# defines the standard BUILD_TESTING option) or enable_testing() in the top-level
# CMakeLists.txt. This module deliberately does NOT call enable_testing() at include
# time. enable_testing() only takes effect for the directory scope in which it runs, and
# this file is include-guarded, so enabling testing from whatever subdirectory happens to
# include Targets first would silently drop tests registered in sibling/parent scopes from
# CTest. See https://github.com/alexames/targets/issues/9.
function(cpp_test)
  # Honor the standard CTest opt-out. When BUILD_TESTING is explicitly OFF (typically set
  # by include(CTest)), create no test target and acquire no test framework. Left
  # undefined, tests are still created — matching CTest's own default-on behavior.
  if(DEFINED BUILD_TESTING AND NOT BUILD_TESTING)
    return()
  endif()

  # Acquire the test framework on first use (deferred from module include time
  # so a bare include(Targets) never touches the network — see issue #3).
  _targets_acquire_gtest()

  # Parse the FULL cpp_target keyword signature plus the four test-only attributes
  # SIZE/TIMEOUT/LABELS/ARGS (issue #27). Recognizing every cpp_target keyword is essential:
  # LABELS and ARGS are multi-value, so a parse that knew ONLY the test-only keywords would
  # let them greedily swallow any cpp_target keyword written after them (e.g.
  # `LABELS unit SOURCES a.cpp` would absorb `SOURCES a.cpp`). With the full signature known,
  # each keyword terminates the previous multi-value list at the right boundary regardless of
  # argument order. The keyword lists mirror cpp_target's; keep them in sync when cpp_target
  # gains a keyword (an unmirrored keyword still works -- it lands in _t_UNPARSED_ARGUMENTS and
  # is forwarded below -- but would not terminate a preceding LABELS/ARGS list).
  set(_ct_options
    STATIC SHARED UNITY_BUILD INSTALL EXPORT_HEADER WINDOWS_EXPORT_ALL_SYMBOLS WERROR LTO)
  set(_ct_one_value
    TYPE TARGET EXPORT FOLDER SOURCE_DIR HEADER_DIR WORKING_DIRECTORY COMMAND_ARGUMENTS
    CXX_STANDARD VERSION SOVERSION UNITY_BUILD_BATCH_SIZE NAMESPACE_ROOT WARNINGS)
  set(_ct_multi
    SOURCES HEADERS INCLUDES DEFINITIONS DEPENDENCIES COPTS LINKOPTS DATA PROPERTIES
    PRECOMPILE_HEADERS SANITIZERS)
  # ALLOW_NO_TESTS is a test-only option (issue #28), like SIZE/TIMEOUT/LABELS/ARGS: it is
  # consumed here and never forwarded to cpp_target (the forwarding loops below iterate only the
  # cpp_target keyword lists, so it cannot leak into cpp_target's unknown-keyword rejection).
  cmake_parse_arguments(PARSE_ARGV 0 _t
    "${_ct_options};ALLOW_NO_TESTS"
    "${_ct_one_value};SIZE;TIMEOUT"
    "${_ct_multi};LABELS;ARGS")

  if(NOT _t_TARGET)
    message(FATAL_ERROR "cpp_test: TARGET argument is required")
  endif()

  # A test-only keyword written with no value is almost certainly a mistake; warn rather than
  # drop it silently (mirrors _targets_check_args' missing-value handling). Missing values on
  # forwarded cpp_target keywords are reported by cpp_target's own validation below.
  foreach(_k IN ITEMS SIZE TIMEOUT LABELS ARGS)
    if("${_k}" IN_LIST _t_KEYWORDS_MISSING_VALUES)
      message(WARNING "cpp_test: keyword ${_k} was given with no value(s); ignored.")
    endif()
  endforeach()

  # Reconstruct the argument list to forward to cpp_target: every cpp_target keyword the caller
  # gave (the four test-only attributes are consumed here, never forwarded, so cpp_target's
  # unknown-keyword rejection does not trip on them), plus anything cpp_target could not
  # classify so its own validation still rejects misspelled/pre-keyword tokens (issue #4).
  # cpp_target parses by keyword, so the reconstructed order is irrelevant.
  set(_forward_args "")
  foreach(_opt IN LISTS _ct_options)
    if(_t_${_opt})
      list(APPEND _forward_args ${_opt})
    endif()
  endforeach()
  foreach(_kw IN LISTS _ct_one_value)
    if(DEFINED _t_${_kw})
      list(APPEND _forward_args ${_kw} "${_t_${_kw}}")
    endif()
  endforeach()
  foreach(_kw IN LISTS _ct_multi)
    if(DEFINED _t_${_kw})
      list(APPEND _forward_args ${_kw} ${_t_${_kw}})
    endif()
  endforeach()
  if(NOT "${_t_UNPARSED_ARGUMENTS}" STREQUAL "")
    list(APPEND _forward_args ${_t_UNPARSED_ARGUMENTS})
  endif()

  # Resolve the effective CTest TIMEOUT up front so a bad SIZE fails fast. An explicit TIMEOUT
  # wins; otherwise SIZE maps to a default (documented in _targets_test_size_timeout); with
  # neither, no timeout is set. A numeric TIMEOUT is required — CTest expects seconds.
  set(_effective_timeout "")
  if(DEFINED _t_TIMEOUT)
    if(NOT "${_t_TIMEOUT}" MATCHES "^[0-9]+$")
      message(FATAL_ERROR
        "cpp_test: TIMEOUT '${_t_TIMEOUT}' must be a non-negative integer number of seconds.")
    endif()
    set(_effective_timeout "${_t_TIMEOUT}")
  elseif(DEFINED _t_SIZE)
    _targets_test_size_timeout("${_t_SIZE}" _effective_timeout)
  endif()

  # Default the IDE folder to "Tests" unless the caller set one explicitly. Detect presence
  # with DEFINED rather than truthiness so a falsey-but-valid folder name (e.g. a folder
  # literally named "0" or "OFF") is honored instead of silently triggering the default
  # (see issue #15). cpp_target applies the FOLDER value; putting the default ahead of the
  # forwarded args lets an explicit user FOLDER, if present there, win over it.
  set(_folder_default "")
  if(NOT DEFINED _t_FOLDER)
    set(_folder_default FOLDER "Tests")
  endif()

  # Create the test executable. Forward the cpp_target arguments (the test-only attributes
  # stripped above); cpp_target does the full argument validation, applies FOLDER/PROPERTIES,
  # and stages any DATA next to the test binary.
  cpp_target(
    TYPE EXECUTABLE
    ${_folder_default}
    ${_forward_args})

  # Link the GTest entry point — every test needs it — and register the tests with CTest.
  # cpp_target validated and created ${_t_TARGET}, so it exists here.
  target_link_libraries(${_t_TARGET} PRIVATE GTest::gtest_main)

  # Register the tests with CTest. WORKING_DIRECTORY and EXTRA_ARGS pass safely through
  # gtest_discover_tests:
  #   - WORKING_DIRECTORY: an explicit value wins; otherwise, when DATA was staged next to the
  #     binary, default to the binary's directory ($<TARGET_FILE_DIR:...>) so the test finds
  #     its data via a relative path. With neither, gtest_discover_tests uses its own default.
  #   - EXTRA_ARGS (from ARGS): passed to the test executable when CTest RUNS it. This is
  #     distinct from cpp_target's COMMAND_ARGUMENTS, which only sets the Visual Studio
  #     debugger's F5 arguments (VS_DEBUGGER_COMMAND_ARGUMENTS) and does not affect ctest.
  # TEST_LIST captures the names of the discovered tests so the remaining per-test properties
  # can be applied below.
  set(_discover_args ${_t_TARGET} TEST_LIST ${_t_TARGET}_TESTS)
  if(DEFINED _t_WORKING_DIRECTORY)
    list(APPEND _discover_args WORKING_DIRECTORY "${_t_WORKING_DIRECTORY}")
  elseif(_t_DATA)
    list(APPEND _discover_args WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_t_TARGET}>")
  endif()
  if(_t_ARGS)
    list(APPEND _discover_args EXTRA_ARGS ${_t_ARGS})
  endif()
  gtest_discover_tests(${_discover_args})

  # Apply the TIMEOUT (from TIMEOUT/SIZE) and LABELS attributes to every discovered test, and --
  # unless ALLOW_NO_TESTS was given -- guard against a test binary that registered ZERO GoogleTest
  # cases (issue #28). gtest_discover_tests discovers tests at BUILD time, so the individual CTest
  # tests do not exist at configure time and can be neither given properties nor counted directly
  # here. Both concerns are handled from ONE generated CTest include file that CTest processes at
  # test time, AFTER gtest's own discovery output has populated ${_t_TARGET}_TESTS (this append
  # follows gtest_discover_tests' own TEST_INCLUDE_FILES append). In that file:
  #   - a non-empty ${_t_TARGET}_TESTS gets the SIZE/TIMEOUT/LABELS properties (issue #27).
  #     gtest_discover_tests' own PROPERTIES option is unusable for LABELS: it forwards each token
  #     verbatim to set_tests_properties, so a multi-valued LABELS list ('unit;fast') loses every
  #     label but the first, and the ';' is mangled into a broken command line on the Visual
  #     Studio generator. A plain quoted string in a script file has no such escaping to mangle.
  #   - an EMPTY ${_t_TARGET}_TESTS registers an always-failing CTest test, so `ctest` goes red
  #     instead of silently reporting success for a suite that tested nothing. Zero cases is a
  #     clean (empty) discovery -- no TEST()/TEST_F(), a --gtest_filter that matched nothing, or a
  #     mislink that dropped the registration TU -- which CTest would otherwise pass over in
  #     silence. The failure runs a generated probe script whose message(FATAL_ERROR ...) names
  #     the target and points at the ALLOW_NO_TESTS opt-out.
  set(_prop_pairs "")
  if(NOT "${_effective_timeout}" STREQUAL "")
    string(APPEND _prop_pairs " TIMEOUT ${_effective_timeout}")
  endif()
  if(_t_LABELS)
    string(APPEND _prop_pairs " LABELS \"${_t_LABELS}\"")
  endif()

  # The empty-suite guard is on by default; ALLOW_NO_TESTS opts a deliberately test-free binary
  # out of it (the rare intentional case called out in issue #28).
  set(_guard_empty TRUE)
  if(_t_ALLOW_NO_TESTS)
    set(_guard_empty FALSE)
  endif()

  # Emit the include file when there are per-test properties to apply OR the empty-suite guard is
  # active; if neither applies (ALLOW_NO_TESTS with no SIZE/TIMEOUT/LABELS) there is nothing to do.
  if(NOT "${_prop_pairs}" STREQUAL "" OR _guard_empty)
    set(_prop_include "${CMAKE_CURRENT_BINARY_DIR}/${_t_TARGET}_cpp_test_props.cmake")

    if(_guard_empty)
      # A standalone probe script the failing CTest test runs; message(FATAL_ERROR ...) in
      # `cmake -P` mode prints the message and exits non-zero, so the test fails loudly.
      set(_probe "${CMAKE_CURRENT_BINARY_DIR}/${_t_TARGET}_no_tests_probe.cmake")
      file(WRITE "${_probe}"
        "# Generated by cpp_test() (issue #28): run as an always-failing CTest test when the\n"
        "# '${_t_TARGET}' test binary registered zero GoogleTest cases.\n"
        "message(FATAL_ERROR\n"
        "  \"cpp_test: test target '${_t_TARGET}' registered zero GoogleTest cases. Its binary \"\n"
        "  \"defines no TEST()/TEST_F() (or a --gtest_filter matched nothing, or a mislink \"\n"
        "  \"dropped the test-registration translation unit), so CTest would otherwise report \"\n"
        "  \"success while testing nothing. Add the missing tests, or pass ALLOW_NO_TESTS to \"\n"
        "  \"cpp_test() if this target is intentionally empty.\")\n")
    endif()

    # Assemble the include file body. ${_t_TARGET} expands now (to the target name); the escaped
    # \${...} and the baked-in ${CMAKE_COMMAND} are left as literals to be resolved at test time
    # (CMAKE_COMMAND is NOT defined in CTest's script scope, so its path is embedded here). Both
    # paths are quoted to tolerate spaces.
    set(_content "")
    string(APPEND _content
      "# Generated by cpp_test() (issues #27, #28): apply per-test properties to the discovered\n")
    string(APPEND _content
      "# tests, and fail loudly when the binary registered zero GoogleTest cases (unless\n")
    string(APPEND _content
      "# ALLOW_NO_TESTS). CTest processes this at test time, after gtest populated the test list.\n")
    string(APPEND _content
      "if(${_t_TARGET}_TESTS)\n")
    if(NOT "${_prop_pairs}" STREQUAL "")
      string(APPEND _content
        "  set_tests_properties(\${${_t_TARGET}_TESTS} PROPERTIES${_prop_pairs})\n")
    endif()
    if(_guard_empty)
      string(APPEND _content
        "else()\n")
      # CTest processes this include file in its script scope, where add_test only accepts the
      # classic positional signature add_test(<name> <command> [args...]) -- the NAME/COMMAND
      # keyword form is a CMakeLists-only spelling and is silently misparsed here (the very form
      # gtest_discover_tests itself emits into its generated include). Name first, then the
      # command and its args.
      string(APPEND _content
        "  add_test(${_t_TARGET}_no_tests_registered\n")
      string(APPEND _content
        "    \"${CMAKE_COMMAND}\" -P \"${_probe}\")\n")
      if(NOT "${_prop_pairs}" STREQUAL "")
        # Carry LABELS onto the guard test too, so a label-filtered `ctest -L <label>` still
        # surfaces the empty suite instead of silently running nothing.
        string(APPEND _content
          "  set_tests_properties(${_t_TARGET}_no_tests_registered PROPERTIES${_prop_pairs})\n")
      endif()
    endif()
    string(APPEND _content
      "endif()\n")

    file(WRITE "${_prop_include}" "${_content}")
    set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES "${_prop_include}")
  endif()
endfunction()
