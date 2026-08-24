# cpp_target.cmake
# Core target abstraction for Targets library
# Provides unified interface for creating C++ libraries and executables

include_guard(GLOBAL)

# Enable folder organization in IDEs
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Whether cpp_target injects MSVC edit-and-continue debug info (/ZI) into Debug builds.
# /ZI is a developer convenience that only applies to x86/x64 and must never reach
# Release, where it de-optimizes the build (see issue #5). It is gated to Debug via a
# generator expression and skipped entirely on ARM/ARM64. Set this to OFF to suppress
# /ZI in every configuration. A configured compiler launcher takes the decision out of this
# option's hands either way: Debug then gets the debug format a compile cache can serve.
option(TARGETS_MSVC_EDIT_AND_CONTINUE
  "Inject MSVC /ZI (edit-and-continue debug info) into Debug builds on x86/x64" ON)

# Whether cpp_target copies the runtime DLLs of an executable's shared-library dependencies
# next to the executable after it is built. On Windows a produced DLL must sit beside the
# consuming .exe (or be on PATH) or the process cannot start, which makes running/debugging a
# SHARED-linked executable from the build tree fail out of the box (see issue #21). This uses
# $<TARGET_RUNTIME_DLLS> (CMake >= 3.21) and is a no-op on platforms without DLLs (Linux/macOS
# rely on RPATH instead) and when an executable has no shared dependencies. Set this to OFF to
# suppress the staging step entirely.
option(TARGETS_STAGE_RUNTIME_DLLS
  "Copy dependency runtime DLLs next to each executable after build (Windows)" ON)

# Whether module-import scanning is left to CMake. Targets provides no way to declare a
# module interface unit, so the per-translation-unit scan that CMP0155 turns on for C++20 and
# later can never find one, and no compile cache can serve its cost; cpp_target therefore sets
# CXX_SCAN_FOR_MODULES OFF. Set this to ON to restore CMake's default project-wide.
option(TARGETS_SCAN_FOR_MODULES
  "Leave module-import scanning to CMake's default instead of disabling it per target" OFF)

# Whether every call that spells its file lists the deprecated way is reported, rather than
# only the first of a configure. A project with hundreds of targets buries every other
# message under the per-call form, so the first call alone is reported by default; the
# per-call form is what names the CMakeLists lines left to migrate. CMake's own
# -Wno-deprecated silences the report and -Werror=deprecated promotes it to a configure
# error whichever way this option is set.
option(TARGETS_WARN_ALL_LEGACY_SOURCES
  "Report every use of the deprecated bare SOURCES / HEADERS spelling, not just the first" OFF)

# Include dependency management
get_filename_component(_TARGETS_MODULE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_TARGETS_ROOT_DIR "${_TARGETS_MODULE_DIR}" PATH)
include("${_TARGETS_ROOT_DIR}/dependencies/import_dependencies.cmake")
include("${_TARGETS_MODULE_DIR}/platform_parser.cmake")
include("${_TARGETS_MODULE_DIR}/install_export.cmake")
include("${_TARGETS_MODULE_DIR}/toolchain_hygiene.cmake")

# Reject arguments that cmake_parse_arguments could not assign to a known keyword.
#
# RULE names the calling rule for diagnostics. UNPARSED is the rule's
# <prefix>_UNPARSED_ARGUMENTS, MISSING is its <prefix>_KEYWORDS_MISSING_VALUES, and
# ARGN carries the rule's full set of valid keywords (printed as a hint). Values are
# passed positionally rather than under keywords so a stray token cannot collide with
# this helper's own argument names. An unrecognized argument is a hard error: it is
# almost always a misspelled keyword or a value that lost its keyword, either of which
# silently changes the target if left unchecked (see issue #4). A keyword given no
# values is only a warning.
function(_targets_check_args RULE UNPARSED MISSING)
  if(NOT "${UNPARSED}" STREQUAL "")
    string(REPLACE ";" ", " _unparsed "${UNPARSED}")
    set(_hint "")
    if(NOT "${ARGN}" STREQUAL "")
      string(REPLACE ";" ", " _valid_keywords "${ARGN}")
      set(_hint " Valid keywords are: ${_valid_keywords}.")
    endif()
    message(FATAL_ERROR
      "${RULE}: unrecognized argument(s): ${_unparsed}. This is usually a "
      "misspelled keyword or a value missing its PUBLIC/PRIVATE keyword.${_hint}")
  endif()
  if(NOT "${MISSING}" STREQUAL "")
    string(REPLACE ";" ", " _missing "${MISSING}")
    message(WARNING "${RULE}: keyword(s) given with no values: ${_missing}.")
  endif()
endfunction()

