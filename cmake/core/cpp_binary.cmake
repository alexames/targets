# cpp_binary(): the executable spelling of cpp_target().

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Define a C++ executable target, with a namespace alias derived from its directory and --
# on Windows, with CMake 3.21 or newer -- the runtime DLLs of its shared dependencies staged
# beside it. Takes cpp_target()'s whole
# argument surface apart from TYPE, under the grammar a leaf target uses -- PRIVATE is implied
# on every visibility-taking list and PUBLIC is rejected. docs/API.md is the reference;
# cpp_target() carries the contract and the failure conditions.
function(cpp_binary)
  cpp_target(
    TYPE EXECUTABLE
    ${ARGN}
  )
endfunction()
