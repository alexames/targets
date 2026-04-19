# platform_parser.cmake
# Helpers for filtering argument lists by build platform.
# Used by cpp_target to support platform-conditional SOURCES, HEADERS,
# INCLUDES, DEFINITIONS, and DEPENDENCIES.

include_guard(GLOBAL)

# Detect the current build platform as a single uppercase token.
# One of: WINDOWS, ANDROID, EMSCRIPTEN, MACOS, LINUX
function(_targets_get_current_platform OUT_VAR)
  if(WIN32)
    set(${OUT_VAR} "WINDOWS" PARENT_SCOPE)
  elseif(ANDROID)
    set(${OUT_VAR} "ANDROID" PARENT_SCOPE)
  elseif(EMSCRIPTEN)
    set(${OUT_VAR} "EMSCRIPTEN" PARENT_SCOPE)
  elseif(APPLE)
    set(${OUT_VAR} "MACOS" PARENT_SCOPE)
  else()
    set(${OUT_VAR} "LINUX" PARENT_SCOPE)
  endif()
endfunction()

# Known platform sentinel tokens recognized by _targets_parse_platforms[_for].
set(_TARGETS_PLATFORM_KEYWORDS WINDOWS LINUX MACOS ANDROID EMSCRIPTEN DEFAULT)

# Filter a token list by platform. Pure function — takes the platform
# explicitly so it can be unit-tested for any target platform from any host.
#
# Token rules:
#   - Tokens appearing before any sentinel are unconditional (always kept).
#   - After a sentinel (WINDOWS, LINUX, MACOS, ANDROID, EMSCRIPTEN, DEFAULT),
#     tokens belong to that platform's bucket until the next sentinel.
#   - The output is: unconditional tokens + the tokens from the PLATFORM
#     bucket if PLATFORM was listed, otherwise the DEFAULT bucket if one
#     was provided, otherwise nothing.
#
# Usage:
#   _targets_parse_platforms_for(OUT_VAR "WINDOWS" <tokens...>)
function(_targets_parse_platforms_for OUT_VAR PLATFORM)
  set(_unconditional "")
  set(_current_section "")
  set(_listed_platforms "")

  foreach(_kw ${_TARGETS_PLATFORM_KEYWORDS})
    set(_section_${_kw} "")
  endforeach()

  foreach(_token IN LISTS ARGN)
    list(FIND _TARGETS_PLATFORM_KEYWORDS "${_token}" _idx)
    if(NOT _idx EQUAL -1)
      set(_current_section "${_token}")
      if(NOT "${_token}" IN_LIST _listed_platforms)
        list(APPEND _listed_platforms "${_token}")
      endif()
    else()
      if(_current_section STREQUAL "")
        list(APPEND _unconditional "${_token}")
      else()
        list(APPEND _section_${_current_section} "${_token}")
      endif()
    endif()
  endforeach()

  set(_result ${_unconditional})
  if("${PLATFORM}" IN_LIST _listed_platforms)
    list(APPEND _result ${_section_${PLATFORM}})
  elseif("DEFAULT" IN_LIST _listed_platforms)
    list(APPEND _result ${_section_DEFAULT})
  endif()

  set(${OUT_VAR} "${_result}" PARENT_SCOPE)
endfunction()

# Filter a token list by the current build platform. Convenience wrapper
# around _targets_parse_platforms_for.
function(_targets_parse_platforms OUT_VAR)
  _targets_get_current_platform(_current)
  _targets_parse_platforms_for(_result "${_current}" ${ARGN})
  set(${OUT_VAR} "${_result}" PARENT_SCOPE)
endfunction()
