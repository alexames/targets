# Defines a target under the inner project's Source/Core directory. With the namespace
# root defaulting to ${PROJECT_SOURCE_DIR}/Source (the inner project), the alias and IDE
# folder must be derived as Inner::Core::InnerLib and "Inner/Core" -- keyed off the inner
# PROJECT_NAME, never the outer CMAKE_PROJECT_NAME ("Outer").
#
# A source-less STATIC library (it picks up the shipped dummy.cpp placeholder TU) keeps
# the fixture free of any real translation unit while still exercising the non-INTERFACE
# alias + FOLDER path.
#
# It also depends on Inner::Sub::HelperLib, which is defined in a sibling subdirectory and
# must be auto-imported. Auto-import both matches on the enclosing project name (Inner) and
# resolves the target's subdirectory against the enclosing project's source root
# (inner/Source/Sub). Before the fix, the label root (Inner) never matched the top-level
# CMAKE_PROJECT_NAME (Outer), so the dependency was silently skipped; and even a match
# would have resolved against the frozen top-level source root (see issue #8).

cpp_library(
  TARGET InnerLib
  DEPENDENCIES
    PUBLIC Inner::Sub::HelperLib
)

# (0) The dependency must have been auto-imported from the enclosing project.
if(NOT TARGET Inner::Sub::HelperLib)
  message(FATAL_ERROR
    "embedded subproject: dependency Inner::Sub::HelperLib was not auto-imported; the "
    "auto-import matched/resolved against the wrong project (issue #8)")
endif()

# (1) The alias must come from the inner project.
if(NOT TARGET Inner::Core::InnerLib)
  message(FATAL_ERROR
    "embedded subproject: expected alias Inner::Core::InnerLib was not created; the "
    "namespace was derived from the wrong project (issue #8)")
endif()

# (2) The alias must NOT come from the outer top-level project. Before the fix this is
# exactly the alias that would have been produced (CMAKE_PROJECT_NAME == Outer).
if(TARGET Outer::Core::InnerLib)
  message(FATAL_ERROR
    "embedded subproject: alias was derived from the top-level project name "
    "(Outer::Core::InnerLib) instead of the enclosing project (issue #8)")
endif()

# (3) The IDE folder must likewise be rooted at the inner project name.
get_target_property(_folder InnerLib FOLDER)
if(NOT _folder STREQUAL "Inner/Core")
  message(FATAL_ERROR
    "embedded subproject: expected FOLDER 'Inner/Core', got '${_folder}' -- folder was "
    "derived from the wrong project name (issue #8)")
endif()
