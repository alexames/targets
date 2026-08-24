# Read back the IDE source groups cpp_target() assigns. source_group() sets no property a
# configure-time assertion can read, so the only place its result surfaces is the
# .vcxproj.filters file a Visual Studio generator writes -- which is why this runs the
# configure itself instead of being a scenario of the fixture.
#
# PRIVATE entries belong under "Source Files" whether or not they are headers, and PUBLIC
# entries under "Header Files" -- the grouping follows visibility, not the file extension.
#
# Inputs, all passed with -D: FIXTURE_DIR (the project to configure), WORK_DIR (a build tree
# this script owns and wipes), and TEST_GENERATOR (a Visual Studio generator).

cmake_minimum_required(VERSION 3.20)

foreach(required FIXTURE_DIR WORK_DIR TEST_GENERATOR)
  if(NOT DEFINED ${required})
    message(FATAL_ERROR "ide_source_groups: -D${required}=... is required")
  endif()
endforeach()

file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${WORK_DIR}")

execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -G "${TEST_GENERATOR}"
    -DSCENARIO=visibility_base_dirs
    -S "${FIXTURE_DIR}"
    -B "${WORK_DIR}"
  RESULT_VARIABLE configure_result
  OUTPUT_VARIABLE configure_output
  ERROR_VARIABLE configure_output)
if(NOT configure_result EQUAL 0)
  message(FATAL_ERROR
    "ide_source_groups: configuring the fixture failed (${configure_result}):\n"
    "${configure_output}")
endif()

set(filters "${WORK_DIR}/VisibilityLib.vcxproj.filters")
if(NOT EXISTS "${filters}")
  message(FATAL_ERROR "ide_source_groups: '${filters}' was not generated")
endif()
file(READ "${filters}" filters_content)

# Each entry is one XML element naming the file and holding its group, e.g.
#   <ClInclude Include="...\public.hpp">
#     <Filter>Header Files</Filter>
#   </ClInclude>
# Matching on the file name alone keeps the pattern clear of the backslash-separated
# absolute path the generator writes.
foreach(expected
    "in_tree[.]cpp=Source Files"
    "detail[.]hpp=Source Files"
    "public[.]hpp=Header Files")
  string(REGEX REPLACE "=.*$" "" file_pattern "${expected}")
  string(REGEX REPLACE "^[^=]*=" "" group "${expected}")
  if(NOT filters_content MATCHES
     "Include=\"[^\"]*${file_pattern}\">[ \t\r\n]*<Filter>${group}</Filter>")
    message(FATAL_ERROR
      "ide_source_groups: no entry putting ${file_pattern} in '${group}'. The filters file "
      "holds:\n${filters_content}")
  endif()
endforeach()

message(STATUS "ide_source_groups: visibility decides the IDE group, not the extension")
