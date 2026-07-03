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

  # Parse arguments to extract TARGET name
  set(options)
  set(one_value_args TARGET FOLDER WORKING_DIRECTORY)
  set(multi_value_args)
  cmake_parse_arguments(
    PARSE_ARGV 0
    _test_args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Create executable using cpp_target
  cpp_target(
    TYPE EXECUTABLE
    ${ARGN}  # Forward all arguments to cpp_target
  )

  # If no FOLDER was specified, default to Tests
  if(NOT _test_args_FOLDER AND _test_args_TARGET)
    set_target_properties(${_test_args_TARGET} PROPERTIES FOLDER "Tests")
  endif()

  if(_test_args_TARGET AND TARGET ${_test_args_TARGET})
    # Link GTest main entry point — every test needs this.
    target_link_libraries(${_test_args_TARGET} PRIVATE GTest::gtest_main)

    # Discover tests with optional working directory
    if(_test_args_WORKING_DIRECTORY)
      gtest_discover_tests(${_test_args_TARGET}
        WORKING_DIRECTORY "${_test_args_WORKING_DIRECTORY}")
    else()
      gtest_discover_tests(${_test_args_TARGET})
    endif()
  endif()
endfunction()
