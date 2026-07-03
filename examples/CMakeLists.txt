# Examples for Targets library

cmake_minimum_required(VERSION 3.20)

# Add examples as subdirectories
add_subdirectory(executable_with_deps)
add_subdirectory(embed_binary)
add_subdirectory(install_export)
add_subdirectory(shared_library)
add_subdirectory(toolchain_hygiene)

# Add FlatBuffers example if FlatBuffers is available
find_package(Flatbuffers QUIET)
if(Flatbuffers_FOUND OR TARGET flatbuffers::flatc OR TARGET flatc)
    add_subdirectory(codegen_flatbuffers)
endif()

# Add the Protobuf example. Unlike the FlatBuffers guard above, protobuf is NOT probed here:
# find_package(Protobuf) pulls in FindThreads, which hard-errors unless a compiler language is
# enabled -- and this top-level examples project is LANGUAGES NONE (each example enables CXX in
# its own project()). The example's subdirectory declares project(... LANGUAGES CXX) and runs
# find_package(Protobuf QUIET) there, returning early when Protocol Buffers is absent, so a
# toolchain without it still configures and builds cleanly.
add_subdirectory(codegen_protobuf)
