# Example: runtime DATA staging (issue #27)
# Demonstrates the DATA attribute: a cpp_binary declares a runtime data file, and Targets
# copies it next to the built executable after the build (via a POST_BUILD custom command),
# mirroring the runtime-DLL staging of issue #21. The program opens the staged file with a
# relative path, so running it from its own output directory just works -- proving the data
# landed next to the binary.
#
# CI builds this example on all three OSes and runs the executable from its output directory;
# a missing data file makes the program exit non-zero and fails the job.

cmake_minimum_required(VERSION 3.20)
project(DataFilesExample VERSION 1.0.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# The DATA entry is resolved relative to the calling directory (like SOURCES) and staged as
# "message.txt" next to DataApp's executable.
cpp_binary(
    TARGET DataApp
    SOURCES src/main.cpp
    DATA data/message.txt
    CXX_STANDARD 17
)

message(STATUS "Example: data_files - Created DataApp with staged DATA")
