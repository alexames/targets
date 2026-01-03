# Examples for Targets library

cmake_minimum_required(VERSION 3.20)

# Add examples as subdirectories
add_subdirectory(executable_with_deps)

# Add FlatBuffers example if FlatBuffers is available
find_package(Flatbuffers QUIET)
if(Flatbuffers_FOUND OR TARGET flatbuffers::flatc OR TARGET flatc)
    add_subdirectory(codegen_flatbuffers)
endif()
