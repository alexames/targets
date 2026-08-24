# A sibling scope that includes Targets for itself. It inherits nothing from "first", so the
# placeholder must resolve without help from anything that scope's include left behind.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../../cmake")
include(Targets)

cpp_library(
  TARGET SecondHeaderOnlyLib
  HEADERS second.h
)

get_target_property(_sources SecondHeaderOnlyLib SOURCES)
if(NOT _sources MATCHES "dummy\\.cpp")
  message(FATAL_ERROR
    "header-only library in a sibling scope must carry the dummy.cpp placeholder TU, got: "
    "'${_sources}'")
endif()

message(STATUS "cpp_target placeholder resolves from a sibling directory scope")