# Split a visibility-taking argument's values into PUBLIC_<VAR_NAME> and
# PRIVATE_<VAR_NAME> (set in the caller's scope). RULE names the calling rule for
# diagnostics. Every value must appear under a PUBLIC or PRIVATE keyword: entries
# placed before the first access keyword would otherwise be dropped silently, so
# they are rejected with a hard error (see issue #4).
function(_targets_parse_access_specifier RULE VAR_NAME)
  set(options)
  set(one_value_args)
  set(multi_value_args PUBLIC PRIVATE)
  cmake_parse_arguments(
    PARSE_ARGV 2
    ACCESS_SPECIFIER
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")
  if(NOT "${ACCESS_SPECIFIER_UNPARSED_ARGUMENTS}" STREQUAL "")
    message(FATAL_ERROR
      "${RULE}: ${VAR_NAME} values must be grouped under PUBLIC or PRIVATE. These "
      "entries precede the first access keyword and would be dropped: "
      "${ACCESS_SPECIFIER_UNPARSED_ARGUMENTS}.")
  endif()
  set(PUBLIC_${VAR_NAME} ${ACCESS_SPECIFIER_PUBLIC} PARENT_SCOPE)
  set(PRIVATE_${VAR_NAME} ${ACCESS_SPECIFIER_PRIVATE} PARENT_SCOPE)
endfunction()

# Split a file-list argument that accepts either the visibility-grouped spelling or the
# deprecated bare list into PUBLIC_<VAR_NAME>, PRIVATE_<VAR_NAME> and <VAR_NAME>_SPELLING
# (set in the caller's scope). RULE names the calling rule for diagnostics, VAR_NAME the
# argument, and the entries to split are the trailing arguments. <VAR_NAME>_SPELLING reads
# "grouped", "legacy" or "none", so the caller can report the deprecated spellings.
#
# The first entry alone decides. Opening with PUBLIC or PRIVATE selects the grouped
# spelling, handed to _targets_parse_access_specifier; any other opening entry is the bare
# list, every entry of which is private.
#
# A list that opens bare and names PUBLIC or PRIVATE later is rejected here. Read as a bare
# list the keyword becomes a file name; read as a grouped one the entries ahead of it are
# exactly what _targets_parse_access_specifier exists to reject -- but it never sees them,
# because cmake_parse_arguments leaves nothing unparsed once the first entry is a keyword.
# This check is the only thing standing between that shape and a silent misreading.
function(_targets_parse_source_visibility RULE VAR_NAME)
  set(entries ${ARGN})
  list(LENGTH entries entry_count)
  if(entry_count EQUAL 0)
    set(PUBLIC_${VAR_NAME} "" PARENT_SCOPE)
    set(PRIVATE_${VAR_NAME} "" PARENT_SCOPE)
    set(${VAR_NAME}_SPELLING "none" PARENT_SCOPE)
    return()
  endif()

  list(GET entries 0 first_entry)
  if(first_entry STREQUAL "PUBLIC" OR first_entry STREQUAL "PRIVATE")
    _targets_parse_access_specifier("${RULE}" ${VAR_NAME} ${entries})
    set(PUBLIC_${VAR_NAME} "${PUBLIC_${VAR_NAME}}" PARENT_SCOPE)
    set(PRIVATE_${VAR_NAME} "${PRIVATE_${VAR_NAME}}" PARENT_SCOPE)
    set(${VAR_NAME}_SPELLING "grouped" PARENT_SCOPE)
    return()
  endif()

  if("PUBLIC" IN_LIST entries OR "PRIVATE" IN_LIST entries)
    message(FATAL_ERROR
      "${RULE}: ${VAR_NAME} mixes the two spellings. It opens with the bare entry "
      "'${first_entry}' and names a PUBLIC or PRIVATE keyword later, so the entries ahead "
      "of that keyword would be dropped. Write either every entry under PUBLIC/PRIVATE "
      "groups -- PUBLIC resolves against HEADER_DIR, PRIVATE against SOURCE_DIR -- or none "
      "of them (the deprecated bare list, which is entirely private).")
  endif()

  set(PUBLIC_${VAR_NAME} "" PARENT_SCOPE)
  set(PRIVATE_${VAR_NAME} "${entries}" PARENT_SCOPE)
  set(${VAR_NAME}_SPELLING "legacy" PARENT_SCOPE)
endfunction()

# Report in OUT_VAR whether any of the trailing entries is a translation unit -- a file the
# compiler is asked to build -- rather than a header. This is what separates a compiled
# library from a header-only INTERFACE one, so an entry whose type cannot be read off its
# name counts as a translation unit: judging it the other way would turn a compiled library
# into an INTERFACE one, silently changing what linking to it means.
#
# The header list must never gain a module interface unit (.ixx, .cppm): those compile,
# and adding one would turn a library that has only module sources into an INTERFACE.
function(_targets_any_translation_unit OUT_VAR)
  set(header_extensions h hh hpp hxx h++ hp inl inc ipp tcc tpp)
  foreach(entry IN LISTS ARGN)
    get_filename_component(extension "${entry}" LAST_EXT)
    string(TOLOWER "${extension}" extension)
    string(REGEX REPLACE "^\\." "" extension "${extension}")
    if(NOT extension IN_LIST header_extensions)
      set(${OUT_VAR} TRUE PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(${OUT_VAR} FALSE PARENT_SCOPE)
endfunction()

# Report that TARGET_NAME spells its file lists the deprecated way. SPELLING names what the
# call wrote, for the diagnostic.
#
# Only the first such call of a configure is reported unless TARGETS_WARN_ALL_LEGACY_SOURCES
# is set. A global property carries the run-once state, which lives for one configure and so
# re-arms on the next.
function(_targets_warn_legacy_source_spelling TARGET_NAME SPELLING)
  if(NOT TARGETS_WARN_ALL_LEGACY_SOURCES)
    get_property(announced GLOBAL PROPERTY _TARGETS_LEGACY_SOURCES_ANNOUNCED)
    if(announced)
      return()
    endif()
    set_property(GLOBAL PROPERTY _TARGETS_LEGACY_SOURCES_ANNOUNCED ON)
    set(remaining_hint "")
    string(APPEND remaining_hint
      " Configure with -DTARGETS_WARN_ALL_LEGACY_SOURCES=ON to name every other call that"
      " still does.")
  else()
    set(remaining_hint "")
  endif()
  message(DEPRECATION
    "cpp_target: '${TARGET_NAME}' declares its files with ${SPELLING}. Group them under "
    "SOURCES instead: PUBLIC entries resolve against HEADER_DIR and PRIVATE entries against "
    "SOURCE_DIR, which is what HEADERS and a bare SOURCES list already mean. The old "
    "spelling still works and is scheduled for removal.${remaining_hint}")
endfunction()

# Partition absolute file paths into those located under ROOT and those outside it.
# source_group(TREE ROOT FILES ...) is a hard configure error for any file that is not
# under ROOT: this happens for generated files in an out-of-source build tree, or for
# "../shared" sources (see issue #6). Callers keep such files out of the TREE grouping
# and place them in a flat group instead. The two lists are returned in the caller's
# UNDER_VAR and OUTSIDE_VAR; the file paths to classify are passed as trailing arguments.
function(_targets_partition_files_by_root ROOT UNDER_VAR OUTSIDE_VAR)
  get_filename_component(root_abs "${ROOT}" ABSOLUTE)
  set(under "")
  set(outside "")
  foreach(file IN LISTS ARGN)
    get_filename_component(file_abs "${file}" ABSOLUTE)
    file(RELATIVE_PATH rel "${root_abs}" "${file_abs}")
    # A file on a different drive keeps its absolute path; one above ROOT starts with
    # "..". Either way it is not under ROOT and must skip source_group(TREE ...).
    if(IS_ABSOLUTE "${rel}" OR rel STREQUAL ".." OR rel MATCHES "^\\.\\./")
      list(APPEND outside "${file}")
    else()
      list(APPEND under "${file}")
    endif()
  endforeach()
  set(${UNDER_VAR} "${under}" PARENT_SCOPE)
  set(${OUTSIDE_VAR} "${outside}" PARENT_SCOPE)
endfunction()

# Resolve the shipped placeholder translation unit (dummy.cpp) into OUT_VAR (set in the
# caller's scope). A source-less, non-header-only target -- e.g. a codegen STATIC library
# whose translation units are produced by a custom command -- still needs at least one
# real TU for some toolchains (notably MSVC) to emit an archive; dummy.cpp is that TU.
#
# The file ships beside the CMake modules in both the source tree (cmake/dummy.cpp) and
# the installed package (share/targets/cmake/dummy.cpp), so the same
# ${_TARGETS_ROOT_DIR}-relative path resolves in dev builds and for find_package
# consumers. A missing file means a broken checkout or a package that failed to ship it,
# which would otherwise surface as a confusing "No SOURCES given to target" or an empty
# archive, so it is a hard error rather than a silent skip (see issue #7).
function(_targets_dummy_source OUT_VAR)
  set(dummy_file "${_TARGETS_ROOT_DIR}/dummy.cpp")
  if(NOT EXISTS "${dummy_file}")
    message(FATAL_ERROR
      "Targets: placeholder translation unit not found at '${dummy_file}'. The "
      "Targets package is incomplete -- dummy.cpp must ship beside the CMake modules "
      "(see issue #7).")
  endif()
  set(${OUT_VAR} "${dummy_file}" PARENT_SCOPE)
endfunction()

# Stage a target's runtime DATA next to its built artifact so the program (or test) finds it
# at run time. DATA entries are runtime dependencies -- data files a binary or test reads
# while running -- mirroring Bazel's `data` attribute. Each entry is resolved relative to
# SOURCE_DIR (absolute paths are kept as-is); a regular file is copied with copy_if_different
# and a directory is mirrored recursively into the output dir. The copy runs POST_BUILD (like
# the runtime-DLL staging of issue #21) so a rebuilt data file is refreshed. TARGET is the
# target to stage for, SOURCE_DIR resolves relative entries, and the entries are the trailing
# arguments; an empty entry list is a no-op.
function(_targets_stage_data TARGET SOURCE_DIR)
  set(files "")
  set(dirs "")
  foreach(entry IN LISTS ARGN)
    if(IS_ABSOLUTE "${entry}")
      set(entry_abs "${entry}")
    else()
      set(entry_abs "${SOURCE_DIR}/${entry}")
    endif()
    # A directory is classified only when it exists at configure time; a not-yet-generated
    # entry is treated as a file and copied at build time (when it should exist).
    if(IS_DIRECTORY "${entry_abs}")
      list(APPEND dirs "${entry_abs}")
    else()
      list(APPEND files "${entry_abs}")
    endif()
  endforeach()

  # Copy all plain files in one command (copy_if_different accepts many sources + a
  # destination directory), then mirror each directory into a same-named subdirectory.
  if(files)
    add_custom_command(TARGET ${TARGET} POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${files} "$<TARGET_FILE_DIR:${TARGET}>"
      VERBATIM)
  endif()
  foreach(dir IN LISTS dirs)
    get_filename_component(dir_name "${dir}" NAME)
    add_custom_command(TARGET ${TARGET} POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${dir}" "$<TARGET_FILE_DIR:${TARGET}>/${dir_name}"
      VERBATIM)
  endforeach()
endfunction()

# Give TARGET a Debug debug-information format that a compile cache can serve.
#
# TARGET names an existing compiled target; the caller must have established that the
# compiler is MSVC.
#
# /Zi and /ZI put debug info in a .pdb shared by every translation unit of the target, which
# a cache hit cannot reproduce: ccache answers unsupported_compiler_option and compiles the
# unit uncached, so a Debug build hits nothing however the cache is configured. /Z7 carries
# the same information in the object file, where a cached object brings it along, and,
# unlike /ZI, carries no x86/x64 restriction.
#
# Only Debug is touched. Other configurations keep CMake's default format, so RelWithDebInfo
# still gets its .pdb -- a Debug-only generator expression on the property would leave every
# other configuration with no debug information at all. RelWithDebInfo therefore keeps /Zi
# and keeps missing the cache.
function(_targets_msvc_cacheable_debug_info TARGET)
  # CMake turns MSVC_DEBUG_INFORMATION_FORMAT into a flag from 3.25 on, and only under
  # CMP0141 NEW; otherwise the format is spelled in CMAKE_CXX_FLAGS_DEBUG, out of the
  # property's reach. A project that puts a debug-info flag there itself is in that same
  # position whatever the policy says, so both signals have to agree before the property is
  # trusted. Every way of getting this wrong lands on the flag route, where an appended /Z7
  # still overrides whatever came earlier.
  set(format_in_flags TRUE)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.25)
    cmake_policy(GET CMP0141 debug_format_policy)
    if(debug_format_policy STREQUAL "NEW"
       AND NOT CMAKE_CXX_FLAGS_DEBUG MATCHES "(^| )[/-]Z[iI]( |$)")
      set(format_in_flags FALSE)
    endif()
  endif()

  # A project that names its own format has decided this question already, cacheable or not.
  if(NOT format_in_flags AND DEFINED CMAKE_MSVC_DEBUG_INFORMATION_FORMAT)
    return()
  endif()

  if(format_in_flags)
    # The last debug-info flag on the command line is the one cl.exe honors, and the one
    # ccache judges the compile by.
    target_compile_options(${TARGET} PRIVATE "$<$<CONFIG:Debug>:/Z7>")
  else()
    set_target_properties(${TARGET} PROPERTIES MSVC_DEBUG_INFORMATION_FORMAT
      "$<IF:$<CONFIG:Debug>,Embedded,$<$<CONFIG:RelWithDebInfo>:ProgramDatabase>>")
  endif()

  get_property(announced GLOBAL PROPERTY _TARGETS_MSVC_DEBUG_FORMAT_ANNOUNCED)
  if(announced)
    return()
  endif()
  set_property(GLOBAL PROPERTY _TARGETS_MSVC_DEBUG_FORMAT_ANNOUNCED ON)
  message(STATUS
    "cpp_target: a compiler launcher is configured, so Debug builds get embedded debug info "
    "(/Z7) in place of edit-and-continue (/ZI), which no compile cache accepts.")
  if(format_in_flags)
    message(STATUS
      "cpp_target: CMAKE_CXX_FLAGS_DEBUG spells the debug format here, so /Z7 is appended to "
      "override it and cl.exe reports D9025 once per translation unit. A project requiring "
      "CMake 3.25 or newer, or setting CMP0141 to NEW, keeps the format out of the flags.")
  endif()
endfunction()

# Apply the settings every compiled target this package creates carries, whatever rule created
# it. TARGET names an existing compiled target -- a static, shared, module or object library,
# or an executable.
#
# Every rule that creates a compiled target calls this; the common_target_defaults_coverage
# test fails a rule that does not.
#
# Call this after the target's own COPTS: the Debug debug-info format it can inject must be the
# last debug-info flag on the command line to take effect.
#
# The module-scanning suppression below matters even to a rule that never asks for C++20: a
# project-wide CMAKE_CXX_STANDARD of 20 or later reaches every target, and so does a
# dependency on a header-only cpp_library, whose INTERFACE cxx_std_23 compile feature raises
# the standard its consumers are compiled at above their own CXX_STANDARD.
#
# FATAL_ERROR if TARGET names no target, or names a type with no private compile step (an
# INTERFACE or a custom target). An ALIAS and an IMPORTED target report the underlying type,
# so the guard passes them through -- pass a target this package created.
function(_targets_apply_common_target_defaults TARGET)
  if(NOT TARGET ${TARGET})
    message(FATAL_ERROR
      "_targets_apply_common_target_defaults: '${TARGET}' is not an existing target.")
  endif()
  get_target_property(target_type ${TARGET} TYPE)
  if(NOT target_type MATCHES
     "^(STATIC_LIBRARY|SHARED_LIBRARY|MODULE_LIBRARY|OBJECT_LIBRARY|EXECUTABLE)$")
    message(FATAL_ERROR
      "_targets_apply_common_target_defaults: '${TARGET}' is a ${target_type}, which has no "
      "private compile step; these settings apply only to compiled targets.")
  endif()

  # C++20 and later make CMake scan every TU for imports, to order module compilation.
  # Targets has no way to declare a module interface unit, so the scan cannot find one:
  # it costs a preprocessing pass per TU, produces an empty modmap, and no compile cache
  # can serve it. A target that genuinely needs modules re-enables scanning with
  # set_target_properties(<t> PROPERTIES CXX_SCAN_FOR_MODULES ON). CMake initializes the
  # property from CMAKE_CXX_SCAN_FOR_MODULES at target creation, so a consumer who sets that
  # variable keeps their choice.
  if(NOT TARGETS_SCAN_FOR_MODULES AND NOT DEFINED CMAKE_CXX_SCAN_FOR_MODULES)
    set_target_properties(${TARGET} PROPERTIES CXX_SCAN_FOR_MODULES OFF)
  endif()

  # MSVC compiler and linker flags. Each flag is scoped to the configurations and
  # architectures where it is valid; injecting them unconditionally de-optimized
  # Release and broke ARM64 (see issue #5).
  if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
    # UTF-8 source and execution character sets: safe in every configuration and
    # on every architecture.
    target_compile_options(${TARGET} PRIVATE /utf-8)

    # Edit-and-continue debug info (/ZI) is a Debug-only developer convenience. It
    # de-optimizes Release builds and is only valid on x86/x64, so it is gated to
    # Debug via a generator expression, skipped on ARM/ARM64, and can be disabled
    # entirely with -DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF. A configured compiler launcher
    # outranks the option, whose ON cannot be told apart from its default anyway: /ZI is
    # what keeps a Debug translation unit out of a compile cache.
    if(CMAKE_CXX_COMPILER_LAUNCHER)
      _targets_msvc_cacheable_debug_info(${TARGET})
    elseif(TARGETS_MSVC_EDIT_AND_CONTINUE
           AND NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "^(ARM|ARM64|ARM64EC)$")
      target_compile_options(${TARGET} PRIVATE "$<$<CONFIG:Debug>:/ZI>")
    endif()

    # /SAFESEH:NO only affects the x86 (32-bit) linker: it is a silent no-op on x64,
    # invalid on ARM64, and ignored on static libraries (which are archived, not
    # linked). Restrict it to x86 linked images: executables, shared and module libraries.
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "X86"
       AND target_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
      target_link_options(${TARGET} PRIVATE /SAFESEH:NO)
    endif()
  endif()
endfunction()

# Main cpp_target function
function(cpp_target)
  # Parse function arguments
  set(options
    STATIC
    SHARED
    UNITY_BUILD
    INSTALL                   # Generate install + export rules (issue #20)
    EXPORT_HEADER             # Generate a GenerateExportHeader export header (issue #21)
    WINDOWS_EXPORT_ALL_SYMBOLS  # Auto-export all symbols of a SHARED library (issue #21)
    WERROR                    # Opt-in: treat warnings as errors (issue #23)
    LTO)                      # Opt-in: link-time (interprocedural) optimization (issue #23)
  set(one_value_args
    TYPE                      # LIBRARY or EXECUTABLE (required)
    TARGET                    # Target name (required)
    EXPORT                    # Export-set name for install/export (implies INSTALL)
    FOLDER                    # IDE folder path
    SOURCE_DIR                # Source directory (default: CMAKE_CURRENT_LIST_DIR)
    HEADER_DIR                # Header directory (default: CMAKE_CURRENT_LIST_DIR/Include)
    WORKING_DIRECTORY         # Debugger working directory (executables only)
    COMMAND_ARGUMENTS         # Debugger command arguments (executables only)
    CXX_STANDARD              # C++ standard (default: 23)
    VERSION                   # Semantic version (e.g., "1.2.3")
    SOVERSION                 # ABI version
    UNITY_BUILD_BATCH_SIZE    # Files per unity chunk (default: 16)
    NAMESPACE_ROOT            # Root for namespace generation (default: PROJECT_SOURCE_DIR/Source)
    WARNINGS                  # Opt-in warning level: off | default | strict (issue #23)
  )
  set(multi_value_args
    SOURCES                   # Files (with PUBLIC/PRIVATE), or a deprecated bare list
    HEADERS                   # Deprecated spelling of SOURCES PUBLIC
    INCLUDES                  # Include directories (with PUBLIC/PRIVATE)
    DEFINITIONS               # Compiler definitions (with PUBLIC/PRIVATE)
    DEPENDENCIES              # Link libraries (with PUBLIC/PRIVATE)
    COPTS                     # Per-target compile options (with PUBLIC/PRIVATE) (issue #27)
    LINKOPTS                  # Per-target link options (with PUBLIC/PRIVATE) (issue #27)
    DATA                      # Runtime data files staged next to the artifact (issue #27)
    PROPERTIES                # Additional CMake properties
    PRECOMPILE_HEADERS        # Headers to precompile
    SANITIZERS                # Opt-in sanitizers, e.g. address undefined (issue #23)
  )
  cmake_parse_arguments(
    PARSE_ARGV 0
    args
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Reject typo'd or misplaced arguments instead of silently ignoring them.
  _targets_check_args("cpp_target"
    "${args_UNPARSED_ARGUMENTS}"
    "${args_KEYWORDS_MISSING_VALUES}"
    ${options} ${one_value_args} ${multi_value_args})

  # Validate required arguments
  if(NOT args_TYPE)
    message(FATAL_ERROR "cpp_target: TYPE argument is required (LIBRARY or EXECUTABLE)")
  endif()
  if(NOT args_TARGET)
    message(FATAL_ERROR "cpp_target: TARGET argument is required")
  endif()

  # Validate the opt-in warning level up front (issue #23), for every target type, so a
  # misspelled level fails fast with the same message on compiled and header-only targets.
  _targets_validate_warnings("cpp_target" "${args_WARNINGS}")

  # EXPORT_HEADER and WINDOWS_EXPORT_ALL_SYMBOLS are two mutually exclusive strategies for
  # exporting a SHARED library's symbols: the former annotates the public API with generated
  # __declspec/visibility macros, the latter auto-exports every symbol. Combining them is
  # contradictory (and on MSVC provokes duplicate-export warnings), so reject it up front
  # (see issue #21).
  if(args_EXPORT_HEADER AND args_WINDOWS_EXPORT_ALL_SYMBOLS)
    message(FATAL_ERROR
      "cpp_target: EXPORT_HEADER and WINDOWS_EXPORT_ALL_SYMBOLS are mutually exclusive "
      "symbol-export strategies; choose one.")
  endif()

  # Decide whether install/export rules are requested. EXPORT implies INSTALL: naming an
  # export set only makes sense if the target is installed. When INSTALL is given for a
  # library without an explicit EXPORT, default the export set to <Project>Targets so a
  # downstream find_package(<Project>) still yields the namespaced target. Executables
  # marked INSTALL without EXPORT are installed to the runtime dir but not exported.
  set(_do_install FALSE)
  set(_export_set "")
  if(args_INSTALL OR args_EXPORT)
    set(_do_install TRUE)
    if(args_EXPORT)
      set(_export_set "${args_EXPORT}")
    elseif(args_TYPE STREQUAL "LIBRARY")
      set(_export_set "${PROJECT_NAME}Targets")
    endif()
  endif()

  # Set defaults
  if(NOT args_SOURCE_DIR)
    set(args_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}")
  endif()
  if(NOT IS_ABSOLUTE "${args_SOURCE_DIR}")
    set(args_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/${args_SOURCE_DIR}")
  endif()

  if(NOT args_HEADER_DIR)
    set(args_HEADER_DIR "${CMAKE_CURRENT_LIST_DIR}/Include")
  endif()
  if(NOT IS_ABSOLUTE "${args_HEADER_DIR}")
    set(args_HEADER_DIR "${CMAKE_CURRENT_LIST_DIR}/${args_HEADER_DIR}")
  endif()

  if(NOT args_CXX_STANDARD)
    set(args_CXX_STANDARD 23)
  endif()

  if(NOT args_NAMESPACE_ROOT)
    set(args_NAMESPACE_ROOT "${PROJECT_SOURCE_DIR}/Source")
  endif()

  # Whether HEADERS was given any values. _targets_parse_platforms below defines the
  # variable whether or not the caller passed the keyword, so this has to be read first.
  set(headers_given FALSE)
  if(DEFINED args_HEADERS)
    set(headers_given TRUE)
  endif()

  # Split the file lists by visibility. PUBLIC entries are the target's interface and
  # resolve against HEADER_DIR; PRIVATE entries are its implementation and resolve against
  # SOURCE_DIR. SOURCES accepts either the grouped spelling or the deprecated bare list
  # (entirely private); HEADERS is the deprecated spelling of the public group.
  _targets_parse_source_visibility("cpp_target" SOURCES ${args_SOURCES})

  # One call cannot use both spellings for its public files: the grouped SOURCES and HEADERS
  # describe the same list, and nothing in the call says which the author meant to keep.
  if(SOURCES_SPELLING STREQUAL "grouped" AND headers_given)
    message(FATAL_ERROR
      "cpp_target: '${args_TARGET}' groups SOURCES under PUBLIC/PRIVATE and also passes "
      "HEADERS, which are two spellings of the same public file list. Move the HEADERS "
      "entries under SOURCES PUBLIC -- they resolve against HEADER_DIR either way.")
  endif()

  set(legacy_spelling "")
  if(SOURCES_SPELLING STREQUAL "legacy")
    set(legacy_spelling "a bare SOURCES list")
  endif()
  if(headers_given)
    if(legacy_spelling)
      string(APPEND legacy_spelling " and HEADERS")
    else()
      set(legacy_spelling "HEADERS")
    endif()
  endif()
  if(legacy_spelling)
    _targets_warn_legacy_source_spelling("${args_TARGET}" "${legacy_spelling}")
  endif()

  # Filter platform-conditional entries out of list arguments. The visibility split runs
  # first, so in the grouped spelling a platform sentinel acts inside one visibility group,
  # exactly as it does for DEPENDENCIES.
  _targets_parse_platforms(PUBLIC_SOURCES ${PUBLIC_SOURCES})
  _targets_parse_platforms(PRIVATE_SOURCES ${PRIVATE_SOURCES})
  _targets_parse_platforms(args_HEADERS ${args_HEADERS})
  list(APPEND PUBLIC_SOURCES ${args_HEADERS})
  # DATA carries no PUBLIC/PRIVATE (a runtime file has no visibility), so it is platform-
  # filtered directly here; COPTS/LINKOPTS carry visibility and are parsed in the compiled
  # branch alongside DEFINITIONS (issue #27).
  _targets_parse_platforms(args_DATA ${args_DATA})

  # Gather the private files
  unset(private_files)
  foreach(entry ${PRIVATE_SOURCES})
    if(IS_ABSOLUTE "${entry}")
      list(APPEND private_files "${entry}")
    else()
      list(APPEND private_files "${args_SOURCE_DIR}/${entry}")
    endif()
  endforeach()

  # Create source groups for IDE organization. source_group(TREE ...) hard-errors on any
  # file outside the tree root, so out-of-root files (generated files in an out-of-source
  # build tree, or ../shared sources) are collected into a flat "Generated Files" group
  # instead of aborting configuration (see issue #6). The dummy.cpp placeholder for
  # file-less targets is injected later, at target creation, so that the header-only
  # INTERFACE decision is made on the user's own files alone (see issue #7).
  if(private_files)
    _targets_partition_files_by_root(
      "${args_SOURCE_DIR}" in_tree_sources out_of_tree_sources ${private_files})
    if(in_tree_sources)
      source_group(TREE "${args_SOURCE_DIR}" PREFIX "Source Files" FILES ${in_tree_sources})
    endif()
    if(out_of_tree_sources)
      source_group("Generated Files" FILES ${out_of_tree_sources})
    endif()
  endif()

  # Gather the public files
  unset(public_files)
  foreach(entry ${PUBLIC_SOURCES})
    if(IS_ABSOLUTE "${entry}")
      list(APPEND public_files "${entry}")
    else()
      list(APPEND public_files "${args_HEADER_DIR}/${entry}")
    endif()
  endforeach()

  # Create public source groups. Out-of-root public files get the same flat "Generated
  # Files" grouping as private ones so a generated header never aborts configuration (see
  # issue #6).
  if(public_files)
    _targets_partition_files_by_root(
      "${args_HEADER_DIR}" in_tree_headers out_of_tree_headers ${public_files})
    if(in_tree_headers)
      source_group(TREE "${args_HEADER_DIR}" PREFIX "Header Files" FILES ${in_tree_headers})
    endif()
    if(out_of_tree_headers)
      source_group("Generated Files" FILES ${out_of_tree_headers})
    endif()
  endif()

  # Create the target
  if(args_TYPE STREQUAL "LIBRARY")
    # STATIC and SHARED select the library's linkage and are mutually exclusive: passing
    # both is contradictory. Reject it with a clear error instead of silently letting
    # SHARED win, mirroring the EXECUTABLE validation below (see issue #14). A library
    # defaults to STATIC when neither flag is given.
    if(args_STATIC AND args_SHARED)
      message(FATAL_ERROR
        "cpp_target: STATIC and SHARED cannot both be specified for a library; choose "
        "one (a library defaults to STATIC when neither is given).")
    endif()
    if(args_SHARED)
      set(library_type SHARED)
    else()
      set(library_type STATIC)
    endif()

    # A library that exposes public files and has no private translation unit to compile is
    # header-only, and must never receive the dummy.cpp placeholder, which would flip it to
    # STATIC and change its usage-requirement semantics (see issue #7). A private header does
    # not make a library compiled -- there is nothing to compile -- so a header-only library
    # keeps its detail headers under PRIVATE without changing kind.
    _targets_any_translation_unit(has_translation_unit ${private_files})
    if(public_files AND NOT has_translation_unit)
      add_library(${args_TARGET} INTERFACE)
      set(_is_interface_library TRUE)
    else()
      # A library with no files at all (e.g. a codegen STATIC target whose translation units
      # are produced by a custom command) still needs one real TU to archive; inject the
      # shipped placeholder for it. Header-only libraries never reach this branch, so they
      # never gain the dummy TU.
      if(NOT private_files)
        _targets_dummy_source(dummy_file)
        list(APPEND private_files "${dummy_file}")
        source_group("CMake Rules" FILES "${dummy_file}")
      endif()
      add_library(${args_TARGET} ${library_type} ${private_files} ${public_files})
      set(_is_interface_library FALSE)
    endif()
  elseif(args_TYPE STREQUAL "EXECUTABLE")
    if(args_STATIC OR args_SHARED)
      message(FATAL_ERROR "cpp_target: Executables cannot be marked STATIC or SHARED")
    endif()
    # Symbol-export controls describe a library's ABI; an executable exports nothing, so
    # reject them rather than silently ignoring a misplaced flag (see issue #21).
    if(args_EXPORT_HEADER OR args_WINDOWS_EXPORT_ALL_SYMBOLS)
      message(FATAL_ERROR
        "cpp_target: EXPORT_HEADER and WINDOWS_EXPORT_ALL_SYMBOLS apply only to libraries, "
        "not executables.")
    endif()
    # An executable with no private files still needs a translation unit to configure; give
    # it the same placeholder fallback as file-less libraries (see issue #7).
    if(NOT private_files)
      _targets_dummy_source(dummy_file)
      list(APPEND private_files "${dummy_file}")
      source_group("CMake Rules" FILES "${dummy_file}")
    endif()
    add_executable(${args_TARGET} ${private_files} ${public_files})
    set(_is_interface_library FALSE)
  else()
    message(FATAL_ERROR "cpp_target: Invalid TYPE '${args_TYPE}'. Must be LIBRARY or EXECUTABLE")
  endif()

  # Create namespace alias
  if(EXISTS "${args_NAMESPACE_ROOT}")
    file(RELATIVE_PATH relative_path_from_root "${args_NAMESPACE_ROOT}" "${CMAKE_CURRENT_LIST_DIR}")
  else()
    set(relative_path_from_root "")
  endif()

  # Derive the namespace root from the *enclosing* project (PROJECT_NAME), not the
  # top-level project (CMAKE_PROJECT_NAME). Keying off CMAKE_PROJECT_NAME made a library's
  # alias change when it was embedded via add_subdirectory/FetchContent -- e.g. a target in
  # project(Sub)'s Source/Core resolved to Sub::Core::Lib standalone but Super::Core::Lib
  # under project(Super) -- breaking every reference to the standalone alias (see issue #8).
  set(default_folder "${PROJECT_NAME}")
  if(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set(default_folder "${default_folder}/${relative_path_from_root}")
  endif()

  string(REPLACE "/" "::" namespace "${default_folder}")
  set(alias "${namespace}::${args_TARGET}")

  if(args_TYPE STREQUAL "EXECUTABLE")
    add_executable(${alias} ALIAS ${args_TARGET})
  else()
    add_library(${alias} ALIAS ${args_TARGET})
  endif()

  # Configure interface libraries differently
  if(_is_interface_library)
    # A header-only INTERFACE library has no private compile step and produces no built
    # artifact, so several arguments have no meaning on it. Everything valid on an INTERFACE
    # target is applied: the PUBLIC/INTERFACE usage-requirements below, plus FOLDER and user
    # PROPERTIES (shared with compiled targets, further down). Everything that only applies
    # to a compiled target is reported with a warning rather than being dropped silently
    # (see issue #13). PRIVATE usage-requirements are still parsed here so the warning can
    # name exactly what was ignored.
    _targets_parse_access_specifier("cpp_target" INCLUDES ${args_INCLUDES})
    _targets_parse_platforms(PUBLIC_INCLUDES ${PUBLIC_INCLUDES})
    _targets_parse_platforms(PRIVATE_INCLUDES ${PRIVATE_INCLUDES})
    # When the target is exported its public include dirs must be wrapped in BUILD/INSTALL
    # interface generator expressions (a plain source path breaks install(EXPORT)); the
    # wrapped directories are also the header-install sources. Otherwise the include dirs
    # stay plain, preserving the non-install behavior exactly.
    if(_do_install)
      _targets_wrap_public_includes(
        _public_include_entries _header_install_dirs "${args_HEADER_DIR}" ${PUBLIC_INCLUDES})
      target_include_directories(${args_TARGET} INTERFACE ${_public_include_entries})
    else()
      target_include_directories(${args_TARGET} INTERFACE
        ${PUBLIC_INCLUDES}
        "$<BUILD_INTERFACE:${args_HEADER_DIR}>"
      )
    endif()

    _targets_parse_access_specifier("cpp_target" DEFINITIONS ${args_DEFINITIONS})
    _targets_parse_platforms(PUBLIC_DEFINITIONS ${PUBLIC_DEFINITIONS})
    _targets_parse_platforms(PRIVATE_DEFINITIONS ${PRIVATE_DEFINITIONS})
    target_compile_definitions(${args_TARGET} INTERFACE ${PUBLIC_DEFINITIONS})

    _targets_parse_access_specifier("cpp_target" DEPENDENCIES ${args_DEPENDENCIES})
    _targets_parse_platforms(PUBLIC_DEPENDENCIES ${PUBLIC_DEPENDENCIES})
    _targets_parse_platforms(PRIVATE_DEPENDENCIES ${PRIVATE_DEPENDENCIES})
    import_dependencies(${args_TARGET} "${PUBLIC_DEPENDENCIES}")
    target_link_libraries(${args_TARGET} INTERFACE ${PUBLIC_DEPENDENCIES})

    target_compile_features(${args_TARGET} INTERFACE cxx_std_${args_CXX_STANDARD})

    # Warn about arguments that have no meaning on a header-only INTERFACE library instead
    # of dropping them silently (see issue #13). PRIVATE usage-requirements need the private
    # compile step this target does not have; VERSION/SOVERSION describe a built artifact it
    # does not produce; PRECOMPILE_HEADERS and UNITY_BUILD are compilation settings with
    # nothing to compile. They are collected and reported once, naming the target and each
    # ignored argument.
    set(ignored_args "")
    if(PRIVATE_INCLUDES)
      list(APPEND ignored_args "INCLUDES (PRIVATE)")
    endif()
    if(PRIVATE_DEFINITIONS)
      list(APPEND ignored_args "DEFINITIONS (PRIVATE)")
    endif()
    if(PRIVATE_DEPENDENCIES)
      list(APPEND ignored_args "DEPENDENCIES (PRIVATE)")
    endif()
    # COPTS/LINKOPTS are compile/link settings and DATA stages files next to a built
    # artifact; a header-only INTERFACE library has neither a compile step nor an artifact,
    # so all three are reported as ignored rather than applied (issue #27, consistent with #13).
    if(args_COPTS)
      list(APPEND ignored_args "COPTS")
    endif()
    if(args_LINKOPTS)
      list(APPEND ignored_args "LINKOPTS")
    endif()
    if(args_DATA)
      list(APPEND ignored_args "DATA")
    endif()
    if(args_VERSION)
      list(APPEND ignored_args "VERSION")
    endif()
    if(args_SOVERSION)
      list(APPEND ignored_args "SOVERSION")
    endif()
    if(args_PRECOMPILE_HEADERS)
      list(APPEND ignored_args "PRECOMPILE_HEADERS")
    endif()
    if(args_UNITY_BUILD)
      list(APPEND ignored_args "UNITY_BUILD")
    endif()
    if(args_EXPORT_HEADER)
      list(APPEND ignored_args "EXPORT_HEADER")
    endif()
    if(args_WINDOWS_EXPORT_ALL_SYMBOLS)
      list(APPEND ignored_args "WINDOWS_EXPORT_ALL_SYMBOLS")
    endif()
    # The opt-in toolchain hygiene knobs (issue #23) are compile/link settings with nothing
    # to compile on a header-only INTERFACE library. WARNINGS is only reported when the
    # caller passed the keyword (DEFINED), so an omitted level is never flagged.
    if(DEFINED args_WARNINGS)
      list(APPEND ignored_args "WARNINGS")
    endif()
    if(args_WERROR)
      list(APPEND ignored_args "WERROR")
    endif()
    if(args_SANITIZERS)
      list(APPEND ignored_args "SANITIZERS")
    endif()
    if(args_LTO)
      list(APPEND ignored_args "LTO")
    endif()
    if(ignored_args)
      string(REPLACE ";" ", " ignored_args "${ignored_args}")
      message(WARNING
        "cpp_target: '${args_TARGET}' is a header-only INTERFACE library (public files, no "
        "private translation unit); the following argument(s) only apply to a compiled "
        "target and were ignored: ${ignored_args}. An INTERFACE library has no private "
        "compile step and produces no built artifact.")
    endif()
  else()
    # Regular libraries and executables

    # Add include directories
    _targets_parse_access_specifier("cpp_target" INCLUDES ${args_INCLUDES})
    _targets_parse_platforms(PUBLIC_INCLUDES ${PUBLIC_INCLUDES})
    _targets_parse_platforms(PRIVATE_INCLUDES ${PRIVATE_INCLUDES})

    # Generate an export header for a SHARED library so its public symbols are actually
    # exported (see issue #21). On Windows/MSVC a SHARED library with no __declspec(dllexport)
    # produces an empty import library and consumers fail to link; GenerateExportHeader writes
    # a <target>_export.h defining a <TARGET>_EXPORT macro that expands to the right
    # dllexport/dllimport (and, on GCC/Clang, visibility) attribute for the current build.
    # CXX_VISIBILITY_PRESET hidden + VISIBILITY_INLINES_HIDDEN give non-Windows toolchains the
    # same "nothing exported unless annotated" behavior MSVC has by default, so the macro is
    # meaningful everywhere. The generated header's directory is added to the target's PUBLIC
    # includes; when the target is also installed/exported it flows through the same
    # BUILD/INSTALL_INTERFACE wrapping and header install as the hand-written headers below, so
    # downstream consumers still find <target>_export.h.
    if(args_EXPORT_HEADER AND args_TYPE STREQUAL "LIBRARY")
      include(GenerateExportHeader)
      set(_export_header_dir "${CMAKE_CURRENT_BINARY_DIR}/${args_TARGET}.export")
      # Create the directory now so it exists at configure time: the install(DIRECTORY ...)
      # rule for exported headers skips directories that are not present when it is generated.
      file(MAKE_DIRECTORY "${_export_header_dir}")
      string(TOLOWER "${args_TARGET}" _export_header_base)
      generate_export_header(${args_TARGET}
        EXPORT_FILE_NAME "${_export_header_dir}/${_export_header_base}_export.h")
      set_target_properties(${args_TARGET} PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON)
      list(APPEND PUBLIC_INCLUDES "${_export_header_dir}")
    endif()

    # Auto-export every symbol of a SHARED library on Windows as an alternative to annotating
    # the public API with export macros (see issue #21). CMake fills the module-definition
    # table from the object files' symbols; it is a no-op for STATIC libraries and on
    # non-Windows toolchains.
    if(args_WINDOWS_EXPORT_ALL_SYMBOLS AND args_TYPE STREQUAL "LIBRARY")
      set_target_properties(${args_TARGET} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
    endif()

    # When the target is exported its public include dirs must be wrapped in BUILD/INSTALL
    # interface generator expressions (a plain source path breaks install(EXPORT)); the
    # wrapped directories are also the header-install sources. Otherwise the include dirs
    # stay plain, preserving the non-install behavior exactly.
    if(_do_install)
      _targets_wrap_public_includes(
        _public_include_entries _header_install_dirs "${args_HEADER_DIR}" ${PUBLIC_INCLUDES})
      target_include_directories(
        ${args_TARGET}
        PUBLIC
          ${_public_include_entries}
        PRIVATE
          ${PRIVATE_INCLUDES}
          "${args_SOURCE_DIR}"
      )
    else()
      target_include_directories(
        ${args_TARGET}
        PUBLIC
          ${PUBLIC_INCLUDES}
          "$<BUILD_INTERFACE:${args_HEADER_DIR}>"
        PRIVATE
          ${PRIVATE_INCLUDES}
          "${args_SOURCE_DIR}"
      )
    endif()

    set_target_properties(
      ${args_TARGET}
      PROPERTIES
        CXX_STANDARD ${args_CXX_STANDARD}
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )

    # Add compiler definitions
    _targets_parse_access_specifier("cpp_target" DEFINITIONS ${args_DEFINITIONS})
    _targets_parse_platforms(PUBLIC_DEFINITIONS ${PUBLIC_DEFINITIONS})
    _targets_parse_platforms(PRIVATE_DEFINITIONS ${PRIVATE_DEFINITIONS})
    target_compile_definitions(
      ${args_TARGET}
      PUBLIC ${PUBLIC_DEFINITIONS}
      PRIVATE ${PRIVATE_DEFINITIONS}
    )

    # Per-target compile / link options (Bazel copts / linkopts, issue #27). Grouped under
    # PUBLIC/PRIVATE and platform-filtered exactly like DEFINITIONS, then translated to the
    # native target_compile_options / target_link_options. PUBLIC entries become usage
    # requirements (also applied to consumers via INTERFACE_COMPILE_OPTIONS/LINK_OPTIONS);
    # PRIVATE entries apply only to this target's own build. Each visibility is applied only
    # when non-empty so an empty section never reaches the underlying command.
    _targets_parse_access_specifier("cpp_target" COPTS ${args_COPTS})
    _targets_parse_platforms(PUBLIC_COPTS ${PUBLIC_COPTS})
    _targets_parse_platforms(PRIVATE_COPTS ${PRIVATE_COPTS})
    if(PUBLIC_COPTS)
      target_compile_options(${args_TARGET} PUBLIC ${PUBLIC_COPTS})
    endif()
    if(PRIVATE_COPTS)
      target_compile_options(${args_TARGET} PRIVATE ${PRIVATE_COPTS})
    endif()

    _targets_parse_access_specifier("cpp_target" LINKOPTS ${args_LINKOPTS})
    _targets_parse_platforms(PUBLIC_LINKOPTS ${PUBLIC_LINKOPTS})
    _targets_parse_platforms(PRIVATE_LINKOPTS ${PRIVATE_LINKOPTS})
    if(PUBLIC_LINKOPTS)
      target_link_options(${args_TARGET} PUBLIC ${PUBLIC_LINKOPTS})
    endif()
    if(PRIVATE_LINKOPTS)
      target_link_options(${args_TARGET} PRIVATE ${PRIVATE_LINKOPTS})
    endif()

    # Applied after this target's own COPTS: the Debug debug-info format injected here has to
    # be the last debug-info flag on the command line.
    _targets_apply_common_target_defaults(${args_TARGET})

    # Add dependencies
    _targets_parse_access_specifier("cpp_target" DEPENDENCIES ${args_DEPENDENCIES})
    _targets_parse_platforms(PUBLIC_DEPENDENCIES ${PUBLIC_DEPENDENCIES})
    _targets_parse_platforms(PRIVATE_DEPENDENCIES ${PRIVATE_DEPENDENCIES})
    import_dependencies(${args_TARGET} "${PUBLIC_DEPENDENCIES}")
    import_dependencies(${args_TARGET} "${PRIVATE_DEPENDENCIES}")
    target_link_libraries(
      ${args_TARGET}
      PUBLIC ${PUBLIC_DEPENDENCIES}
      PRIVATE ${PRIVATE_DEPENDENCIES}
    )

    # Set version properties for libraries
    if(args_TYPE STREQUAL "LIBRARY" AND args_VERSION)
      set_target_properties(${args_TARGET} PROPERTIES VERSION ${args_VERSION})
      if(args_SOVERSION)
        set_target_properties(${args_TARGET} PROPERTIES SOVERSION ${args_SOVERSION})
      endif()
    endif()

    # Set working directory for executables (debugger)
    if(args_TYPE STREQUAL "EXECUTABLE" AND args_WORKING_DIRECTORY)
      set_target_properties(
        ${args_TARGET}
        PROPERTIES
          VS_DEBUGGER_WORKING_DIRECTORY "${args_WORKING_DIRECTORY}"
      )
    endif()

    # Set debugger command arguments for executables
    if(args_TYPE STREQUAL "EXECUTABLE" AND args_COMMAND_ARGUMENTS)
      set_target_properties(
        ${args_TARGET}
        PROPERTIES
          VS_DEBUGGER_COMMAND_ARGUMENTS "${args_COMMAND_ARGUMENTS}"
      )
    endif()

    # Stage runtime DLLs next to the executable so it launches from the build tree (see issue
    # #21). On Windows the DLL of a SHARED dependency must sit beside the .exe (or be on PATH),
    # or the process cannot start. $<TARGET_RUNTIME_DLLS> resolves the transitive set of
    # dependency DLLs for us; the copy runs after every build so newly rebuilt DLLs are
    # refreshed. It requires CMake >= 3.21 (this project's floor is 3.20), so it is version
    # guarded and simply omitted on older CMake. The command name is chosen at generate time:
    # with no runtime DLLs (e.g. only STATIC deps, or a non-DLL platform where the list is
    # always empty) it degrades to `cmake -E true`, avoiding a `copy_if_different` invoked with
    # no source files -- which is an error, not a no-op. COMMAND_EXPAND_LISTS splits the
    # semicolon-separated DLL list into individual arguments.
    if(args_TYPE STREQUAL "EXECUTABLE"
       AND TARGETS_STAGE_RUNTIME_DLLS
       AND NOT CMAKE_VERSION VERSION_LESS "3.21")
      add_custom_command(TARGET ${args_TARGET} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E
          "$<IF:$<BOOL:$<TARGET_RUNTIME_DLLS:${args_TARGET}>>,copy_if_different,true>"
          "$<TARGET_RUNTIME_DLLS:${args_TARGET}>"
          "$<TARGET_FILE_DIR:${args_TARGET}>"
        COMMAND_EXPAND_LISTS
        VERBATIM)
    endif()

    # Stage runtime DATA next to the built artifact (Bazel data, issue #27). The files a
    # program or test reads at run time are copied into the target's output directory after
    # every build, so it finds them via a relative path when launched from the build tree --
    # mirroring the runtime-DLL staging above. DATA was already platform-filtered near the top;
    # a header-only INTERFACE library never reaches this branch, so it warns instead (above).
    if(args_DATA)
      _targets_stage_data(${args_TARGET} "${args_SOURCE_DIR}" ${args_DATA})
    endif()

    # Configure precompiled headers
    if(args_PRECOMPILE_HEADERS)
      target_precompile_headers(${args_TARGET} PRIVATE ${args_PRECOMPILE_HEADERS})
    endif()

    # Configure unity builds
    if(args_UNITY_BUILD)
      set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD ON)
      if(args_UNITY_BUILD_BATCH_SIZE)
        set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD_BATCH_SIZE ${args_UNITY_BUILD_BATCH_SIZE})
      else()
        set_target_properties(${args_TARGET} PROPERTIES UNITY_BUILD_BATCH_SIZE 16)
      endif()
    endif()

    # Apply the opt-in toolchain hygiene knobs last, so they layer on top of the target's
    # own compile/link options (issue #23). Each is a no-op unless the caller opted in, so
    # this changes nothing for existing targets. Only the keywords the caller actually gave
    # are forwarded: passing an empty WARNINGS/SANITIZERS would trip CMP0174's dev warning
    # in the common opt-out case, so they are appended only when present.
    set(_hygiene_args TARGET ${args_TARGET})
    if(NOT "${args_WARNINGS}" STREQUAL "")
      list(APPEND _hygiene_args WARNINGS "${args_WARNINGS}")
    endif()
    if(args_SANITIZERS)
      list(APPEND _hygiene_args SANITIZERS ${args_SANITIZERS})
    endif()
    if(args_WERROR)
      list(APPEND _hygiene_args WERROR)
    endif()
    if(args_LTO)
      list(APPEND _hygiene_args LTO)
    endif()
    _targets_apply_toolchain_hygiene(${_hygiene_args})
  endif()

  # Set IDE folder. FOLDER is valid on every target type -- executables, compiled
  # libraries, and INTERFACE (header-only) libraries (CMake >= 3.19) -- so it is applied
  # here for all of them rather than only compiled targets, which used to silently drop it
  # for header-only libraries (see issue #13). When the caller does not pass an explicit
  # FOLDER, derive it from the enclosing project (see issue #8). Presence is tested with
  # DEFINED rather than truthiness so an explicit but falsey-looking folder name (e.g. "0"
  # or "OFF") is honored instead of falling through to the derived default (see issue #15).
  if(DEFINED args_FOLDER)
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${args_FOLDER}")
  elseif(relative_path_from_root AND NOT relative_path_from_root MATCHES "^\\.\\.")
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}/${relative_path_from_root}")
  else()
    set_target_properties(${args_TARGET} PROPERTIES FOLDER "${PROJECT_NAME}")
  endif()

  # Apply additional user-supplied properties last, so they can override anything set
  # above. Valid on INTERFACE targets too (CMake >= 3.19), so this is shared across every
  # target type; the header-only path used to drop it silently (see issue #13).
  if(args_PROPERTIES)
    set_target_properties(${args_TARGET} PROPERTIES ${args_PROPERTIES})
  endif()

  # Generate install/export rules when requested (issue #20). The public-include wrapping
  # above already made the target export-safe and collected its header directories; this
  # installs the artifact and headers and, when an export set is named, adds the target to
  # it and emits the package config so downstream find_package(<Project>) resolves the
  # namespaced target. The namespace matches the build-tree alias derived above.
  if(_do_install)
    _targets_install_target(
      TARGET ${args_TARGET}
      EXPORT "${_export_set}"
      NAMESPACE "${namespace}"
      HEADER_DIRS ${_header_install_dirs}
    )
  endif()
endfunction()
