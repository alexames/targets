# Unit tests for _targets_parse_platforms_for and _targets_get_current_platform.
# Run via: cmake -P test_parse_platforms.cmake

cmake_minimum_required(VERSION 3.20)

include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/core/platform_parser.cmake")

set(_failures 0)

# assert_equal(<test-name> <expected-list> <actual-list>)
# Both list arguments are passed as semicolon-joined strings.
function(assert_equal name expected actual)
  if(NOT "${expected}" STREQUAL "${actual}")
    message(SEND_ERROR "FAIL [${name}]\n  expected: [${expected}]\n  actual:   [${actual}]")
    math(EXPR _new "${_failures} + 1")
    set(_failures ${_new} PARENT_SCOPE)
  else()
    message(STATUS "PASS [${name}]")
  endif()
endfunction()

# --- _targets_get_current_platform -----------------------------------------

_targets_get_current_platform(_detected)
if(NOT _detected MATCHES "^(WINDOWS|LINUX|MACOS|ANDROID|EMSCRIPTEN)$")
  message(SEND_ERROR "FAIL [get_current_platform]: unexpected value '${_detected}'")
  math(EXPR _failures "${_failures} + 1")
else()
  message(STATUS "PASS [get_current_platform] -> ${_detected}")
endif()

# --- _targets_parse_platforms_for ------------------------------------------

# 1. Empty input
_targets_parse_platforms_for(out "WINDOWS")
assert_equal("empty" "" "${out}")

# 2. Only unconditional tokens
_targets_parse_platforms_for(out "WINDOWS" a.cpp b.cpp c.cpp)
assert_equal("all_unconditional" "a.cpp;b.cpp;c.cpp" "${out}")

# 3. Platform-only, matching platform
_targets_parse_platforms_for(out "WINDOWS" WINDOWS win.cpp)
assert_equal("only_matching_platform" "win.cpp" "${out}")

# 4. Platform-only, non-matching platform, no DEFAULT
_targets_parse_platforms_for(out "LINUX" WINDOWS win.cpp)
assert_equal("only_nonmatching_no_default" "" "${out}")

# 5. Platform-only, non-matching, with DEFAULT
_targets_parse_platforms_for(out "LINUX" WINDOWS win.cpp DEFAULT stub.cpp)
assert_equal("fallback_to_default" "stub.cpp" "${out}")

# 6. Matching platform wins over DEFAULT
_targets_parse_platforms_for(out "WINDOWS" WINDOWS win.cpp DEFAULT stub.cpp)
assert_equal("platform_beats_default" "win.cpp" "${out}")

# 7. Unconditional + matching platform
_targets_parse_platforms_for(out "EMSCRIPTEN"
  common.cpp
  WINDOWS win.cpp
  EMSCRIPTEN web.cpp
  DEFAULT stub.cpp)
assert_equal("unconditional_plus_match"
  "common.cpp;web.cpp"
  "${out}")

# 8. Unconditional + no match, no DEFAULT
_targets_parse_platforms_for(out "MACOS"
  common.cpp
  WINDOWS win.cpp
  EMSCRIPTEN web.cpp)
assert_equal("unconditional_plus_nomatch_no_default"
  "common.cpp"
  "${out}")

# 9. Unconditional + no match + DEFAULT
_targets_parse_platforms_for(out "MACOS"
  common1.cpp
  common2.cpp
  WINDOWS win.cpp
  DEFAULT stub1.cpp stub2.cpp)
assert_equal("unconditional_plus_default"
  "common1.cpp;common2.cpp;stub1.cpp;stub2.cpp"
  "${out}")

# 10. Multiple platforms, pick the right one
_targets_parse_platforms_for(out "ANDROID"
  a.cpp
  WINDOWS win.cpp
  LINUX linux.cpp
  MACOS mac.cpp
  ANDROID android1.cpp android2.cpp
  EMSCRIPTEN web.cpp
  DEFAULT stub.cpp)
assert_equal("pick_android"
  "a.cpp;android1.cpp;android2.cpp"
  "${out}")

# 11. Works with non-file tokens too (deps, defines, include dirs)
_targets_parse_platforms_for(out "WINDOWS"
  core_lib
  WINDOWS win_lib
  LINUX linux_lib)
assert_equal("dep_tokens" "core_lib;win_lib" "${out}")

# 12. DEFAULT bucket followed by platform bucket (order independence of sections)
_targets_parse_platforms_for(out "LINUX"
  common.cpp
  DEFAULT stub.cpp
  WINDOWS win.cpp)
assert_equal("default_before_platform_fallback"
  "common.cpp;stub.cpp"
  "${out}")

_targets_parse_platforms_for(out "WINDOWS"
  common.cpp
  DEFAULT stub.cpp
  WINDOWS win.cpp)
assert_equal("default_before_platform_match"
  "common.cpp;win.cpp"
  "${out}")

# 13. All five platforms recognized
foreach(_p WINDOWS LINUX MACOS ANDROID EMSCRIPTEN)
  _targets_parse_platforms_for(out "${_p}"
    base
    WINDOWS w
    LINUX l
    MACOS m
    ANDROID a
    EMSCRIPTEN e)
  string(TOLOWER "${_p}" _lower)
  string(SUBSTRING "${_lower}" 0 1 _expected_letter)
  assert_equal("platform_${_p}" "base;${_expected_letter}" "${out}")
endforeach()

# 14. Repeated platform sentinels accumulate into the same bucket
_targets_parse_platforms_for(out "WINDOWS"
  WINDOWS a.cpp
  LINUX other.cpp
  WINDOWS b.cpp)
assert_equal("repeated_platform_accumulates" "a.cpp;b.cpp" "${out}")

# --- summary ---------------------------------------------------------------

if(_failures GREATER 0)
  message(FATAL_ERROR "${_failures} test(s) failed")
endif()
message(STATUS "All parse_platforms tests passed.")
