# compiler_cache.cmake
# Route C and C++ compiles through a compiler cache (ccache/sccache)

include_guard(GLOBAL)

# For the shared _targets_check_args() argument validator.
get_filename_component(_TARGETS_UTILS_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_UTILS_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/core/cpp_target.cmake")

# Drop the compiler-launcher cache entries an earlier configure of this build tree left
# behind. They survive a reconfigure on their own, so without this the tree goes on compiling
# through a launcher the current call has just declined to wire -- after PROGRAM was pointed
# at a binary that is not installed, say. TARGETS_COMPILER_CACHE is written only on the
# success path, so it identifies the entries as this rule's own and a launcher the project
# set by other means is left alone.
function(_targets_forget_compiler_cache)
  if(DEFINED CACHE{TARGETS_COMPILER_CACHE})
    unset(CMAKE_C_COMPILER_LAUNCHER CACHE)
    unset(CMAKE_CXX_COMPILER_LAUNCHER CACHE)
    unset(TARGETS_COMPILER_CACHE CACHE)
  endif()
endfunction()

# Route C and C++ compiles through a compiler cache.
#
# Finds a cache binary and points CMAKE_C_COMPILER_LAUNCHER and CMAKE_CXX_COMPILER_LAUNCHER
# at it, wrapped in `cmake -E env` so the cache configuration is recorded in the generated
# build rules instead of being read from whatever the developer happens to have exported.
# CMake initializes a target's launcher property when the target is created, so this must be
# called before the cpp_library()/cpp_binary()/cpp_test() calls it should apply to --
# normally from the top-level CMakeLists.
#
# Arguments:
#   PROGRAM: Name or absolute path of the cache binary (optional). When omitted, ccache is
#            searched for first and sccache second. sccache implements only part of the
#            CCACHE_* configuration this rule sets, and is warned about when selected.
#   BASE_DIR: Directory that ccache rewrites absolute paths relative to, via CCACHE_BASEDIR
#             (default: CMAKE_SOURCE_DIR). This is what lets two checkouts of the same
#             sources share cache entries. A relative path is resolved against
#             CMAKE_CURRENT_SOURCE_DIR, so pass an absolute one from anywhere but the
#             top-level CMakeLists. It is re-spelled the way the filesystem holds it, so the
#             wrong letter case is safe to pass; a directory the sources are not under is
#             warned about, because ccache then rewrites nothing and the two checkouts share
#             nothing.
#   REQUIRED: Fail configuration with a FATAL_ERROR when no cache binary is found (optional).
#             Without it a missing binary produces a STATUS message, the launchers are left
#             unset, and the build proceeds uncached.
#
# On success the launchers are set as FORCEd cache entries, so every directory processed
# after this call sees them and a later configure of the same build tree starts with them
# already in place, and in the calling scope as well. TARGETS_COMPILER_CACHE is set to the
# resolved binary.
#
# Nothing is set under a generator that ignores compiler launchers; a WARNING names the
# generator and TARGETS_COMPILER_CACHE is left undefined, so a consumer can test it to learn
# whether caching is really in effect. A call that declines to enable caching, for that
# reason or because no binary was found, also drops the cache entries an earlier configure of
# the same build tree got from this rule.
#
# Example:
#   targets_enable_compiler_cache(REQUIRED)
function(targets_enable_compiler_cache)
  set(options REQUIRED)
  set(one_value_args PROGRAM BASE_DIR)
  set(multi_value_args)

  cmake_parse_arguments(
    PARSE_ARGV 0
    args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Reject typo'd or misplaced arguments instead of silently ignoring them.
  _targets_check_args("targets_enable_compiler_cache"
    "${args_UNPARSED_ARGUMENTS}"
    "${args_KEYWORDS_MISSING_VALUES}"
    ${options} ${one_value_args} ${multi_value_args})

  if(args_PROGRAM)
    set(search_names "${args_PROGRAM}")
  else()
    set(search_names ccache sccache)
  endif()

  # find_program() memoizes into the cache entry it is handed, NOTFOUND included. Keying the
  # entry on the names being searched keeps a failed lookup from answering a later call that
  # asks for a different program.
  string(MAKE_C_IDENTIFIER "_targets_compiler_cache_${search_names}" found_var)
  find_program(${found_var} NAMES ${search_names}
    DOC "Compiler cache binary located by targets_enable_compiler_cache()")
  set(program "${${found_var}}")

  string(REPLACE ";" ", " searched "${search_names}")
  if(NOT program)
    if(args_REQUIRED)
      message(FATAL_ERROR
        "targets_enable_compiler_cache: REQUIRED, but no compiler cache was found on PATH "
        "(searched for: ${searched}).")
    endif()
    message(STATUS
      "targets_enable_compiler_cache: no compiler cache found (searched for: ${searched}); "
      "compiler launchers left unset")
    _targets_forget_compiler_cache()
    return()
  endif()

  # Only the Makefile generators and Ninja run a compiler launcher. Every other generator
  # accepts CMAKE_<LANG>_COMPILER_LAUNCHER and drops it: a Visual Studio build with the
  # launcher set finishes with every ccache statistic at zero, which is indistinguishable
  # from a working cache.
  if(NOT CMAKE_GENERATOR MATCHES "Makefiles|Ninja")
    message(WARNING
      "targets_enable_compiler_cache: the '${CMAKE_GENERATOR}' generator ignores compiler "
      "launchers, so ${program} would cache nothing while the build still reported success. "
      "Compiler launchers left unset; configure with Ninja or a Makefile generator to use "
      "the cache.")
    _targets_forget_compiler_cache()
    return()
  endif()

  if(args_BASE_DIR)
    set(base_dir "${args_BASE_DIR}")
  else()
    set(base_dir "${CMAKE_SOURCE_DIR}")
  endif()
  # ccache compares CCACHE_BASEDIR against each absolute path byte for byte, so a base
  # directory whose letter case differs from the on-disk path rewrites nothing on Windows,
  # where the path still resolves and nothing else complains. ABSOLUTE re-spells the part of
  # the path that exists the way the filesystem holds it, which is what makes a hand-written
  # BASE_DIR safe to pass.
  get_filename_component(base_dir "${base_dir}" ABSOLUTE)

  # A base directory the sources do not sit under is the other way to get a cache that never
  # hits, and ccache is silent about that too. The trailing separators keep a sibling whose
  # name merely starts the same -- /work/foo against sources in /work/foobar -- from passing
  # for an ancestor.
  string(REGEX REPLACE "/+$" "" base_dir_stem "${base_dir}")
  string(FIND "${CMAKE_SOURCE_DIR}/" "${base_dir_stem}/" base_dir_offset)
  if(NOT base_dir_offset EQUAL 0)
    message(WARNING
      "targets_enable_compiler_cache: BASE_DIR '${base_dir}' is not a prefix of the source "
      "tree '${CMAKE_SOURCE_DIR}'. ccache rewrites only paths under BASE_DIR, so cache "
      "entries will not be shared between checkouts.")
  endif()

  get_filename_component(program_name "${program}" NAME_WE)
  if(program_name MATCHES "^sccache")
    message(WARNING
      "targets_enable_compiler_cache: selected sccache (${program}), which does not "
      "implement CCACHE_BASEDIR. The launcher still carries the ccache settings for a later "
      "switch, but cross-checkout cache sharing is unverified with sccache; pass "
      "PROGRAM ccache to get the behavior this rule is built around.")
  endif()

  # Carrying the configuration in the build rules rather than the ambient environment is what
  # makes a fresh checkout cache correctly with no developer setup: an exported CCACHE_BASEDIR
  # is one global value, so a second worktree inherits the first one's. CCACHE_NOHASHDIR keeps
  # the compilation's working directory out of the hash -- ccache folds it in whenever debug
  # info is generated, because it is recorded there, and two checkouts never share one.
  set(launcher
    "${CMAKE_COMMAND}" -E env
    "CCACHE_BASEDIR=${base_dir}"
    "CCACHE_NOHASHDIR=1"
    "${program}")

  set(TARGETS_COMPILER_CACHE "${program}"
    CACHE FILEPATH "Compiler cache wired in by targets_enable_compiler_cache()" FORCE)
  set(CMAKE_C_COMPILER_LAUNCHER "${launcher}"
    CACHE STRING "C compiler launcher set by targets_enable_compiler_cache()" FORCE)
  set(CMAKE_CXX_COMPILER_LAUNCHER "${launcher}"
    CACHE STRING "C++ compiler launcher set by targets_enable_compiler_cache()" FORCE)

  # A normal variable of the same name in the calling scope -- from a toolchain file, say --
  # shadows the cache entry, so the calling scope is written directly as well.
  set(TARGETS_COMPILER_CACHE "${program}" PARENT_SCOPE)
  set(CMAKE_C_COMPILER_LAUNCHER "${launcher}" PARENT_SCOPE)
  set(CMAKE_CXX_COMPILER_LAUNCHER "${launcher}" PARENT_SCOPE)

  message(STATUS
    "targets_enable_compiler_cache: using ${program} (CCACHE_BASEDIR=${base_dir})")
endfunction()
