# import_dependencies.cmake
# Smart dependency importing with automatic subdirectory discovery and circular dependency detection

include_guard(GLOBAL)

# Global properties for tracking imported directories
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

# Configuration variables
if(NOT TARGETS_SOURCE_DIR)
  set(TARGETS_SOURCE_DIR "${PROJECT_SOURCE_DIR}/Source" CACHE PATH "Root directory for source files")
endif()

if(NOT TARGETS_BINARY_DIR)
  set(TARGETS_BINARY_DIR "${PROJECT_BINARY_DIR}/Source" CACHE PATH "Root directory for build files")
endif()

# Internal implementation with circular dependency detection
function(_targets_import_subdirectory_real target subdirectory)
  # Get stack of visited directories
  get_property(imported_stack GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK)

  # Get last item (top of stack)
  list(LENGTH imported_stack imported_stack_length)
  set(top "")
  if(imported_stack_length)
    list(GET imported_stack -1 top)
  endif()

  # Check for circular dependencies
  # Allow same-file references (targets in same CMakeLists.txt)
  if("${subdirectory}" STREQUAL "${top}")
    # Skip check - same file reference is allowed
  else()
    # Check if the requested subdirectory is already in the import stack
    list(FIND imported_stack "${subdirectory}" index)
    if(NOT index EQUAL -1)
      # Circular dependency detected! Print error and halt
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

    # Not circular - add to stack
    list(APPEND imported_stack "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK ${imported_stack})
  endif()

  # Check if already imported
  get_property(imported_list GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST)
  list(FIND imported_list "${subdirectory}" index)

  if(index EQUAL -1)
    # Not yet imported - add to list
    list(APPEND imported_list "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_LIST "${imported_list}")

    # Construct full path
    set(source_dir "${TARGETS_SOURCE_DIR}/${subdirectory}")
    set(binary_dir "${TARGETS_BINARY_DIR}/${subdirectory}")

    # Validate directory exists
    if(NOT EXISTS "${source_dir}")
      message(FATAL_ERROR "Targets: import_subdirectory: Target ${target}: Directory does not exist: ${source_dir}")
      return()
    endif()

    # Validate CMakeLists.txt exists
    if(NOT EXISTS "${source_dir}/CMakeLists.txt")
      message(WARNING "Targets: import_subdirectory: Target ${target}: No CMakeLists.txt in ${source_dir}")
      return()
    endif()

    # Import the subdirectory
    add_subdirectory("${source_dir}" "${binary_dir}")
  endif()

  # Pop from stack (unless it's a same-file reference)
  if(NOT "${subdirectory}" STREQUAL "${top}")
    list(REMOVE_ITEM imported_stack "${subdirectory}")
    set_property(GLOBAL PROPERTY TARGETS_IMPORTED_SUBDIRECTORY_STACK ${imported_stack})
  endif()
endfunction()

# Public API: Import a single subdirectory
function(import_subdirectory subdirectory)
  _targets_import_subdirectory_real("<root>" "${subdirectory}")
endfunction()

# Public API: Automatically import dependencies based on namespace
function(import_dependencies target dependencies)
  foreach(dependency ${dependencies})
    # Only process if not already a target
    if(NOT TARGET ${dependency})
      # Parse namespace (e.g., "MyProject::Core::Math" -> ["MyProject", "Core", "Math"])
      string(REPLACE "::" ";" namespace_list "${dependency}")

      # Get root namespace
      list(GET namespace_list 0 root)

      # Only auto-import if it matches the current project
      if(root STREQUAL "${CMAKE_PROJECT_NAME}")
        # Remove project name from front
        list(POP_FRONT namespace_list)

        # Remove target name from end
        list(POP_BACK namespace_list)

        # Convert remaining namespace to directory path
        string(REPLACE ";" "/" relative_dir "${namespace_list}")

        # Import the subdirectory
        _targets_import_subdirectory_real("${target}" "${relative_dir}")

        # Verify the target now exists
        if(NOT TARGET ${dependency})
          message(FATAL_ERROR "Targets: import_dependencies: Target ${target}: Failed to import ${dependency} from ${relative_dir}")
        endif()
      endif()
    endif()
  endforeach()
endfunction()

# Public API: Recursively import all CMakeLists.txt files in a directory tree
function(import_all dir)
  # Get all children in directory
  file(GLOB children RELATIVE "${dir}" "${dir}/*")

  foreach(child IN LISTS children)
    set(child_path "${dir}/${child}")

    # Process if it's a directory (and not the build directory)
    if(IS_DIRECTORY "${child_path}")
      if(NOT "${child_path}" STREQUAL "${CMAKE_BINARY_DIR}")
        # If it has a CMakeLists.txt, import it
        if(EXISTS "${child_path}/CMakeLists.txt")
          file(RELATIVE_PATH relative_child_path "${TARGETS_SOURCE_DIR}" "${child_path}")
          import_subdirectory("${relative_child_path}")
        endif()

        # Recurse into subdirectories
        import_all("${child_path}")
      endif()
    endif()
  endforeach()
endfunction()
