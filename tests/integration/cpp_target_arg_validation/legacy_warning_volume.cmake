# Count the deprecation reports one configure produces, which is the whole point of the
# once-per-configure guard: a consumer with hundreds of targets gets one report by default
# and every call only when it asks. A CTest regex can say a report appeared but not how many
# appeared, and a configure cannot see its own diagnostics, so this drives the configure
# itself and counts the banners in what it printed.
#
# The scenario halts on a sentinel once both targets exist, so the configure exits non-zero
# by design and its exit code says nothing; the sentinel is checked instead.
#
# Inputs, all passed with -D: FIXTURE_DIR (the project to configure) and WORK_DIR (a build
# tree this script owns and wipes).

cmake_minimum_required(VERSION 3.20)

foreach(required FIXTURE_DIR WORK_DIR)
  if(NOT DEFINED ${required})
    message(FATAL_ERROR "legacy_warning_volume: -D${required}=... is required")
  endif()
endforeach()

# Configure the two-legacy-target scenario and report how many deprecation banners came
# back in COUNT_VAR. LABEL names the run in diagnostics and picks its own build tree, so the
# two runs never share one. Any trailing arguments are extra -D flags for the configure.
function(count_deprecation_banners LABEL COUNT_VAR)
  set(build_dir "${WORK_DIR}/${LABEL}")
  file(REMOVE_RECURSE "${build_dir}")
  file(MAKE_DIRECTORY "${build_dir}")

  # CMake prints diagnostics on stderr; naming one variable for both pipes merges them.
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      -DSCENARIO=legacy_volume
      ${ARGN}
      -S "${FIXTURE_DIR}"
      -B "${build_dir}"
    OUTPUT_VARIABLE output
    ERROR_VARIABLE output)

  if(NOT output MATCHES "LEGACY_VOLUME_OK")
    message(FATAL_ERROR
      "legacy_warning_volume: the ${LABEL} configure never reached the scenario's halt, so "
      "it did not create both targets:\n${output}")
  endif()

  # CMake 4.4 renamed the banner message(DEPRECATION) prints: "CMake Deprecation Warning at"
  # became "CMake Warning (deprecated) at" when CMP0218 reworked diagnostics. Both spellings
  # count, or this stops counting anything on half the supported CMake versions.
  string(REGEX MATCHALL
    "CMake (Deprecation Warning|Warning [(]deprecated[)]) at" banners "${output}")
  list(LENGTH banners banner_count)
  set(${COUNT_VAR} "${banner_count}" PARENT_SCOPE)
endfunction()

count_deprecation_banners(default default_count)
if(NOT default_count EQUAL 1)
  message(FATAL_ERROR
    "legacy_warning_volume: two targets on the deprecated spelling produced "
    "${default_count} deprecation reports, expected exactly 1 -- the run-once guard is not "
    "holding, and a consumer with hundreds of targets would get one report each.")
endif()

count_deprecation_banners(all all_count -DTARGETS_WARN_ALL_LEGACY_SOURCES=ON)
if(NOT all_count EQUAL 2)
  message(FATAL_ERROR
    "legacy_warning_volume: with TARGETS_WARN_ALL_LEGACY_SOURCES=ON, two targets on the "
    "deprecated spelling produced ${all_count} deprecation reports, expected one each.")
endif()

message(STATUS
  "legacy_warning_volume: one report per configure by default, one per call when asked")
