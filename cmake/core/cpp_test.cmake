# cpp_test.cmake
# Wrapper for creating C++ test targets with Google Test integration

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Check if Google Test is available
if(NOT TARGET GTest::gtest AND NOT TARGET gtest)
  # Try to find Google Test
  find_package(GTest QUIET)

  if(NOT GTest_FOUND)
    # Fall back to FetchContent if available
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

# Enable testing if not already enabled
if(NOT CMAKE_TESTING_ENABLED)
  enable_testing()
endif()

# Include GoogleTest module for test discovery
include(GoogleTest)

# Define a C++ test target
function(cpp_test)
  # Parse arguments to extract TARGET name
  set(options)
  set(one_value_args TARGET FOLDER)
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

  # Discover tests if target was created
  if(_test_args_TARGET AND TARGET ${_test_args_TARGET})
    gtest_discover_tests(${_test_args_TARGET})
  endif()
endfunction()
