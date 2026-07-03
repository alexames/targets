# Configure-mode regression test for embed_binary().
#
# Regression test for https://github.com/alexames/targets/issues/1: embed_binary()
# aborted configuration with an invalid ${list(LENGTH ...)} reference in message(),
# so no call could ever succeed. Configuring this project reaches completion only if
# the function runs end to end; the assertions below also confirm it produced outputs.

cmake_minimum_required(VERSION 3.20)
project(TestEmbedBinary LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

# Create a data file to embed. Keeping it in the build tree makes the test
# self-contained (no committed binary fixture required).
set(data_file "${CMAKE_CURRENT_BINARY_DIR}/payload.bin")
file(WRITE "${data_file}" "targets-embed-binary-test-payload")

embed_binary(
    TARGET EmbeddedTestData
    FILES
        "${data_file}"
    NAMESPACE test::embedded
)

# The function must have created the library target...
if(NOT TARGET EmbeddedTestData)
  message(FATAL_ERROR "embed_binary did not create target EmbeddedTestData")
endif()

# ...and emitted generated sources for the embedded file.
set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/_embed_binary/EmbeddedTestData")
if(NOT EXISTS "${generated_dir}/payload_bin.h")
  message(FATAL_ERROR "embed_binary did not generate header payload_bin.h")
endif()
if(NOT EXISTS "${generated_dir}/payload_bin.cpp")
  message(FATAL_ERROR "embed_binary did not generate source payload_bin.cpp")
endif()

message(STATUS "embed_binary configure-mode test passed")
