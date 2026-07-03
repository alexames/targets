# Example: Install / Export
# Demonstrates cpp_library(... INSTALL EXPORT ...) — making a Targets-built library
# installable and consumable via find_package downstream (issue #20).
#
# Building this example (as CI does) generates the install(TARGETS)/install(EXPORT) rules
# and validates them at generate time. The end-to-end round trip (install, then a separate
# find_package consumer) is exercised by tests/consume_install and the install-export CI
# job.

cmake_minimum_required(VERSION 3.20)
project(WidgetKit VERSION 1.2.0 LANGUAGES CXX)

# Include Targets
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(Targets)

# A normal library, plus INSTALL/EXPORT to ship it. INSTALL opts the target into standard,
# relocatable install + export rules; EXPORT names the export set. Because the project is
# WidgetKit, this makes find_package(WidgetKit CONFIG REQUIRED) yield WidgetKit::Widget
# downstream — the same namespaced name the target has in this build tree.
cpp_library(
    TARGET Widget
    SOURCES
        src/widget.cpp
    HEADERS
        widget/widget.h
    HEADER_DIR
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES
        PUBLIC
            include/
    CXX_STANDARD 17
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    INSTALL
    EXPORT WidgetKitTargets
)

message(STATUS "Example: install_export - Created installable/exportable target Widget")
