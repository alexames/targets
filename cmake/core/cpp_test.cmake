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
    # Try to find Google Test
    find_package(GTest QUIET)

    if(NOT GTest_FOUND)
      # Fall back to FetchContent if absent.
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
  cmake_parse_arguments(PARSE_ARGV 0 _t
    "${_ct_options}"
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

  # Apply the TIMEOUT (from TIMEOUT/SIZE) and LABELS attributes to every discovered test.
  # gtest_discover_tests discovers tests at BUILD time, so the individual CTest tests do not
  # exist at configure time and cannot be given properties directly here. Its own PROPERTIES
  # option is unusable for LABELS: it forwards each token verbatim to set_tests_properties, so
  # a multi-valued LABELS list ('unit;fast') loses every label but the first, and the ';' in
  # the value is mangled into a broken command line on the Visual Studio generator. Instead,
  # use the documented escape hatch -- a CTest include file that sets the properties over the
  # captured ${_t_TARGET}_TESTS list. CTest includes it after gtest's own discovery output
  # (this append follows gtest_discover_tests' own TEST_INCLUDE_FILES append), by which point
  # that variable holds the discovered test names, and the LABELS value is a plain quoted
  # string in a script file (no command-line escaping to mangle it).
  set(_prop_pairs "")
  if(NOT "${_effective_timeout}" STREQUAL "")
    string(APPEND _prop_pairs " TIMEOUT ${_effective_timeout}")
  endif()
  if(_t_LABELS)
    string(APPEND _prop_pairs " LABELS \"${_t_LABELS}\"")
  endif()
  if(NOT "${_prop_pairs}" STREQUAL "")
    set(_prop_include "${CMAKE_CURRENT_BINARY_DIR}/${_t_TARGET}_cpp_test_props.cmake")
    file(WRITE "${_prop_include}"
      "# Generated by cpp_test() (issue #27): apply SIZE/TIMEOUT/LABELS to the discovered tests.\n"
      "if(${_t_TARGET}_TESTS)\n"
      "  set_tests_properties(\${${_t_TARGET}_TESTS} PROPERTIES${_prop_pairs})\n"
      "endif()\n")
    set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES "${_prop_include}")
  endif()
endfunction()
