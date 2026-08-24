# The scope that includes Targets first, so that cpp_target.cmake's include_guard(GLOBAL) has
# already fired by the time the sibling beside this one includes Targets. Its library has a
# translation unit of its own and so never needs the placeholder.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../../cmake")
include(Targets)

cpp_library(
  TARGET FirstLib
  SOURCES first.cpp
)
