# End-to-end downstream consumer of a Targets-built library installed via
# cpp_library(... INSTALL EXPORT ...) (issue #20).
#
# This project does NOT include Targets. It relies solely on the package config that
# cpp_library generated and installed: find_package(WidgetKit CONFIG REQUIRED) must locate
# <prefix>/lib/cmake/WidgetKit/WidgetKitConfig.cmake, and the imported target
# WidgetKit::Widget must carry the installed public headers (via $<INSTALL_INTERFACE:...>)
# and link cleanly. The install-export CI job installs the examples/install_export producer
# to a prefix, then configures/builds/runs this consumer against it.
cmake_minimum_required(VERSION 3.20)
project(ConsumeInstallExport LANGUAGES CXX)

# Pin the advertised version to lock in the generated version file: the producer installs a
# WidgetKitConfigVersion.cmake generated from project(WidgetKit VERSION 1.2.0), so requiring
# 1.2.0 must succeed.
find_package(WidgetKit 1.2.0 CONFIG REQUIRED)

add_executable(use_widget main.cpp)
target_link_libraries(use_widget PRIVATE WidgetKit::Widget)

message(STATUS "consume_install: found WidgetKit and linked WidgetKit::Widget")
