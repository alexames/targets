# Resolve a namespaced dependency label to the subdirectory that declares it, and
# add_subdirectory() that directory on demand, with circular-import detection.

include_guard(GLOBAL)

define_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK
  BRIEF_DOCS "Stack of currently importing subdirectories for circular dependency detection"
  FULL_DOCS "Maintains a stack of subdirectories currently being imported to detect circular dependencies"
)
set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK "")

define_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST
  BRIEF_DOCS "List of all imported subdirectories"
  FULL_DOCS "Maintains a list of all subdirectories that have been imported to avoid duplicate imports"
)
set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST "")

# Report in out_var the root that maps a namespaced label to a subdirectory: the source tree
# for _targets_source_root, the matching binary tree for _targets_binary_root.
#
# Both are recomputed on every call rather than cached, so each project in a multi-project
# tree resolves its imports against its OWN Source directory -- a value frozen at
# module-include time would be the first project's, and a Targets project embedded via
# add_subdirectory/FetchContent would then look for its subdirectories in the wrong tree.
# An explicit TARGETS_SOURCE_DIR / TARGETS_BINARY_DIR set by the consumer still wins;
# otherwise each derives from the *enclosing* project.
function(_targets_source_root out_var)
  if(TARGETS_SOURCE_DIR)
    set(${out_var} "${TARGETS_SOURCE_DIR}" PARENT_SCOPE)
  else()
    set(${out_var} "${PROJECT_SOURCE_DIR}/Source" PARENT_SCOPE)
  endif()
endfunction()

function(_targets_binary_root out_var)
  if(TARGETS_BINARY_DIR)
    set(${out_var} "${TARGETS_BINARY_DIR}" PARENT_SCOPE)
  else()
    set(${out_var} "${PROJECT_BINARY_DIR}/Source" PARENT_SCOPE)
  endif()
endfunction()

# add_subdirectory() the source root's SUBDIRECTORY, once per configure. TARGET names the
# target whose dependency triggered the import, for diagnostics.
#
# A directory already on the import stack means a cycle, and is a FATAL_ERROR that prints the
# chain. A directory that is merely already imported is skipped. A self-reference -- the
# subdirectory currently on top of the stack, which is how two targets in one CMakeLists reach
# each other -- is neither.
#
# FATAL_ERROR when the resolved directory does not exist; a directory with no CMakeLists.txt
# is a WARNING and imports nothing.
function(_targets_import_subdirectory_real target subdirectory)
  get_property(imported_stack GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK)

  list(LENGTH imported_stack imported_stack_length)
  set(top "")
  if(imported_stack_length)
    list(GET imported_stack -1 top)
  endif()

  if("${subdirectory}" STREQUAL "${top}")
    # A target naming a sibling declared in the same CMakeLists is not a cycle.
  else()
    list(FIND imported_stack "${subdirectory}" index)
    if(NOT index EQUAL -1)
      message(STATUS "========================================")
      message(STATUS "Circular dependency detected!")
      message(STATUS "========================================")
      message(STATUS "Import chain:")
      set(prefix "   ")
      foreach(directory ${imported_stack})
        if("${directory}" STREQUAL "${subdirectory}")
          set(prefix " .->")
        endif()
        message(STATUS " ${prefix} ${directory}/CMakeLists.txt")
        if("${directory}" STREQUAL "${subdirectory}")
          set(prefix " |  ")
        endif()
      endforeach()
      message(STATUS " '-> ${subdirectory}/CMakeLists.txt")
      message(STATUS "========================================")
      message(FATAL_ERROR "Targets: Circular dependency detected while importing ${subdirectory} for target ${target}")
      return()
    endif()

    list(APPEND imported_stack "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK ${imported_stack})
  endif()

  get_property(imported_list GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST)
  list(FIND imported_list "${subdirectory}" index)

  if(index EQUAL -1)
    list(APPEND imported_list "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST "${imported_list}")

    _targets_source_root(source_root)
    _targets_binary_root(binary_root)
    set(source_dir "${source_root}/${subdirectory}")
    set(binary_dir "${binary_root}/${subdirectory}")

    if(NOT EXISTS "${source_dir}")
      message(FATAL_ERROR "Targets: import_subdirectory: Target ${target}: Directory does not exist: ${source_dir}")
      return()
    endif()

    if(NOT EXISTS "${source_dir}/CMakeLists.txt")
      message(WARNING "Targets: import_subdirectory: Target ${target}: No CMakeLists.txt in ${source_dir}")
      return()
    endif()

    add_subdirectory("${source_dir}" "${binary_dir}")
  endif()

  if(NOT "${subdirectory}" STREQUAL "${top}")
    list(REMOVE_ITEM imported_stack "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK ${imported_stack})
  endif()
endfunction()

# Import one subdirectory of the enclosing project's source root, given relative to it.
#
# Imports at most once per configure however many times it is called, and is a FATAL_ERROR on
# a directory that does not exist or that a cycle leads back to.
function(import_subdirectory subdirectory)
  _targets_import_subdirectory_real("<root>" "${subdirectory}")
endfunction()

# Import the subdirectories that declare TARGET's namespaced dependencies, so a target can be
# named before the CMakeLists that creates it has been processed. DEPENDENCIES is one
# semicolon-separated list of labels, quoted at the call site.
#
# A label already resolving to a target is left alone. Otherwise its leading namespace must be
# the *enclosing* project (PROJECT_NAME) rather than the top-level one (CMAKE_PROJECT_NAME),
# which is what lets an embedded subproject's own labels ("SubProj::Core::Lib") match; the
# remaining namespace components are the path under the source root. A label rooted at
# anything else is left for CMake to resolve, since it names a target this project does not
# own.
#
# FATAL_ERROR when a matching label's subdirectory is imported and the target still does not
# exist.
function(import_dependencies target dependencies)
  foreach(dependency ${dependencies})
    if(NOT TARGET ${dependency})
      # "MyProject::Core::Math" -> ["MyProject", "Core", "Math"], of which the middle
      # components are the path and the last is the target name.
      string(REPLACE "::" ";" namespace_list "${dependency}")

      list(GET namespace_list 0 root)

      if(root STREQUAL "${PROJECT_NAME}")
        list(POP_FRONT namespace_list)
        list(POP_BACK namespace_list)

        string(REPLACE ";" "/" relative_dir "${namespace_list}")

        _targets_import_subdirectory_real("${target}" "${relative_dir}")

        if(NOT TARGET ${dependency})
          message(FATAL_ERROR "Targets: import_dependencies: Target ${target}: Failed to import ${dependency} from ${relative_dir}")
        endif()
      endif()
    endif()
  endforeach()
endfunction()

# Import every subdirectory of DIR that holds a CMakeLists.txt, recursively. DIR is absolute;
# each directory found is imported relative to the enclosing project's source root, so DIR
# must lie under it.
#
# The build directory is skipped. Directories are visited in glob order, so a project whose
# targets depend on each other relies on import_dependencies() rather than on this ordering.
function(import_all dir)
  file(GLOB children RELATIVE "${dir}" "${dir}/*")

  foreach(child IN LISTS children)
    set(child_path "${dir}/${child}")

    if(IS_DIRECTORY "${child_path}")
      if(NOT "${child_path}" STREQUAL "${CMAKE_BINARY_DIR}")
        if(EXISTS "${child_path}/CMakeLists.txt")
          _targets_source_root(source_root)
          file(RELATIVE_PATH relative_child_path "${source_root}" "${child_path}")
          import_subdirectory("${relative_child_path}")
        endif()

        import_all("${child_path}")
      endif()
    endif()
  endforeach()
endfunction()
