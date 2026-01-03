# cpp_binary.cmake
# Wrapper for creating C++ executable targets

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Define a C++ executable target
function(cpp_binary)
  cpp_target(
    TYPE EXECUTABLE
    ${ARGN}  # Forward all arguments to cpp_target
  )
endfunction()
