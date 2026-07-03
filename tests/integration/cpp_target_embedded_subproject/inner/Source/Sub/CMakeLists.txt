# A second target in the inner project, in a *different* subdirectory (Source/Sub). It is
# referenced by InnerLib as "Inner::Sub::HelperLib"; auto-import must map that label to
# this directory and add_subdirectory it. Auto-import matching keys off the enclosing
# project name (Inner) and resolves the subdirectory against the enclosing project's
# source root (inner/Source) -- both must be per-project, not the top-level Outer (issue
# #8). A source-less STATIC library (dummy.cpp placeholder TU) keeps the fixture minimal.

cpp_library(
  TARGET HelperLib
)
