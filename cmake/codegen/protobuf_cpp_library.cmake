# protobuf_cpp_library.cmake
# Generate C++ sources from Protocol Buffers (.proto) files -- optionally with gRPC
# service stubs -- and wrap them in a linkable library.

include_guard(GLOBAL)

get_filename_component(_TARGETS_CODEGEN_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_CODEGEN_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")
# For the shared _targets_check_args() argument validator and the
# _targets_partition_files_by_root() source_group helper (see issue #6).
include("${_TARGETS_ROOT_DIR}/core/cpp_target.cmake")

# Records the proto import root(s) a target exposes so a dependent protobuf_cpp_library can
# add them to protoc's -I search path when its own .proto files `import` this target's
# schemas (mirrors flatbuffer_cpp_library's FLATBUFFERS_SCHEMA_DIR).
define_property(TARGET PROPERTY PROTOBUF_IMPORT_DIRS
  BRIEF_DOCS "Proto import directories exposed by this target"
  FULL_DOCS "Directories added to protoc's -I search path for targets that import this target's .proto files"
)

# Generate a C++ library from Protocol Buffers schemas.
#
# Runs protoc to turn each .proto into <name>.pb.cc / <name>.pb.h and builds a STATIC
# library from the generated sources, wired with the generated-header include directory and
# a PUBLIC link to the protobuf runtime. grpc_cpp_library() additionally runs the gRPC C++
# plugin to emit <name>.grpc.pb.cc / <name>.grpc.pb.h and links gRPC::grpc++.
#
# Arguments:
#   TARGET: The name of the library target to generate (required).
#   PROTOS: The list of .proto files to generate code for (required).
#   PROTO_ROOT_DIR: Root for resolving proto imports and the generated output layout;
#                   protoc's primary -I. Default: CMAKE_CURRENT_LIST_DIR.
#   IMPORT_DIRS: Additional directories added to protoc's -I search path.
#   NAMESPACE_ROOT: Root for the namespace alias / IDE folder. Default:
#                   PROJECT_SOURCE_DIR/Source (matches cpp_target()).
#   DEPENDENCIES: Other proto library targets this one links and imports from.
#   FLAGS: Additional flags passed through to protoc.
#
# Example:
#   protobuf_cpp_library(
#       TARGET MyProtos
#       PROTOS messages/person.proto
#       IMPORT_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/vendor/proto"
#       DEPENDENCIES CommonProtos
#   )
#   grpc_cpp_library(
#       TARGET MyServices
#       PROTOS services/greeter.proto
#       DEPENDENCIES MyProtos
#   )
function(protobuf_cpp_library)
  _targets_protobuf_cpp_library(FALSE ${ARGN})
endfunction()

function(grpc_cpp_library)
  _targets_protobuf_cpp_library(TRUE ${ARGN})
endfunction()

# Shared implementation of protobuf_cpp_library() and grpc_cpp_library(). The leading
# enable_grpc positional flag (TRUE only from grpc_cpp_library) turns on gRPC service-stub
# generation and the gRPC::grpc++ link; everything else is identical, so the two public rules
# stay in lockstep. The flag is a private positional -- not a parsed keyword -- so it never
# appears in the public argument surface (a caller cannot smuggle gRPC generation into
# protobuf_cpp_library) and is not advertised by the unknown-argument diagnostic.
function(_targets_protobuf_cpp_library enable_grpc)
  set(options)
  set(one_value_args
    TARGET
    PROTO_ROOT_DIR
    NAMESPACE_ROOT
  )
  set(multi_value_args
    PROTOS
    IMPORT_DIRS
    DEPENDENCIES
    FLAGS
  )

  # Parse from index 1: index 0 is the enable_grpc flag consumed above.
  cmake_parse_arguments(
    PARSE_ARGV 1
    args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Name the calling rule in diagnostics.
  if(enable_grpc)
    set(rule "grpc_cpp_library")
  else()
    set(rule "protobuf_cpp_library")
  endif()

  # Reject typo'd or misplaced arguments instead of silently ignoring them (see issue #4).
  _targets_check_args("${rule}"
    "${args_UNPARSED_ARGUMENTS}"
    "${args_KEYWORDS_MISSING_VALUES}"
    ${options} ${one_value_args} ${multi_value_args})

  # Validate required arguments.
  if(NOT args_TARGET)
    message(FATAL_ERROR "${rule}: TARGET must be provided")
  endif()
  if(NOT args_PROTOS)
    message(FATAL_ERROR "${rule}: PROTOS must be provided")
  endif()

  # Set defaults.
  if(NOT args_PROTO_ROOT_DIR)
    set(args_PROTO_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}")
  elseif(NOT IS_ABSOLUTE "${args_PROTO_ROOT_DIR}")
    set(args_PROTO_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/${args_PROTO_ROOT_DIR}")
  endif()

  if(NOT args_NAMESPACE_ROOT)
    set(args_NAMESPACE_ROOT "${PROJECT_SOURCE_DIR}/Source")
  endif()

  # Resolve proto files to absolute paths (relative resolves against the caller's dir).
  unset(proto_paths)
  foreach(proto IN LISTS args_PROTOS)
    if(IS_ABSOLUTE "${proto}")
      list(APPEND proto_paths "${proto}")
    else()
      list(APPEND proto_paths "${CMAKE_CURRENT_LIST_DIR}/${proto}")
    endif()
  endforeach()

  # Locate protoc. Prefer the imported target from find_package(Protobuf) so the generator
  # correctly serializes a DEPENDS on the tool; fall back to the executable variable. protoc
  # is resolved at the point of use (not module-include time) so include(Targets) stays
  # side-effect free for projects that never call this rule (compare issue #3).
  if(TARGET protobuf::protoc)
    set(protoc_dependency protobuf::protoc)
    set(protoc "$<TARGET_FILE:protobuf::protoc>")
  elseif(Protobuf_PROTOC_EXECUTABLE)
    set(protoc_dependency "")
    set(protoc "${Protobuf_PROTOC_EXECUTABLE}")
  elseif(PROTOBUF_PROTOC_EXECUTABLE)
    set(protoc_dependency "")
    set(protoc "${PROTOBUF_PROTOC_EXECUTABLE}")
  else()
    message(FATAL_ERROR
      "${rule}: protoc not found. Call find_package(Protobuf) first (e.g. install protobuf "
      "via vcpkg) so the protobuf::protoc target or Protobuf_PROTOC_EXECUTABLE is available.")
  endif()

  # Locate the gRPC C++ plugin when generating service stubs.
  set(grpc_plugin_dependency "")
  if(enable_grpc)
    if(TARGET gRPC::grpc_cpp_plugin)
      set(grpc_plugin_dependency gRPC::grpc_cpp_plugin)
      set(grpc_plugin "$<TARGET_FILE:gRPC::grpc_cpp_plugin>")
    elseif(GRPC_CPP_PLUGIN_EXECUTABLE)
      set(grpc_plugin "${GRPC_CPP_PLUGIN_EXECUTABLE}")
    else()
      message(FATAL_ERROR
        "${rule}: grpc_cpp_plugin not found. Call find_package(gRPC) first (e.g. install "
        "grpc via vcpkg) so the gRPC::grpc_cpp_plugin target is available.")
    endif()
  endif()

  # Auto-import namespaced proto dependencies (same mechanism as cpp_target/flatbuffer).
  import_dependencies(${args_TARGET} "${args_DEPENDENCIES}")

  # Build protoc's -I search path: this target's proto root, the caller's IMPORT_DIRS, and
  # the import roots exposed by proto dependencies (so cross-target `import` statements
  # resolve during code generation). The dependency roots are also re-exported on this target
  # (below) so the search path propagates transitively down a dependency chain.
  set(import_params "-I" "${args_PROTO_ROOT_DIR}")
  set(exported_import_dirs "${args_PROTO_ROOT_DIR}")
  foreach(import_dir IN LISTS args_IMPORT_DIRS)
    if(NOT IS_ABSOLUTE "${import_dir}")
      set(import_dir "${CMAKE_CURRENT_LIST_DIR}/${import_dir}")
    endif()
    list(APPEND import_params "-I" "${import_dir}")
  endforeach()
  foreach(dependency IN LISTS args_DEPENDENCIES)
    if(TARGET ${dependency})
      get_target_property(dependency_import_dirs ${dependency} PROTOBUF_IMPORT_DIRS)
      if(dependency_import_dirs)
        foreach(dependency_import_dir IN LISTS dependency_import_dirs)
          list(APPEND import_params "-I" "${dependency_import_dir}")
          list(APPEND exported_import_dirs "${dependency_import_dir}")
        endforeach()
      endif()
    endif()
  endforeach()
  list(REMOVE_DUPLICATES exported_import_dirs)

  # Generated sources live in the build tree, out of the source root. protoc creates the
  # nested package subdirectories itself, so only the base directory must exist up front.
  set(generated_source_dir "${CMAKE_CURRENT_BINARY_DIR}/_protobuf_cpp_library/${args_TARGET}")
  file(MAKE_DIRECTORY "${generated_source_dir}")

  # Generate C++ for each proto.
  unset(all_generated_sources)
  unset(all_generated_headers)
  foreach(proto IN LISTS proto_paths)
    if(NOT EXISTS "${proto}")
      message(FATAL_ERROR "${rule}: proto file does not exist: ${proto}")
    endif()

    # Predict protoc's output path: the proto's location relative to PROTO_ROOT_DIR with the
    # extension swapped. protoc mirrors that relative structure under --cpp_out.
    file(RELATIVE_PATH relative_proto "${args_PROTO_ROOT_DIR}" "${proto}")
    # Precise out-of-root test (matches _targets_partition_files_by_root): a path on another
    # drive stays absolute, and one above the root is ".." or begins "../". A leading-".." in
    # the *filename* (e.g. "..foo.proto") is legitimately under the root and must not trip.
    if(IS_ABSOLUTE "${relative_proto}"
        OR relative_proto STREQUAL ".."
        OR relative_proto MATCHES "^\\.\\./")
      message(FATAL_ERROR
        "${rule}: proto file '${proto}' is not located under PROTO_ROOT_DIR "
        "'${args_PROTO_ROOT_DIR}'. Set PROTO_ROOT_DIR to a directory that contains the "
        "proto files so protoc can resolve their import paths.")
    endif()
    string(REGEX REPLACE "\\.proto$" "" relative_stem "${relative_proto}")

    set(pb_header "${generated_source_dir}/${relative_stem}.pb.h")
    set(pb_source "${generated_source_dir}/${relative_stem}.pb.cc")

    set(outputs "${pb_header}" "${pb_source}")
    set(protoc_args ${import_params} "--cpp_out=${generated_source_dir}")

    if(enable_grpc)
      set(grpc_header "${generated_source_dir}/${relative_stem}.grpc.pb.h")
      set(grpc_source "${generated_source_dir}/${relative_stem}.grpc.pb.cc")
      list(APPEND outputs "${grpc_header}" "${grpc_source}")
      list(APPEND protoc_args
        "--grpc_out=${generated_source_dir}"
        "--plugin=protoc-gen-grpc=${grpc_plugin}")
    endif()

    get_filename_component(proto_name "${proto}" NAME)
    add_custom_command(
      OUTPUT ${outputs}
      COMMAND ${protoc} ${protoc_args} ${args_FLAGS} "${proto}"
      DEPENDS
        ${protoc_dependency}
        ${grpc_plugin_dependency}
        "${proto}"
      WORKING_DIRECTORY "${args_PROTO_ROOT_DIR}"
      COMMENT "Generating C++ from ${proto_name}"
      VERBATIM
    )

    list(APPEND all_generated_headers "${pb_header}")
    list(APPEND all_generated_sources "${pb_source}")
    if(enable_grpc)
      list(APPEND all_generated_headers "${grpc_header}")
      list(APPEND all_generated_sources "${grpc_source}")
    endif()
  endforeach()

  # Create the library from the generated sources. The generated .pb.cc files are real
  # translation units, so -- unlike a header-only flatbuffer library -- no dummy.cpp
  # placeholder is required.
  add_library(${args_TARGET} STATIC)

  target_sources(${args_TARGET}
    PRIVATE
      ${all_generated_sources}
      ${all_generated_headers}
      ${proto_paths}
  )

  # The generated .pb.h files include each other by their path relative to the output root,
  # so expose that directory to this target and its consumers.
  target_include_directories(${args_TARGET}
    PUBLIC
      "$<BUILD_INTERFACE:${generated_source_dir}>"
  )

  # protobuf-generated code requires at least C++17. The protobuf runtime target normally
  # propagates a cxx_std_* compile feature, but the variable-only fallback below carries no
  # usage requirements, so pin a floor here to keep the .pb.cc compiling regardless.
  set_target_properties(${args_TARGET} PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON)

  # Record this target's import roots (its own proto root plus every dependency's, so the set
  # is transitive) for any dependent protobuf_cpp_library to add to protoc's -I path.
  set_property(TARGET ${args_TARGET} PROPERTY PROTOBUF_IMPORT_DIRS "${exported_import_dirs}")

  # Link the protobuf runtime (and the gRPC C++ runtime for service stubs). Their include
  # directories flow to consumers as usage requirements.
  if(TARGET protobuf::libprotobuf)
    target_link_libraries(${args_TARGET} PUBLIC protobuf::libprotobuf)
  elseif(Protobuf_LIBRARIES)
    # Old-style FindProtobuf variables carry no usage requirements, so the protobuf headers
    # must be added explicitly or the generated code cannot find <google/protobuf/...>.
    target_link_libraries(${args_TARGET} PUBLIC ${Protobuf_LIBRARIES})
    if(Protobuf_INCLUDE_DIRS)
      target_include_directories(${args_TARGET} PUBLIC ${Protobuf_INCLUDE_DIRS})
    endif()
  endif()

  if(enable_grpc AND TARGET gRPC::grpc++)
    target_link_libraries(${args_TARGET} PUBLIC gRPC::grpc++)
  endif()

  # Link proto dependencies. Their PUBLIC generated-header include dirs flow transitively so
  # cross-proto `import`s resolve at compile time.
  if(args_DEPENDENCIES)
    target_link_libraries(${args_TARGET} PUBLIC ${args_DEPENDENCIES})
  endif()

  # Namespace alias + IDE folder, derived from the *enclosing* project (PROJECT_NAME) and the
  # target's path relative to NAMESPACE_ROOT. This mirrors cpp_target() and
  # flatbuffer_cpp_library(); keying off the enclosing project keeps an embedded proto
  # library's alias stable (see issue #8).
  if(EXISTS "${args_NAMESPACE_ROOT}")
    file(RELATIVE_PATH relative_path_from_root "${args_NAMESPACE_ROOT}" "${CMAKE_CURRENT_LIST_DIR}")
  else()
    set(relative_path_from_root "")
  endif()

  set(default_folder "${PROJECT_NAME}")
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set(default_folder "${default_folder}/${relative_path_from_root}")
  endif()

  string(REPLACE "/" "::" namespace "${default_folder}")
  add_library("${namespace}::${args_TARGET}" ALIAS ${args_TARGET})

  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}/${relative_path_from_root}")
  else()
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}")
  endif()

  # IDE source groups. source_group(TREE ...) hard-errors on any file outside its root, so
  # generated sources (build tree) and proto sources (source tree) are each partitioned and
  # only the in-root files get a TREE grouping; out-of-root files fall back to a flat group
  # (see issue #6).
  _targets_partition_files_by_root(
    "${generated_source_dir}" in_tree_generated out_of_tree_generated
    ${all_generated_sources} ${all_generated_headers})
  if(in_tree_generated)
    source_group(TREE "${generated_source_dir}" PREFIX "Generated Files" FILES ${in_tree_generated})
  endif()
  if(out_of_tree_generated)
    source_group("Generated Files" FILES ${out_of_tree_generated})
  endif()

  _targets_partition_files_by_root(
    "${args_PROTO_ROOT_DIR}" in_tree_protos out_of_tree_protos ${proto_paths})
  if(in_tree_protos)
    source_group(TREE "${args_PROTO_ROOT_DIR}" PREFIX "Proto Files" FILES ${in_tree_protos})
  endif()
  if(out_of_tree_protos)
    source_group("Proto Files" FILES ${out_of_tree_protos})
  endif()
endfunction()
