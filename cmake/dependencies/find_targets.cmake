# find_targets.cmake
# Utility to recursively find and add all CMakeLists.txt files in a directory

include_guard(GLOBAL)

# Find and add all CMakeLists.txt files in a directory tree
function(find_targets)
  # Parse function arguments
  set(options)
  set(one_value_args
    DIRECTORY   # Directory to search (default: CMAKE_CURRENT_LIST_DIR)
    NAME        # Filename to search for (default: CMakeLists.txt)
  )
  set(multi_value_args)

  cmake_parse_arguments(
    PARSE_ARGV 0
    ARGS
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Set defaults
  if(NOT ARGS_DIRECTORY)
    set(ARGS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(NOT ARGS_NAME)
    set(ARGS_NAME "CMakeLists.txt")
  endif()

  # Find all matching files recursively
  file(GLOB_RECURSE files LIST_DIRECTORIES false "${ARGS_DIRECTORY}/**/${ARGS_NAME}")

  # Add each directory containing a matching file
  foreach(file ${files})
    get_filename_component(dir "${file}" DIRECTORY)
    message(STATUS "Targets: find_targets: Adding subdirectory ${dir}")
    add_subdirectory("${dir}")
  endforeach()
endfunction()
