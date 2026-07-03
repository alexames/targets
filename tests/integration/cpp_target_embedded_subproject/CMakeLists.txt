# Configure-mode regression test for issue #8: namespace aliases, IDE folders, and
# auto-import must key off the *enclosing* project (PROJECT_NAME), not the top-level
# project (CMAKE_PROJECT_NAME). Otherwise a Targets library that works standalone changes
# its aliases/folders the moment it is embedded via add_subdirectory/FetchContent.
#
# This is the OUTER project. It includes Targets and then embeds an inner project that
# defines its own project() and calls a Targets rule. The inner subproject asserts that
# the alias and FOLDER it produces are derived from the inner project name ("Inner"), not
# this outer top-level name ("Outer"). A FATAL_ERROR in any assertion fails the CTest.

cmake_minimum_required(VERSION 3.20)
project(Outer LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

add_subdirectory(inner)

message(STATUS "cpp_target embedded-subproject test passed (issue #8)")
