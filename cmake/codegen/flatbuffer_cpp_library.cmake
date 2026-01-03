# flatbuffer_cpp_library.cmake
# Generate C++ headers from FlatBuffers schema files

include_guard(GLOBAL)

get_filename_component(_TARGETS_CODEGEN_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_CODEGEN_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")

# Define custom target property for schema directories
define_property(TARGET PROPERTY FLATBUFFERS_SCHEMA_DIR
  BRIEF_DOCS "Directory containing FlatBuffers schema files"
  FULL_DOCS "The root directory containing .fbs schema files for this target"
)

# Generate C++ headers from FlatBuffers schemas
#
# Creates a target that can be linked against that generates flatbuffer headers.
#
# Arguments:
#   TARGET: The name of the target to generate (required)
#   SCHEMAS: The list of schema files to generate code for (required)
#   SCHEMA_ROOT_DIR: Root directory for schema includes (default: PROJECT_SOURCE_DIR/Source)
#   INCLUDE_PREFIX: Prefix path for generated headers
#   BINARY_SCHEMAS_DIR: Directory for binary schema output (.bfbs files)
#   DEPENDENCIES: Dependencies on other FlatBuffer schema targets
#   FLAGS: Additional flags to pass to flatc compiler
#
# Example:
#   flatbuffer_cpp_library(
#       TARGET GameSchemas
#       SCHEMAS
#           schemas/player.fbs
#           schemas/world.fbs
#       SCHEMA_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
#       INCLUDE_PREFIX "game/generated"
#       BINARY_SCHEMAS_DIR "${CMAKE_BINARY_DIR}/schemas"
#       DEPENDENCIES CommonSchemas
#       FLAGS --gen-mutable
#   )
function(flatbuffer_cpp_library)
  # Parse function arguments
  set(options VERBOSE)
  set(one_value_args
    TARGET
    SCHEMA_ROOT_DIR
    INCLUDE_PREFIX
    BINARY_SCHEMAS_DIR
  )
  set(multi_value_args
    SCHEMAS
    DEPENDENCIES
    FLAGS
  )

  cmake_parse_arguments(
    PARSE_ARGV 0
    args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Validate required arguments
  if(NOT args_TARGET)
    message(FATAL_ERROR "flatbuffer_cpp_library: TARGET must be provided")
  endif()

  if(NOT args_SCHEMAS)
    message(FATAL_ERROR "flatbuffer_cpp_library: SCHEMAS must be provided")
  endif()

  # Set defaults
  if(NOT args_SCHEMA_ROOT_DIR)
    set(args_SCHEMA_ROOT_DIR "${PROJECT_SOURCE_DIR}/Source")
  endif()

  if(NOT args_BINARY_SCHEMAS_DIR)
    set(args_BINARY_SCHEMAS_DIR "${PROJECT_BINARY_DIR}/flatbuffers")
  endif()

  # Convert schema files to absolute paths
  unset(source_paths)
  foreach(source ${args_SCHEMAS})
    cmake_path(IS_ABSOLUTE "${source}" is_absolute)
    if(is_absolute)
      list(APPEND source_paths "${source}")
    else()
      list(APPEND source_paths "${CMAKE_CURRENT_LIST_DIR}/${source}")
    endif()
  endforeach()

  # Set default flatc flags if not provided
  if(NOT args_FLAGS)
    list(APPEND args_FLAGS
      "--scoped-enums"     # Use C++ enum class
      "--gen-object-api"   # Generate mutable object API
      "--keep-prefix"      # Preserve relative paths in includes
    )
  endif()

  # Add include prefix if specified
  if(args_INCLUDE_PREFIX)
    list(APPEND args_FLAGS "--include-prefix" "${args_INCLUDE_PREFIX}")
  endif()

  # Create output directory for generated headers
  set(generated_header_dir "${CMAKE_CURRENT_BINARY_DIR}/_flatbuffer_cpp_library/${args_TARGET}")

  # Find flatc compiler
  if(FLATBUFFERS_FLATC_EXECUTABLE)
    # Using FindFlatBuffers
    set(FLATC_TARGET "")
    set(FLATC "${FLATBUFFERS_FLATC_EXECUTABLE}")
  else()
    # Using flatc target from vcpkg or FetchContent
    if(TARGET flatbuffers::flatc)
      set(FLATC_TARGET flatbuffers::flatc)
      set(FLATC "$<TARGET_FILE:flatbuffers::flatc>")
    elseif(TARGET flatc)
      set(FLATC_TARGET flatc)
      set(FLATC "$<TARGET_FILE:flatc>")
    else()
      message(FATAL_ERROR "flatbuffer_cpp_library: flatc compiler not found. Please install FlatBuffers.")
    endif()
  endif()

  # Import schema dependencies
  import_dependencies(${args_TARGET} "${args_DEPENDENCIES}")

  # Collect include directories from dependencies
  set(include_params "")
  set(include_directories "")
  foreach(dependency ${args_DEPENDENCIES})
    if(TARGET ${dependency})
      get_target_property(dependency_schema_directories ${dependency} FLATBUFFERS_SCHEMA_DIR)
      if(dependency_schema_directories)
        foreach(schema_directory ${dependency_schema_directories})
          list(APPEND include_directories "${schema_directory}")
          list(APPEND include_params "-I" "${schema_directory}")
        endforeach()
      endif()
    endif()
  endforeach()

  # Generate code for each schema
  unset(all_generated_header_files)
  unset(all_generated_binary_files)

  foreach(schema ${source_paths})
    # Validate schema exists
    if(NOT EXISTS "${schema}")
      message(FATAL_ERROR "flatbuffer_cpp_library: Schema file does not exist: ${schema}")
    endif()

    # Get schema filename and directory
    get_filename_component(filename ${schema} NAME_WE)
    get_filename_component(schema_directory ${schema} DIRECTORY)

    # Calculate relative path from schema root
    file(RELATIVE_PATH relative_path "${args_SCHEMA_ROOT_DIR}" "${schema_directory}")

    # Determine output directory
    set(output_dir "${generated_header_dir}")
    if(args_INCLUDE_PREFIX)
      cmake_path(APPEND output_dir "${args_INCLUDE_PREFIX}")
    endif()
    cmake_path(APPEND output_dir "${relative_path}")

    # Generated header path
    set(generated_header "${output_dir}/${filename}_generated.h")

    # Create custom command to generate header
    add_custom_command(
      OUTPUT "${generated_header}"
      COMMAND ${FLATC}
        -o "${output_dir}"
        ${include_params}
        -c "${schema}"
        ${args_FLAGS}
      DEPENDS
        ${FLATC_TARGET}
        "${schema}"
      WORKING_DIRECTORY "${args_SCHEMA_ROOT_DIR}"
      COMMENT "Generating FlatBuffers C++ header: ${filename}_generated.h"
      VERBATIM
    )

    list(APPEND all_generated_header_files "${generated_header}")

    # Generate binary schema if directory specified
    if(args_BINARY_SCHEMAS_DIR)
      set(binary_schema_dir "${args_BINARY_SCHEMAS_DIR}")
      if(relative_path)
        cmake_path(APPEND binary_schema_dir "${relative_path}")
      endif()

      set(binary_schema "${binary_schema_dir}/${filename}.bfbs")

      add_custom_command(
        OUTPUT "${binary_schema}"
        COMMAND ${FLATC}
          -b
          --schema
          -o "${binary_schema_dir}"
          ${include_params}
          "${schema}"
        DEPENDS
          ${FLATC_TARGET}
          "${schema}"
        WORKING_DIRECTORY "${args_SCHEMA_ROOT_DIR}"
        COMMENT "Generating FlatBuffers binary schema: ${filename}.bfbs"
        VERBATIM
      )

      list(APPEND all_generated_binary_files "${binary_schema}")
    endif()
  endforeach()

  # Create dummy source file path
  set(dummy_file "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/dummy.cpp")

  # Create library target
  add_library(${args_TARGET} STATIC)

  # Add sources
  target_sources(${args_TARGET}
    PRIVATE
      ${all_generated_header_files}
      ${all_generated_binary_files}
      ${source_paths}
  )

  # Add dummy source if it exists
  if(EXISTS "${dummy_file}")
    target_sources(${args_TARGET} PRIVATE "${dummy_file}")
  endif()

  # Add include directories
  target_include_directories(${args_TARGET}
    PUBLIC
      "$<BUILD_INTERFACE:${generated_header_dir}>"
  )

  # Set schema directory property
  set_property(
    TARGET ${args_TARGET}
    PROPERTY FLATBUFFERS_SCHEMA_DIR "${args_SCHEMA_ROOT_DIR}"
  )

  # Link to FlatBuffers runtime
  if(TARGET flatbuffers::flatbuffers)
    target_link_libraries(${args_TARGET} PUBLIC flatbuffers::flatbuffers)
  elseif(TARGET flatbuffers)
    target_link_libraries(${args_TARGET} PUBLIC flatbuffers)
  endif()

  # Link dependencies
  if(args_DEPENDENCIES)
    target_link_libraries(${args_TARGET} PUBLIC ${args_DEPENDENCIES})
  endif()

  # Create namespace alias
  if(EXISTS "${args_SCHEMA_ROOT_DIR}")
    file(RELATIVE_PATH relative_path_from_root "${args_SCHEMA_ROOT_DIR}" "${CMAKE_CURRENT_LIST_DIR}")
  else()
    set(relative_path_from_root "")
  endif()

  set(default_folder "${CMAKE_PROJECT_NAME}")
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set(default_folder "${default_folder}/${relative_path_from_root}")
  endif()

  string(REPLACE "/" "::" namespace "${default_folder}")
  set(alias "${namespace}::${args_TARGET}")
  add_library(${alias} ALIAS ${args_TARGET})

  # Set IDE folder
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}/${relative_path_from_root}")
  else()
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}")
  endif()

  # Organize files in IDE
  source_group(
    TREE "${generated_header_dir}"
    PREFIX "Generated Headers"
    FILES ${all_generated_header_files}
  )

  source_group(
    TREE "${args_SCHEMA_ROOT_DIR}"
    PREFIX "Schemas"
    FILES ${source_paths}
  )

  if(all_generated_binary_files)
    source_group(
      TREE "${args_BINARY_SCHEMAS_DIR}"
      PREFIX "Binary Schemas"
      FILES ${all_generated_binary_files}
    )
  endif()

  if(EXISTS "${dummy_file}")
    source_group("CMake Rules" FILES "${dummy_file}")
  endif()
endfunction()
