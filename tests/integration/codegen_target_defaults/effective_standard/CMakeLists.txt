# Build-mode fixture: a header-only cpp_library dependency really does raise a codegen
# target into module-scanning range.
#
# The configure-mode scenarios beside this one assert CXX_SCAN_FOR_MODULES is OFF on a
# codegen target that depends on a header-only cpp_library. That assertion is only worth
# something if such a target is in scanning range to begin with, and no property can show it:
# the standard a target is compiled at is the highest any of its compile features requires,
# raised at generate time, while CXX_STANDARD keeps reading whatever the rule set. So this
# fixture compiles, and lets the compiler report the standard it was actually given.
#
# embed_binary is the codegen rule used because it needs no external tool: it writes real C++
# sources itself, so the target can be built on a machine with neither flatc nor protoc.
#
# Nothing here sets CMAKE_CXX_STANDARD. The only thing asking for C++20 or later is the
# header-only library's INTERFACE compile feature.

cmake_minimum_required(VERSION 3.28)
project(TestCodegenEffectiveStandard LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../../cmake")
include(Targets)

if(DEFINED CMAKE_CXX_STANDARD)
  message(FATAL_ERROR
    "CMAKE_CXX_STANDARD is set to '${CMAKE_CXX_STANDARD}' -- the dependency would no longer "
    "be the only thing raising the standard, which is the whole subject here")
endif()

# Declared by hand rather than by a cpp_* rule: no rule here produces a target that
# propagates a compile feature, and the subject is what an arbitrary dependency does.
add_library(StandardCarrier INTERFACE)
target_compile_features(StandardCarrier INTERFACE cxx_std_23)

set(_payload "${CMAKE_CURRENT_BINARY_DIR}/payload.bin")
file(WRITE "${_payload}" "codegen-effective-standard-payload")
embed_binary(
  TARGET EmbeddedLib
  FILES "${_payload}"
  NAMESPACE test::embedded
)

target_link_libraries(EmbeddedLib PUBLIC StandardCarrier)

# The probe fails to compile unless the dependency raised this target to C++20 or later.
# MSVC reports the standard it was given in _MSVC_LANG; __cplusplus stays at 199711L there
# without /Zc:__cplusplus, which no rule here passes.
set(_probe "${CMAKE_CURRENT_BINARY_DIR}/standard_probe.cpp")
file(WRITE "${_probe}" "\
#if defined(_MSVC_LANG)
#  define TARGETS_TEST_LANG _MSVC_LANG
#else
#  define TARGETS_TEST_LANG __cplusplus
#endif
static_assert(TARGETS_TEST_LANG >= 202002L,
    \"the dependency did not raise this target to C++20 or later, \"
    \"so it is not in module-scanning range and the scanning assertions prove nothing\");
int standard_probe_symbol() { return 0; }
")
target_sources(EmbeddedLib PRIVATE "${_probe}")

get_target_property(_standard EmbeddedLib CXX_STANDARD)
if(_standard MATCHES "NOTFOUND$")
  set(_standard "<unset>")
endif()
get_target_property(_scan EmbeddedLib CXX_SCAN_FOR_MODULES)
if(_scan MATCHES "NOTFOUND$")
  set(_scan "<unset>")
endif()
message(STATUS "EmbeddedLib CXX_STANDARD=${_standard} CXX_SCAN_FOR_MODULES=${_scan}")

if(NOT "${_scan}" STREQUAL "OFF")
  message(FATAL_ERROR
    "EmbeddedLib CXX_SCAN_FOR_MODULES is '${_scan}', expected 'OFF' -- embed_binary creates "
    "its target without the settings every compiled target carries")
endif()
