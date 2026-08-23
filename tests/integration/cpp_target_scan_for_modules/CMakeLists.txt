# Configure-mode test for C++20 module-scanning suppression.
#
# cpp_target defaults CXX_STANDARD to 23. Under CMP0155 NEW, CMake then dependency-scans every
# translation unit to discover module imports and order module compilation. Targets exposes no
# way to declare a module interface unit, so that scan can never find one, and cpp_target sets
# CXX_SCAN_FOR_MODULES OFF on every compiled target. This project reads the property back off a
# library and an executable.
#
# The 3.28 minimum is load-bearing: below it CMP0155 is OLD, CMake never scans, and the
# assertion would hold for the wrong reason. The C++ standard is asserted for the same reason --
# scanning applies only to C++20 and later.
#
# Three CTest entries configure this project, one per way of asking for scanning:
#   - default:        the property must read OFF.
#   - -DTARGETS_SCAN_FOR_MODULES=ON: the property must be left unset so CMake's own
#     CMP0155-governed default decides. Forcing it ON instead would be a hard error under a
#     generator that cannot scan.
#   - -DCMAKE_CXX_SCAN_FOR_MODULES=<v>: CMake initializes the property from that variable at
#     target creation, and the consumer's choice must survive.

cmake_minimum_required(VERSION 3.28)
project(TestCppTargetScanForModules LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../../cmake")
include(Targets)

cmake_policy(GET CMP0155 _cmp0155)
if(NOT _cmp0155 STREQUAL "NEW")
  message(FATAL_ERROR
    "CMP0155 is '${_cmp0155}', not NEW -- CMake would not scan whatever the property said, "
    "so this test would pass against unfixed code")
endif()

if(TARGETS_SCAN_FOR_MODULES)
  set(_expected "<unset>")
elseif(DEFINED CMAKE_CXX_SCAN_FOR_MODULES)
  set(_expected "${CMAKE_CXX_SCAN_FOR_MODULES}")
else()
  set(_expected "OFF")
endif()

# Real translation units in the build tree; SOURCE_DIR points there so source_group(TREE) is
# happy and both targets are compiled (non-INTERFACE) ones that carry the property.
set(_src "${CMAKE_CURRENT_BINARY_DIR}/scanlib.cpp")
file(WRITE "${_src}" "int scanlib_symbol() { return 0; }\n")
cpp_library(
  TARGET ScanLib
  SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  SOURCES "${_src}"
)

set(_main "${CMAKE_CURRENT_BINARY_DIR}/scanapp.cpp")
file(WRITE "${_main}" "int main() { return 0; }\n")
cpp_binary(
  TARGET ScanApp
  SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  SOURCES "${_main}"
)

foreach(_target ScanLib ScanApp)
  get_target_property(_std ${_target} CXX_STANDARD)
  get_target_property(_scan ${_target} CXX_SCAN_FOR_MODULES)
  if(_scan MATCHES "NOTFOUND$")
    set(_scan "<unset>")
  endif()
  message(STATUS "${_target} CXX_STANDARD=${_std} CXX_SCAN_FOR_MODULES=${_scan}")

  if(NOT _std GREATER_EQUAL 20)
    message(FATAL_ERROR
      "${_target} is C++${_std}; CMake does not scan below C++20, so this test would pass "
      "against unfixed code")
  endif()

  if(NOT "${_scan}" STREQUAL "${_expected}")
    message(FATAL_ERROR
      "${_target} CXX_SCAN_FOR_MODULES is '${_scan}', expected '${_expected}'")
  endif()
endforeach()

if(NOT _expected STREQUAL "OFF")
  # Halt before generation: scanning is live now, and a generator without C++20 module support
  # fails generation. That is the generator's limitation, not this scenario's subject. The
  # default scenario carries the shipped behavior through generation instead.
  message(FATAL_ERROR "SCAN_FOR_MODULES_OVERRIDE_OK")
endif()

message(STATUS "cpp_target module-scanning test passed")
