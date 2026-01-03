# cpp_library.cmake
# Wrapper for creating C++ library targets

include_guard(GLOBAL)

get_filename_component(_TARGETS_CORE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_TARGETS_CORE_DIR}/cpp_target.cmake")

# Define a C++ library target
function(cpp_library)
  cpp_target(
    TYPE LIBRARY
    ${ARGN}  # Forward all arguments to cpp_target
  )
endfunction()
