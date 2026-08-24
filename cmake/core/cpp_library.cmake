# cpp_library(): the library spelling of cpp_target().

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Define a C++ library target: STATIC unless SHARED is given, with a namespace alias derived
# from its directory. Takes cpp_target()'s whole argument surface apart from TYPE, under the
# grammar a library uses -- every visibility-taking list requires PUBLIC or PRIVATE on each
# entry. docs/API.md is the reference; cpp_target() above carries the contract and the
# failure conditions.
function(cpp_library)
  cpp_target(
    TYPE LIBRARY
    ${ARGN}
  )
endfunction()
