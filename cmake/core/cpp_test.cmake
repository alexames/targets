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
      # Fall back to FetchContent if absent
      include(FetchContent)
      FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.2
        FIND_PACKAGE_ARGS NAMES GTest
      )

      # For Windows: Prevent overriding the parent project's compiler/linker settings
      set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

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

# Enable testing if not already enabled
if(NOT CMAKE_TESTING_ENABLED)
  enable_testing()
endif()

# Define a C++ test target
function(cpp_test)
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
