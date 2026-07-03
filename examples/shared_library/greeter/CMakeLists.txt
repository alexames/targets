# The SHARED library. EXPORT_HEADER makes cpp_library run CMake's GenerateExportHeader for
# this target, producing greeter_export.h (defining the GREETER_EXPORT macro) in the build
# tree and putting its directory on Greeter's PUBLIC include path. Without it, MSVC would
# export no symbols, the import library would be empty, and GreeterApp would fail to link.
cpp_library(
    TARGET Greeter
    SHARED
    SOURCES
        src/greeter.cpp
    HEADERS
        greeter/greeter.h
    HEADER_DIR
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES
        PUBLIC
            include/
    CXX_STANDARD 17
    EXPORT_HEADER
)
