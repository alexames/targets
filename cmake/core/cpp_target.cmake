# cpp_target.cmake
# Core target abstraction for Targets library
# Provides unified interface for creating C++ libraries and executables

include_guard(GLOBAL)

# Enable folder organization in IDEs
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Include dependency management
get_filename_component(_TARGETS_MODULE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_MODULE_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")

# Helper function to parse PUBLIC/PRIVATE access specifiers
function(_targets_parse_access_specifier VAR_NAME)
  set(options)
  set(one_value_args)
  set(multi_value_args PUBLIC PRIVATE)
  cmake_parse_arguments(
    PARSE_ARGV 1
    ACCESS_SPECIFIER
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")
  set(PUBLIC_${VAR_NAME} ${ACCESS_SPECIFIER_PUBLIC} PARENT_SCOPE)
  set(PRIVATE_${VAR_NAME} ${ACCESS_SPECIFIER_PRIVATE} PARENT_SCOPE)
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

  # Gather source files
  unset(sources)
  foreach(source ${args_SOURCES})
    if(IS_ABSOLUTE "${source}")
      list(APPEND sources "${source}")
    else()
      list(APPEND sources "${args_SOURCE_DIR}/${source}")
    endif()
  endforeach()

  # Create source groups for IDE organization
  if(sources)
    source_group(TREE "${args_SOURCE_DIR}" PREFIX "Source Files" FILES ${sources})
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

  # Create header source groups
  if(headers)
    source_group(TREE "${args_HEADER_DIR}" PREFIX "Header Files" FILES ${headers})
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
    _targets_parse_access_specifier(INCLUDES ${args_INCLUDES})
    target_include_directories(${args_TARGET} INTERFACE ${PUBLIC_INCLUDES})

    _targets_parse_access_specifier(DEFINITIONS ${args_DEFINITIONS})
    target_compile_definitions(${args_TARGET} INTERFACE ${PUBLIC_DEFINITIONS})

    _targets_parse_access_specifier(DEPENDENCIES ${args_DEPENDENCIES})
    import_dependencies(${args_TARGET} "${PUBLIC_DEPENDENCIES}")
    target_link_libraries(${args_TARGET} INTERFACE ${PUBLIC_DEPENDENCIES})

    target_compile_features(${args_TARGET} INTERFACE cxx_std_${args_CXX_STANDARD})
  else()
    # Regular libraries and executables

    # Add include directories
    _targets_parse_access_specifier(INCLUDES ${args_INCLUDES})
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
    _targets_parse_access_specifier(DEFINITIONS ${args_DEFINITIONS})
    target_compile_definitions(
      ${args_TARGET}
      PUBLIC ${PUBLIC_DEFINITIONS}
      PRIVATE ${PRIVATE_DEFINITIONS}
    )

    # Platform-specific compiler settings
    if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
      target_compile_options(${args_TARGET} PRIVATE
        /utf-8        # UTF-8 source and execution
        /ZI           # Edit and continue debug info
      )
      target_link_options(${args_TARGET} PRIVATE
        /SAFESEH:NO   # Disable safe exception handlers
      )
    endif()

    # Add dependencies
    _targets_parse_access_specifier(DEPENDENCIES ${args_DEPENDENCIES})
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
