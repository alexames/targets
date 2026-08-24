# find_targets(): add_subdirectory() every directory in a tree that declares targets.

include_guard(GLOBAL)

# add_subdirectory() each directory under DIRECTORY that contains a file named NAME.
#
#   DIRECTORY  the tree to search (default: the calling CMakeLists directory)
#   NAME       the file that marks a directory as one to add (default: CMakeLists.txt)
#
# The search is a recursive glob run at configure time, so a directory added afterward is not
# picked up until the next configure. Only directories strictly below DIRECTORY are matched --
# the glob requires an intervening path component -- so calling this from a CMakeLists does
# not re-add its own directory. Each match is added unconditionally, in whatever order the
# glob returns, so a tree whose targets reference each other wants import_dependencies()
# instead.
function(find_targets)
  set(options)
  set(one_value_args
    DIRECTORY
    NAME
  )
  set(multi_value_args)

  cmake_parse_arguments(
    PARSE_ARGV 0
    ARGS
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  if(NOT ARGS_DIRECTORY)
    set(ARGS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")
  endif()

  if(NOT ARGS_NAME)
    set(ARGS_NAME "CMakeLists.txt")
  endif()

  file(GLOB_RECURSE files LIST_DIRECTORIES false "${ARGS_DIRECTORY}/**/${ARGS_NAME}")

  foreach(file ${files})
    get_filename_component(dir "${file}" DIRECTORY)
    message(STATUS "Targets: find_targets: Adding subdirectory ${dir}")
    add_subdirectory("${dir}")
  endforeach()
endfunction()
