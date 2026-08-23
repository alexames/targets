# Driver for the build-mode half of the codegen target defaults tests: configures and builds
# the effective_standard fixture, which only compiles if a header-only cpp_library dependency
# raised an embed_binary target to C++20 or later.
#
# Configure and build are one CTest entry rather than two, so a fixture that fails to
# configure reports one failure naming this subject instead of a second, derived one.
#
# Run with `cmake -P`. Every argument is required:
#   FIXTURE_DIR      The project to configure and build.
#   WORK_DIR         Build tree; erased and rebuilt on every run.
#   TEST_GENERATOR   Generator for the inner build. The outer generator is reused, so the
#                    build tool is known to be installed.
#   TEST_CONFIG      Configuration to build, passed to --config. May be empty: CTest expands
#                    the $<CONFIG> the harness passes to nothing when ctest was given no -C,
#                    and `--config ""` is not the same request as omitting it.

cmake_minimum_required(VERSION 3.20)

foreach(argument FIXTURE_DIR WORK_DIR TEST_GENERATOR TEST_CONFIG)
  if(NOT DEFINED ${argument})
    message(FATAL_ERROR "effective_standard: -D${argument} is required")
  endif()
endforeach()

# A stale build tree would let a previously compiled probe stand in for one this run never
# compiled.
file(REMOVE_RECURSE "${WORK_DIR}")

execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -G "${TEST_GENERATOR}"
    -S "${FIXTURE_DIR}"
    -B "${WORK_DIR}"
  RESULT_VARIABLE configure_result)
if(NOT configure_result EQUAL 0)
  message(FATAL_ERROR "effective_standard: configuring the fixture failed (${configure_result})")
endif()

set(build_command "${CMAKE_COMMAND}" --build "${WORK_DIR}")
if(NOT TEST_CONFIG STREQUAL "")
  list(APPEND build_command --config "${TEST_CONFIG}")
endif()
execute_process(COMMAND ${build_command} RESULT_VARIABLE build_result)
if(NOT build_result EQUAL 0)
  message(FATAL_ERROR
    "effective_standard: building the fixture failed (${build_result}). A failed static "
    "assertion here means the header-only dependency did not raise the embed_binary target "
    "to C++20 or later.")
endif()

message(STATUS "EFFECTIVE_STANDARD_OK: the dependency raised the target into scanning range")
