# cpp_target.cmake
# Core target abstraction for Targets library
# Provides unified interface for creating C++ libraries and executables

include_guard(GLOBAL)

# Enable folder organization in IDEs
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Whether cpp_target injects MSVC edit-and-continue debug info (/ZI) into Debug builds.
# /ZI is a developer convenience that only applies to x86/x64 and must never reach
# Release, where it de-optimizes the build (see issue #5). It is gated to Debug via a
# generator expression and skipped entirely on ARM/ARM64. Set this to OFF to suppress
# /ZI in every configuration.
option(TARGETS_MSVC_EDIT_AND_CONTINUE
  "Inject MSVC /ZI (edit-and-continue debug info) into Debug builds on x86/x64" ON)

# Include dependency management
get_filename_component(_TARGETS_MODULE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_MODULE_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")
include("${_TARGETS_MODULE_DIR}/platform_parser.cmake")

# Reject arguments that cmake_parse_arguments could not assign to a known keyword.
#
# RULE names the calling rule for diagnostics. UNPARSED is the rule's
# <prefix>_UNPARSED_ARGUMENTS, MISSING is its <prefix>_KEYWORDS_MISSING_VALUES, and
# ARGN carries the rule's full set of valid keywords (printed as a hint). Values are
# passed positionally rather than under keywords so a stray token cannot collide with
# this helper's own argument names. An unrecognized argument is a hard error: it is
# almost always a misspelled keyword or a value that lost its keyword, either of which
# silently changes the target if left unchecked (see issue #4). A keyword given no
# values is only a warning.
function(_targets_check_args RULE UNPARSED MISSING)
  if(NOT "${UNPARSED}" STREQUAL "")
    string(REPLACE ";" ", " _unparsed "${UNPARSED}")
    set(_hint "")
    if(NOT "${ARGN}" STREQUAL "")
      string(REPLACE ";" ", " _valid_keywords "${ARGN}")
      set(_hint " Valid keywords are: ${_valid_keywords}.")
    endif()
    message(FATAL_ERROR
      "${RULE}: unrecognized argument(s): ${_unparsed}. This is usually a "
      "misspelled keyword or a value missing its PUBLIC/PRIVATE keyword.${_hint}")
  endif()
  if(NOT "${MISSING}" STREQUAL "")
    string(REPLACE ";" ", " _missing "${MISSING}")
    message(WARNING "${RULE}: keyword(s) given with no values: ${_missing}.")
  endif()
endfunction()

# Split a visibility-taking argument's values into PUBLIC_<VAR_NAME> and
# PRIVATE_<VAR_NAME> (set in the caller's scope). RULE names the calling rule for
# diagnostics. Every value must appear under a PUBLIC or PRIVATE keyword: entries
# placed before the first access keyword would otherwise be dropped silently, so
# they are rejected with a hard error (see issue #4).
function(_targets_parse_access_specifier RULE VAR_NAME)
  set(options)
  set(one_value_args)
  set(multi_value_args PUBLIC PRIVATE)
  cmake_parse_arguments(
    PARSE_ARGV 2
    ACCESS_SPECIFIER
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")
  if(NOT "${ACCESS_SPECIFIER_UNPARSED_ARGUMENTS}" STREQUAL "")
    message(FATAL_ERROR
      "${RULE}: ${VAR_NAME} values must be grouped under PUBLIC or PRIVATE. These "
      "entries precede the first access keyword and would be dropped: "
      "${ACCESS_SPECIFIER_UNPARSED_ARGUMENTS}.")
  endif()
  set(PUBLIC_${VAR_NAME} ${ACCESS_SPECIFIER_PUBLIC} PARENT_SCOPE)
  set(PRIVATE_${VAR_NAME} ${ACCESS_SPECIFIER_PRIVATE} PARENT_SCOPE)
endfunction()

# Partition absolute file paths into those located under ROOT and those outside it.
# source_group(TREE ROOT FILES ...) is a hard configure error for any file that is not
# under ROOT: this happens for generated files in an out-of-source build tree, or for
# "../shared" sources (see issue #6). Callers keep such files out of the TREE grouping
# and place them in a flat group instead. The two lists are returned in the caller's
# UNDER_VAR and OUTSIDE_VAR; the file paths to classify are passed as trailing arguments.
function(_targets_partition_files_by_root ROOT UNDER_VAR OUTSIDE_VAR)
  get_filename_component(root_abs "${ROOT}" ABSOLUTE)
  set(under "")
  set(outside "")
  foreach(file IN LISTS ARGN)
    get_filename_component(file_abs "${file}" ABSOLUTE)
    file(RELATIVE_PATH rel "${root_abs}" "${file_abs}")
    # A file on a different drive keeps its absolute path; one above ROOT starts with
    # "..". Either way it is not under ROOT and must skip source_group(TREE ...).
    if(IS_ABSOLUTE "${rel}" OR rel STREQUAL ".." OR rel MATCHES "^\\.\\./")
      list(APPEND outside "${file}")
    else()
      list(APPEND under "${file}")
    endif()
  endforeach()
  set(${UNDER_VAR} "${under}" PARENT_SCOPE)
  set(${OUTSIDE_VAR} "${outside}" PARENT_SCOPE)
endfunction()

# Main cpp_target function
function(cpp_target)
  # Parse function arguments
  set(options
    STATIC
    SHARED
    UNITY_BUILD)
  set(one_value_args
    TYPE                      # LIBRARY or EXECUTABLE (required)
    TARGET                    # Target name (required)
    FOLDER                    # IDE folder path
    SOURCE_DIR                # Source directory (default: CMAKE_CURRENT_LIST_DIR)
    HEADER_DIR                # Header directory (default: CMAKE_CURRENT_LIST_DIR/Include)
    WORKING_DIRECTORY         # Debugger working directory (executables only)
    COMMAND_ARGUMENTS         # Debugger command arguments (executables only)
    CXX_STANDARD              # C++ standard (default: 23)
    VERSION                   # Semantic version (e.g., "1.2.3")
    SOVERSION                 # ABI version
    UNITY_BUILD_BATCH_SIZE    # Files per unity chunk (default: 16)
    NAMESPACE_ROOT            # Root for namespace generation (default: PROJECT_SOURCE_DIR/Source)
  )
  set(multi_value_args
    SOURCES                   # Source files
    HEADERS                   # Header files
    INCLUDES                  # Include directories (with PUBLIC/PRIVATE)
    DEFINITIONS               # Compiler definitions (with PUBLIC/PRIVATE)
    DEPENDENCIES              # Link libraries (with PUBLIC/PRIVATE)
    PROPERTIES                # Additional CMake properties
    PRECOMPILE_HEADERS        # Headers to precompile
  )
  cmake_parse_arguments(
    PARSE_ARGV 0
    args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Reject typo'd or misplaced arguments instead of silently ignoring them.
  _targets_check_args("cpp_target"
    "${args_UNPARSED_ARGUMENTS}"
    "${args_KEYWORDS_MISSING_VALUES}"
    ${options} ${one_value_args} ${multi_value_args})

  # Validate required arguments
  if(NOT args_TYPE)
    message(FATAL_ERROR "cpp_target: TYPE argument is required (LIBRARY or EXECUTABLE)")
  endif()
  if(NOT args_TARGET)
    message(FATAL_ERROR "cpp_target: TARGET argument is required")
  endif()

  # Set defaults
  if(NOT args_SOURCE_DIR)
    set(args_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}")
  endif()
  if(NOT IS_ABSOLUTE "${args_SOURCE_DIR}")
    set(args_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/${args_SOURCE_DIR}")
  endif()

  if(NOT args_HEADER_DIR)
    set(args_HEADER_DIR "${CMAKE_CURRENT_LIST_DIR}/Include")
  endif()
  if(NOT IS_ABSOLUTE "${args_HEADER_DIR}")
    set(args_HEADER_DIR "${CMAKE_CURRENT_LIST_DIR}/${args_HEADER_DIR}")
  endif()

  if(NOT args_CXX_STANDARD)
    set(args_CXX_STANDARD 23)
  endif()

  if(NOT args_NAMESPACE_ROOT)
    set(args_NAMESPACE_ROOT "${PROJECT_SOURCE_DIR}/Source")
  endif()

  # Filter platform-conditional entries out of list arguments.
  _targets_parse_platforms(args_SOURCES ${args_SOURCES})
  _targets_parse_platforms(args_HEADERS ${args_HEADERS})

  # Gather source files
  unset(sources)
  foreach(source ${args_SOURCES})
    if(IS_ABSOLUTE "${source}")
      list(APPEND sources "${source}")
    else()
      list(APPEND sources "${args_SOURCE_DIR}/${source}")
    endif()
  endforeach()

  # Create source groups for IDE organization. source_group(TREE ...) hard-errors on any
  # file outside the tree root, so out-of-root sources (generated files in an out-of-source
  # build tree, or ../shared sources) are collected into a flat "Generated Files" group
  # instead of aborting configuration (see issue #6).
  if(sources)
    _targets_partition_files_by_root(
      "${args_SOURCE_DIR}" in_tree_sources out_of_tree_sources ${sources})
    if(in_tree_sources)
      source_group(TREE "${args_SOURCE_DIR}" PREFIX "Source Files" FILES ${in_tree_sources})
    endif()
    if(out_of_tree_sources)
      source_group("Generated Files" FILES ${out_of_tree_sources})
    endif()
  else()
    # If no sources provided, add a dummy file (for header-only or generated targets)
    set(dummy_file "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/dummy.cpp")
    if(EXISTS "${dummy_file}")
      list(APPEND sources "${dummy_file}")
      source_group("CMake Rules" FILES "${dummy_file}")
    endif()
  endif()

  # Gather header files
  unset(headers)
  foreach(header ${args_HEADERS})
    if(IS_ABSOLUTE "${header}")
      list(APPEND headers "${header}")
    else()
      list(APPEND headers "${args_HEADER_DIR}/${header}")
    endif()
  endforeach()

  # Create header source groups. Out-of-root headers get the same flat "Generated Files"
  # grouping as sources so a generated header never aborts configuration (see issue #6).
  if(headers)
    _targets_partition_files_by_root(
      "${args_HEADER_DIR}" in_tree_headers out_of_tree_headers ${headers})
    if(in_tree_headers)
      source_group(TREE "${args_HEADER_DIR}" PREFIX "Header Files" FILES ${in_tree_headers})
    endif()
    if(out_of_tree_headers)
      source_group("Generated Files" FILES ${out_of_tree_headers})
    endif()
  endif()

  # Create the target
  if(args_TYPE STREQUAL "LIBRARY")
    if(args_SHARED)
      set(library_type SHARED)
    else()
      set(library_type STATIC)
    endif()

    # Handle header-only libraries
    if(NOT sources AND headers)
      add_library(${args_TARGET} INTERFACE)
      set(_is_interface_library TRUE)
    else()
      add_library(${args_TARGET} ${library_type} ${sources} ${headers})
      set(_is_interface_library FALSE)
    endif()
  elseif(args_TYPE STREQUAL "EXECUTABLE")
    if(args_STATIC OR args_SHARED)
      message(FATAL_ERROR "cpp_target: Executables cannot be marked STATIC or SHARED")
    endif()
    add_executable(${args_TARGET} ${sources} ${headers})
    set(_is_interface_library FALSE)
  else()
    message(FATAL_ERROR "cpp_target: Invalid TYPE '${args_TYPE}'. Must be LIBRARY or EXECUTABLE")
  endif()

  # Create namespace alias
  if(EXISTS "${args_NAMESPACE_ROOT}")
    file(RELATIVE_PATH relative_path_from_root "${args_NAMESPACE_ROOT}" "${CMAKE_CURRENT_LIST_DIR}")
  else()
    set(relative_path_from_root "")
  endif()

  set(default_folder "${CMAKE_PROJECT_NAME}")
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set(default_folder "${default_folder}/${relative_path_from_root}")
  endif()

  string(REPLACE "/" "::" namespace "${default_folder}")
  set(alias "${namespace}::${args_TARGET}")

  if(args_TYPE STREQUAL "EXECUTABLE")
    add_executable(${alias} ALIAS ${args_TARGET})
  else()
    add_library(${alias} ALIAS ${args_TARGET})
  endif()

  # Configure interface libraries differently
  if(_is_interface_library)
    # Interface libraries use INTERFACE keyword for everything
    _targets_parse_access_specifier("cpp_target" INCLUDES ${args_INCLUDES})
    _targets_parse_platforms(PUBLIC_INCLUDES ${PUBLIC_INCLUDES})
    target_include_directories(${args_TARGET} INTERFACE
      ${PUBLIC_INCLUDES}
      "$<BUILD_INTERFACE:${args_HEADER_DIR}>"
    )

    _targets_parse_access_specifier("cpp_target" DEFINITIONS ${args_DEFINITIONS})
    _targets_parse_platforms(PUBLIC_DEFINITIONS ${PUBLIC_DEFINITIONS})
    target_compile_definitions(${args_TARGET} INTERFACE ${PUBLIC_DEFINITIONS})

    _targets_parse_access_specifier("cpp_target" DEPENDENCIES ${args_DEPENDENCIES})
    _targets_parse_platforms(PUBLIC_DEPENDENCIES ${PUBLIC_DEPENDENCIES})
    import_dependencies(${args_TARGET} "${PUBLIC_DEPENDENCIES}")
    target_link_libraries(${args_TARGET} INTERFACE ${PUBLIC_DEPENDENCIES})

    target_compile_features(${args_TARGET} INTERFACE cxx_std_${args_CXX_STANDARD})
  else()
    # Regular libraries and executables

    # Add include directories
    _targets_parse_access_specifier("cpp_target" INCLUDES ${args_INCLUDES})
    _targets_parse_platforms(PUBLIC_INCLUDES ${PUBLIC_INCLUDES})
    _targets_parse_platforms(PRIVATE_INCLUDES ${PRIVATE_INCLUDES})
    target_include_directories(
      ${args_TARGET}
      PUBLIC
        ${PUBLIC_INCLUDES}
        "$<BUILD_INTERFACE:${args_HEADER_DIR}>"
      PRIVATE
        ${PRIVATE_INCLUDES}
        "${args_SOURCE_DIR}"
    )

    # Set C++ standard
    set_target_properties(
      ${args_TARGET}
      PROPERTIES
        CXX_STANDARD ${args_CXX_STANDARD}
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )

    # Add compiler definitions
    _targets_parse_access_specifier("cpp_target" DEFINITIONS ${args_DEFINITIONS})
    _targets_parse_platforms(PUBLIC_DEFINITIONS ${PUBLIC_DEFINITIONS})
    _targets_parse_platforms(PRIVATE_DEFINITIONS ${PRIVATE_DEFINITIONS})
    target_compile_definitions(
      ${args_TARGET}
      PUBLIC ${PUBLIC_DEFINITIONS}
      PRIVATE ${PRIVATE_DEFINITIONS}
    )

    # MSVC compiler and linker flags. Each flag is scoped to the configurations and
    # architectures where it is valid; injecting them unconditionally de-optimized
    # Release and broke ARM64 (see issue #5).
    if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
      # UTF-8 source and execution character sets: safe in every configuration and
      # on every architecture.
      target_compile_options(${args_TARGET} PRIVATE /utf-8)

      # Edit-and-continue debug info (/ZI) is a Debug-only developer convenience. It
      # de-optimizes Release builds and is only valid on x86/x64, so it is gated to
      # Debug via a generator expression, skipped on ARM/ARM64, and can be disabled
      # entirely with -DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF.
      if(TARGETS_MSVC_EDIT_AND_CONTINUE
         AND NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(ARM|ARM64|ARM64EC)$")
        target_compile_options(${args_TARGET} PRIVATE "$<$<CONFIG:Debug>:/ZI>")
      endif()

      # /SAFESEH:NO only affects the x86 (32-bit) linker: it is a silent no-op on x64,
      # invalid on ARM64, and ignored on static libraries (which are archived, not
      # linked). Restrict it to x86 executables and shared libraries.
      if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "X86"
         AND (args_TYPE STREQUAL "EXECUTABLE" OR args_SHARED))
        target_link_options(${args_TARGET} PRIVATE /SAFESEH:NO)
      endif()
    endif()

    # Add dependencies
    _targets_parse_access_specifier("cpp_target" DEPENDENCIES ${args_DEPENDENCIES})
    _targets_parse_platforms(PUBLIC_DEPENDENCIES ${PUBLIC_DEPENDENCIES})
    _targets_parse_platforms(PRIVATE_DEPENDENCIES ${PRIVATE_DEPENDENCIES})
    import_dependencies(${args_TARGET} "${PUBLIC_DEPENDENCIES}")
    import_dependencies(${args_TARGET} "${PRIVATE_DEPENDENCIES}")
    target_link_libraries(
      ${args_TARGET}
      PUBLIC ${PUBLIC_DEPENDENCIES}
      PRIVATE ${PRIVATE_DEPENDENCIES}
    )

    # Set version properties for libraries
    if(args_TYPE STREQUAL "LIBRARY" AND args_VERSION)
      set_target_properties(${args_TARGET} PROPERTIES VERSION ${args_VERSION})
      if(args_SOVERSION)
        set_target_properties(${args_TARGET} PROPERTIES SOVERSION ${args_SOVERSION})
      endif()
    endif()

    # Set IDE folder
    if(args_FOLDER)
      set_target_properties(${args_TARGET} PROPERTIES FOLDER "${args_FOLDER}")
    elseif(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
      set_target_properties(${args_TARGET} PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}/${relative_path_from_root}")
    else()
      set_target_properties(${args_TARGET} PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}")
    endif()

    # Set working directory for executables (debugger)
    if(args_TYPE STREQUAL "EXECUTABLE" AND args_WORKING_DIRECTORY)
      set_target_properties(
        ${args_TARGET}
        PROPERTIES
          VS_DEBUGGER_WORKING_DIRECTORY "${args_WORKING_DIRECTORY}"
      )
    endif()

    # Set debugger command arguments for executables
    if(args_TYPE STREQUAL "EXECUTABLE" AND args_COMMAND_ARGUMENTS)
      set_target_properties(
        ${args_TARGET}
        PROPERTIES
          VS_DEBUGGER_COMMAND_ARGUMENTS "${args_COMMAND_ARGUMENTS}"
      )
    endif()

    # Configure precompiled headers
    if(args_PRECOMPILE_HEADERS)
      target_precompile_headers(${args_TARGET} PRIVATE ${args_PRECOMPILE_HEADERS})
    endif()

    # Configure unity builds
    if(args_UNITY_BUILD)
      set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD ON)
      if(args_UNITY_BUILD_BATCH_SIZE)
        set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD_BATCH_SIZE ${args_UNITY_BUILD_BATCH_SIZE})
      else()
        set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD_BATCH_SIZE 16)
      endif()
    endif()

    # Apply additional properties
    if(args_PROPERTIES)
      set_target_properties(${args_TARGET} PROPERTIES ${args_PROPERTIES})
    endif()
  endif()
endfunction()
