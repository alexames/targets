# set_folder_for_targets.cmake
# Utility to set IDE folder for multiple targets at once

include_guard(GLOBAL)

# Set the FOLDER property for multiple targets
# Useful for organizing third-party libraries in IDE solution explorers
#
# Arguments:
#   FOLDER: The folder path (e.g., "ThirdParty/Libraries")
#   TARGETS: List of target names
#
# Example:
#   set_folder_for_targets(
#       FOLDER "ThirdParty/Libraries"
#       TARGETS fmt spdlog EnTT
#   )
function(set_folder_for_targets)
  # Parse function arguments
  set(options)
  set(one_value_args FOLDER)
  set(multi_value_args TARGETS)

  cmake_parse_arguments(
    PARSE_ARGV 0
    ARGS
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  # Validate arguments
  if(NOT ARGS_FOLDER)
    message(FATAL_ERROR "set_folder_for_targets: FOLDER argument is required")
  endif()

  if(NOT ARGS_TARGETS)
    message(WARNING "set_folder_for_targets: No TARGETS specified")
    return()
  endif()

  # Set folder for each target
  foreach(target ${ARGS_TARGETS})
    if(TARGET ${target})
      set_target_properties("${target}" PROPERTIES FOLDER "${ARGS_FOLDER}")
    else()
      message(WARNING "set_folder_for_targets: Target '${target}' does not exist")
    endif()
  endforeach()
endfunction()
