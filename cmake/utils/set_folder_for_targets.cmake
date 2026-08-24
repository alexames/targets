# set_folder_for_targets(): put several existing targets in one IDE folder.

include_guard(GLOBAL)

# Set the FOLDER property on several targets at once, which is how third-party targets a
# project did not declare itself get organized in an IDE.
#
# Arguments:
#   FOLDER: The folder path, e.g. "ThirdParty/Libraries" (required).
#   TARGETS: The targets to set it on. Each must already exist; one that does not is a
#            WARNING and is skipped, since a target's presence often depends on which
#            optional dependencies were found.
#
# FATAL_ERROR when FOLDER is missing. An empty TARGETS list is a WARNING and does nothing.
#
# Example:
#   set_folder_for_targets(
#       FOLDER "ThirdParty/Libraries"
#       TARGETS fmt spdlog EnTT
#   )
function(set_folder_for_targets)
  set(options)
  set(one_value_args FOLDER)
  set(multi_value_args TARGETS)

  cmake_parse_arguments(
    PARSE_ARGV 0
    ARGS
    "${options}"
    "${one_value_args}"
    "${multi_value_args}")

  if(NOT ARGS_FOLDER)
    message(FATAL_ERROR "set_folder_for_targets: FOLDER argument is required")
  endif()

  if(NOT ARGS_TARGETS)
    message(WARNING "set_folder_for_targets: No TARGETS specified")
    return()
  endif()

  foreach(target ${ARGS_TARGETS})
    if(TARGET ${target})
      set_target_properties("${target}" PROPERTIES FOLDER "${ARGS_FOLDER}")
    else()
      message(WARNING "set_folder_for_targets: Target '${target}' does not exist")
    endif()
  endforeach()
endfunction()
