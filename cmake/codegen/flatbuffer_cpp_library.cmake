# flatbuffer_cpp_library(): compile .fbs schemas into a linkable C++ library.

include_guard(GLOBAL)

get_filename_component(_TARGETS_CODEGEN_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_CODEGEN_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")
# For _targets_check_args(), _targets_dummy_source(), _targets_partition_files_by_root() and
# _targets_apply_common_target_defaults().
include("${_TARGETS_ROOT_DIR}/core/cpp_target.cmake")

define_property(TARGET PROPERTY FLATBUFFERS_SCHEMA_DIR
  BRIEF_DOCS "Directory containing FlatBuffers schema files"
  FULL_DOCS "The root directory containing .fbs schema files for this target"
)

# Generate a C++ library from FlatBuffers schemas.
#
# Runs flatc over each .fbs to produce a <name>_generated.h and builds a STATIC library from
# them, with the generated-header directory on the library's PUBLIC include path: a consumer
# names the target under DEPENDENCIES and includes the headers, with nothing else to wire.
#
# Arguments:
#   TARGET: Name of the library target to create (required).
#   SCHEMAS: The .fbs files to compile (required). A relative entry resolves against the
#            calling CMakeLists directory; each must exist at configure time.
#   SCHEMA_ROOT_DIR: Root the generated output layout mirrors, and flatc's working directory
#                    (default: PROJECT_SOURCE_DIR/Source). Also published to dependents as
#                    this target's FLATBUFFERS_SCHEMA_DIR.
#   INCLUDE_PREFIX: Path prepended to the generated headers' location, and passed to flatc as
#                   --include-prefix so cross-schema includes agree with it (default: none).
#   BINARY_SCHEMAS_DIR: Where the .bfbs binary schemas are written (default:
#                       PROJECT_BINARY_DIR/flatbuffers). Binary schemas are always generated.
#   DEPENDENCIES: Other flatbuffer_cpp_library targets. Linked PUBLIC, and their schema
#                 directories are added to flatc's -I path so cross-target includes resolve.
#   FLAGS: Flags passed to flatc, REPLACING the defaults below rather than adding to them.
#   VERBOSE: Accepted and unused.
#
# The paths given here are resolved once and baked into the generated build rules, so a file
# moved afterward is not picked up until the next configure.
#
# FATAL_ERROR when TARGET or SCHEMAS is missing, an argument is unrecognized, a named schema
# does not exist, flatc cannot be located, or the placeholder translation unit is missing from
# the Targets package.
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

  _targets_check_args("flatbuffer_cpp_library"
    "${args_UNPARSED_ARGUMENTS}"
    "${args_KEYWORDS_MISSING_VALUES}"
    ${options} ${one_value_args} ${multi_value_args})

  if(NOT args_TARGET)
    message(FATAL_ERROR "flatbuffer_cpp_library: TARGET must be provided")
  endif()

  if(NOT args_SCHEMAS)
    message(FATAL_ERROR "flatbuffer_cpp_library: SCHEMAS must be provided")
  endif()

  if(NOT args_SCHEMA_ROOT_DIR)
    set(args_SCHEMA_ROOT_DIR "${PROJECT_SOURCE_DIR}/Source")
  endif()

  if(NOT args_BINARY_SCHEMAS_DIR)
    set(args_BINARY_SCHEMAS_DIR "${PROJECT_BINARY_DIR}/flatbuffers")
  endif()

  unset(source_paths)
  foreach(source IN LISTS args_SCHEMAS)
    cmake_path(IS_ABSOLUTE source is_absolute)
    if(is_absolute)
      list(APPEND source_paths "${source}")
    else()
      list(APPEND source_paths "${CMAKE_CURRENT_LIST_DIR}/${source}")
    endif()
  endforeach()

  # A caller's FLAGS replace these rather than extending them, so the defaults are only
  # applied when the keyword is absent.
  if(NOT args_FLAGS)
    list(APPEND args_FLAGS
      "--scoped-enums"     # Use C++ enum class
      "--gen-object-api"   # Generate mutable object API
      "--keep-prefix"      # Preserve relative paths in includes
    )
  endif()

  if(args_INCLUDE_PREFIX)
    list(APPEND args_FLAGS "--include-prefix" "${args_INCLUDE_PREFIX}")
  endif()

  set(generated_header_dir "${CMAKE_CURRENT_BINARY_DIR}/_flatbuffer_cpp_library/${args_TARGET}")

  # FindFlatBuffers names an already-installed flatc in a variable; vcpkg and FetchContent
  # provide an imported target instead, whose $<TARGET_FILE:...> lets the custom commands
  # DEPEND on the tool so a flatc built from source is built first.
  if(FLATBUFFERS_FLATC_EXECUTABLE)
    set(FLATC_TARGET "")
    set(FLATC "${FLATBUFFERS_FLATC_EXECUTABLE}")
  else()
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

  import_dependencies(${args_TARGET} "${args_DEPENDENCIES}")

  # Build flatc's -I search path from the schema roots the dependencies publish, so an
  # `include` statement crossing targets resolves during generation.
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

  unset(all_generated_header_files)
  unset(all_generated_binary_files)

  foreach(schema ${source_paths})
    if(NOT EXISTS "${schema}")
      message(FATAL_ERROR "flatbuffer_cpp_library: Schema file does not exist: ${schema}")
    endif()

    get_filename_component(filename ${schema} NAME_WE)
    get_filename_component(schema_directory ${schema} DIRECTORY)

    # The generated tree mirrors each schema's location relative to the schema root, so two
    # schemas of the same name in different directories do not collide.
    file(RELATIVE_PATH relative_path "${args_SCHEMA_ROOT_DIR}" "${schema_directory}")

    set(output_dir "${generated_header_dir}")
    if(args_INCLUDE_PREFIX)
      cmake_path(APPEND output_dir "${args_INCLUDE_PREFIX}")
    endif()
    cmake_path(APPEND output_dir "${relative_path}")

    set(generated_header "${output_dir}/${filename}_generated.h")

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

  # A flatbuffer library generates headers and binary schemas, never a translation unit, and
  # MSVC needs a real one to archive a static library; the shipped placeholder is it. Resolving
  # it here is a hard error, so a package that failed to ship dummy.cpp says so instead of
  # producing an empty library in silence.
  _targets_dummy_source(dummy_file)

  add_library(${args_TARGET} STATIC)

  _targets_apply_common_target_defaults(${args_TARGET})

  target_sources(${args_TARGET}
    PRIVATE
      ${all_generated_header_files}
      ${all_generated_binary_files}
      ${source_paths}
  )

  target_sources(${args_TARGET} PRIVATE "${dummy_file}")

  target_include_directories(${args_TARGET}
    PUBLIC
      "$<BUILD_INTERFACE:${generated_header_dir}>"
  )

  # Published for dependent rules to read back as an -I entry.
  set_property(
    TARGET ${args_TARGET}
    PROPERTY FLATBUFFERS_SCHEMA_DIR "${args_SCHEMA_ROOT_DIR}"
  )

  if(TARGET flatbuffers::flatbuffers)
    target_link_libraries(${args_TARGET} PUBLIC flatbuffers::flatbuffers)
  elseif(TARGET flatbuffers)
    target_link_libraries(${args_TARGET} PUBLIC flatbuffers)
  endif()

  if(args_DEPENDENCIES)
    target_link_libraries(${args_TARGET} PUBLIC ${args_DEPENDENCIES})
  endif()

  if(EXISTS "${args_SCHEMA_ROOT_DIR}")
    file(RELATIVE_PATH relative_path_from_root "${args_SCHEMA_ROOT_DIR}" "${CMAKE_CURRENT_LIST_DIR}")
  else()
    set(relative_path_from_root "")
  endif()

  # The namespace root is the *enclosing* project (PROJECT_NAME) rather than the top-level one
  # (CMAKE_PROJECT_NAME), so an embedded schema library keeps the alias it has standalone.
  # This mirrors cpp_target()'s derivation; keep the two consistent.
  set(default_folder "${PROJECT_NAME}")
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set(default_folder "${default_folder}/${relative_path_from_root}")
  endif()

  string(REPLACE "/" "::" namespace "${default_folder}")
  set(alias "${namespace}::${args_TARGET}")
  add_library(${alias} ALIAS ${args_TARGET})

  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}/${relative_path_from_root}")
  else()
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}")
  endif()

  # source_group(TREE ...) hard-errors on any file outside its root, so each file list is
  # partitioned and only the in-root files get a TREE grouping; out-of-root files (generated
  # headers and binary schemas written to the build tree, or `..`-relative schemas) fall back
  # to a flat group.
  _targets_partition_files_by_root(
    "${generated_header_dir}" in_tree_headers out_of_tree_headers
    ${all_generated_header_files})
  if(in_tree_headers)
    source_group(TREE "${generated_header_dir}" PREFIX "Generated Headers" FILES ${in_tree_headers})
  endif()
  if(out_of_tree_headers)
    source_group("Generated Headers" FILES ${out_of_tree_headers})
  endif()

  _targets_partition_files_by_root(
    "${args_SCHEMA_ROOT_DIR}" in_tree_schemas out_of_tree_schemas ${source_paths})
  if(in_tree_schemas)
    source_group(TREE "${args_SCHEMA_ROOT_DIR}" PREFIX "Schemas" FILES ${in_tree_schemas})
  endif()
  if(out_of_tree_schemas)
    source_group("Schemas" FILES ${out_of_tree_schemas})
  endif()

  if(all_generated_binary_files)
    _targets_partition_files_by_root(
      "${args_BINARY_SCHEMAS_DIR}" in_tree_binaries out_of_tree_binaries
      ${all_generated_binary_files})
    if(in_tree_binaries)
      source_group(TREE "${args_BINARY_SCHEMAS_DIR}" PREFIX "Binary Schemas" FILES ${in_tree_binaries})
    endif()
    if(out_of_tree_binaries)
      source_group("Binary Schemas" FILES ${out_of_tree_binaries})
    endif()
  endif()

  source_group("CMake Rules" FILES "${dummy_file}")
endfunction()
