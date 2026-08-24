# Configure-mode regression test: the shipped placeholder translation unit resolves from any
# directory scope, not only the one that included Targets first.
#
# cpp_target.cmake guards its body with include_guard(GLOBAL), so the body runs in the first
# directory scope that includes Targets and nowhere else. Anything the body leaves in a
# directory-scoped variable is therefore absent from a sibling directory that includes
# Targets for itself -- which is what every example and most real projects do. A rule that
# resolved the placeholder through such a variable would fail configuration there with a
# path that had lost its root.
#
# This project deliberately does NOT include Targets: "first" includes it (and so runs the
# body), then "second" includes it again in a scope that inherits nothing from "first" and
# declares the library that needs the placeholder.
#
# A FATAL_ERROR in any assertion makes configuration exit non-zero and fails the CTest.

cmake_minimum_required(VERSION 3.20)
project(TestCppTargetDummySourceSiblingScope LANGUAGES CXX)

add_subdirectory(first)
add_subdirectory(second)
