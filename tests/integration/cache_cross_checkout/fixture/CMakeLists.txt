# The project copied into each of the two checkouts the cross-checkout test builds. Kept to
# one translation unit: the test counts hits and misses, and every extra unit is another
# number to reason about.
#
# Driven with -DTARGETS_CMAKE_DIR (directory holding Targets.cmake) and -DSHARED_INCLUDE_DIR
# (include root outside both checkouts). Both are required.

cmake_minimum_required(VERSION 3.20)
project(TargetsCacheCrossCheckout LANGUAGES CXX)

if(NOT DEFINED TARGETS_CMAKE_DIR)
  message(FATAL_ERROR "cache_cross_checkout fixture: -DTARGETS_CMAKE_DIR is required")
endif()
if(NOT DEFINED SHARED_INCLUDE_DIR)
  message(FATAL_ERROR "cache_cross_checkout fixture: -DSHARED_INCLUDE_DIR is required")
endif()

list(APPEND CMAKE_MODULE_PATH "${TARGETS_CMAKE_DIR}")
include(Targets)

# REQUIRED, so a cache binary that stopped being findable between the driver's search and
# this configure fails loudly instead of producing a build that reports success and shares
# nothing.
targets_enable_compiler_cache(REQUIRED)

# SHARED_INCLUDE_DIR names a directory outside both checkouts, standing in for the vcpkg tree
# a real project compiles against. ccache rewrites only the paths under CCACHE_BASEDIR, which
# is one checkout's root: an include root outside both is spelled identically on both command
# lines, while one living inside a checkout is rewritten for that checkout and left absolute
# for the other, which costs the second compile its direct-mode hit.
cpp_library(
  TARGET cache_fixture
  SOURCES
    "cached.cpp"
  INCLUDES
    PRIVATE
      "${SHARED_INCLUDE_DIR}")
