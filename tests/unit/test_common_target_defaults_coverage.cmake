# Every rule that creates a compiled target must apply the shared defaults.
# Run via: cmake -P test_common_target_defaults_coverage.cmake
#
# _targets_apply_common_target_defaults() is the single place a setting is added once and
# reaches every compiled target the package produces. That only holds while every creation
# site calls it, and nothing in CMake enforces it: a new rule that writes its own
# add_library() compiles perfectly well and simply misses whatever the helper carries. This
# script is the enforcement, so a rule added later cannot repeat the omission unnoticed.
#
# It reads the shipped CMake sources rather than configuring a project, because a rule no
# test exercises is exactly the one that would slip through. Scanning is per scope, so a file
# that already applies the defaults in one rule must still apply them in a second one added
# beside it.
#
# Selected with -DSCENARIO=self_check, which also requires -DMUTATED_DIR=<scratch path>: the
# script rescans a copy of the sources with one helper call removed, and fails unless the
# scan reports it. Without that, an accidentally inert matcher would report a clean sweep of
# a codebase it never examined.

cmake_minimum_required(VERSION 3.20)

set(_targets_cmake_dir "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Report every scope in ROOT_DIR's CMake sources that creates a compiled target without
# applying the shared defaults, as entries in VIOLATIONS_VAR. The number of creation sites
# seen is returned in SITES_VAR, so a caller can tell "nothing is wrong" apart from "nothing
# was read". Only *.cmake under ROOT_DIR is read, recursively, and only text that is present
# as source -- a rule added in a CMakeLists.txt or a .cmake.in, or a target created through
# cmake_language(EVAL CODE), is invisible to this scan.
#
# Matching is line based, over comment-stripped and lowercased lines -- CMake command names
# are case insensitive, and an add_library() named in a comment is not a creation site. A
# creation site is an add_library()/add_executable() call naming a target, excluding a call
# whose argument after the target name is ALIAS, IMPORTED or INTERFACE -- none of those has a
# private compile step. The keyword is recognized only in that position, so a target whose own
# name contains one still counts. add_library(<name> <type> IMPORTED) puts the keyword one
# argument later and reads as a creation site; the package declares none.
#
# A call whose target name is not on the same line cannot be classified by a line-based scan,
# and is a hard error rather than a silent pass: going unseen is the exact failure this script
# exists to prevent.
#
# A scope passes when it calls the helper at least once, not once per creation site. cpp_target
# creates its library and its executable in exclusive branches of one if/else and applies the
# defaults after the join, so a site-to-call count would report it as short by one every time.
# The cost is that a scope creating two targets down two branches and guarding only one reads
# as guarded here; the configure-mode tests cover the rules that exist.
function(scan_for_unguarded_creation_sites ROOT_DIR VIOLATIONS_VAR SITES_VAR)
  file(GLOB_RECURSE cmake_sources "${ROOT_DIR}/*.cmake")
  set(creation_command "^[ \t]*add_(library|executable)[ \t]*\\(")
  set(creation_command_naming_a_target "${creation_command}[ \t]*[^ \t()]+")
  set(creation_command_for_a_non_compiled_target
    "${creation_command_naming_a_target}[ \t]+(alias|imported|interface)([ \t)]|$)")
  set(violations "")
  set(site_count 0)

  foreach(source IN LISTS cmake_sources)
    # Walk the file a line at a time with string(FIND)/string(SUBSTRING) rather than turning
    # it into a CMake list. A list is re-parsed with list semantics on every use: a non-ASCII
    # byte ends an element mid-line, leaving the tail to be read as a line of its own, and an
    # unbalanced "[[" swallows the following lines into one element. Either one misnumbers a
    # line, and either one can hide a creation site outright. Held as a plain string, a line
    # keeps every byte it had, so the index below is its true 1-based line number.
    file(READ "${source}" content)
    string(ASCII 13 carriage_return)
    string(ASCII 10 newline)
    string(REPLACE "${carriage_return}" "" content "${content}")

    set(line_number 0)
    set(inside_bracket FALSE)
    set(bracket_equals "")
    set(scope_name "<file scope>")
    set(scope_sites "")
    set(scope_calls 0)

    set(at_last_line FALSE)
    while(NOT at_last_line)
      string(FIND "${content}" "${newline}" break_at)
      if(break_at EQUAL -1)
        set(line "${content}")
        set(at_last_line TRUE)
      else()
        string(SUBSTRING "${content}" 0 ${break_at} line)
        math(EXPR resume_at "${break_at} + 1")
        string(SUBSTRING "${content}" ${resume_at} -1 content)
      endif()
      math(EXPR line_number "${line_number} + 1")

      # A bracket comment or bracket string spans lines, and its interior is not code: a
      # helper call quoted inside one does not guard anything, and an add_library() inside one
      # creates nothing. CMake opens a bracket with [=*[ -- a comment prefixes it with # --
      # and closes it with a ]=*] carrying the same number of '='. Both edges are handled on
      # the raw line, before the # strip below would swallow a #[[ opener whole, and only the
      # bracketed span is dropped, so code sharing the opening or closing line still counts.
      # An opener preceded by a double quote on its line is a bracket inside a string, not a
      # span: "[[]" is how a regex spells a literal '[', and treating it as one would swallow
      # the rest of the file. A multi-line quoted string is not tracked, so a doc string whose
      # interior line begins with the helper call reads as a call.
      if(inside_bracket)
        if(NOT line MATCHES "\\]${bracket_equals}\\](.*)$")
          continue()
        endif()
        set(line "${CMAKE_MATCH_1}")
        set(inside_bracket FALSE)
      endif()
      if(line MATCHES "^([^\"]*)#?\\[(=*)\\[")
        set(before_bracket "${CMAKE_MATCH_1}")
        set(bracket_equals "${CMAKE_MATCH_2}")
        if(NOT line MATCHES "\\[=*\\[.*\\]${bracket_equals}\\]")
          set(inside_bracket TRUE)
          set(line "${before_bracket}")
        endif()
      endif()

      string(REGEX REPLACE "#.*$" "" line "${line}")
      string(TOLOWER "${line}" line)

      # Opening a scope closes the previous one. Reporting here as well as at the close keeps
      # a file-scope site preceding the first function from being dropped by that reset.
      if(line MATCHES "^[ \t]*(function|macro)[ \t]*\\([ \t]*([a-z0-9_]+)")
        if(scope_sites AND scope_calls LESS_EQUAL 0)
          string(REPLACE ";" "," scope_sites_pretty "${scope_sites}")
          list(APPEND violations "${source}:${scope_sites_pretty} in ${scope_name}")
        endif()
        set(scope_name "${CMAKE_MATCH_2}")
        set(scope_sites "")
        set(scope_calls 0)
      endif()

      if(line MATCHES "${creation_command}")
        if(NOT line MATCHES "${creation_command_naming_a_target}")
          message(FATAL_ERROR
            "${source}:${line_number}: this add_library()/add_executable() call does not name "
            "its target on the same line, so a line-based scan cannot tell whether it creates "
            "a compiled target. Put the target name on the command's line, or teach this "
            "script to read the call.")
        endif()
        if(NOT line MATCHES "${creation_command_for_a_non_compiled_target}")
          list(APPEND scope_sites "${line_number}")
          math(EXPR site_count "${site_count} + 1")
        endif()
      endif()

      if(line MATCHES "^[ \t]*_targets_apply_common_target_defaults[ \t]*\\(")
        math(EXPR scope_calls "${scope_calls} + 1")
      endif()

      if(line MATCHES "^[ \t]*(endfunction|endmacro)[ \t]*\\(")
        if(scope_sites AND scope_calls LESS_EQUAL 0)
          string(REPLACE ";" "," scope_sites_pretty "${scope_sites}")
          list(APPEND violations "${source}:${scope_sites_pretty} in ${scope_name}")
        endif()
        set(scope_name "<file scope>")
        set(scope_sites "")
        set(scope_calls 0)
      endif()
    endwhile()

    # A site at file scope reaches no endfunction()/endmacro(), so it is reported here.
    if(scope_sites AND scope_calls LESS_EQUAL 0)
      string(REPLACE ";" "," scope_sites_pretty "${scope_sites}")
      list(APPEND violations "${source}:${scope_sites_pretty} in ${scope_name}")
    endif()
  endforeach()

  set(${VIOLATIONS_VAR} "${violations}" PARENT_SCOPE)
  set(${SITES_VAR} "${site_count}" PARENT_SCOPE)
endfunction()

# The compiled-target creation sites the package is known to have: one each in
# flatbuffer_cpp_library, protobuf_cpp_library and embed_binary, plus cpp_target's library
# and executable branches. Counting them turns a matcher that silently stopped matching into
# a failure, rather than a clean sweep of an empty set.
set(expected_sites 5)

scan_for_unguarded_creation_sites("${_targets_cmake_dir}" violations sites)

if(SCENARIO STREQUAL "self_check")
  # Rescan a copy with one helper call deleted. The scan has to name that rule, or it is not
  # measuring anything and every clean result it ever reports is worthless.
  if(NOT DEFINED MUTATED_DIR OR MUTATED_DIR STREQUAL "")
    message(FATAL_ERROR "self_check: -DMUTATED_DIR=<scratch path> is required")
  endif()
  set(mutated_dir "${MUTATED_DIR}")
  file(REMOVE_RECURSE "${mutated_dir}")
  file(COPY "${_targets_cmake_dir}/" DESTINATION "${mutated_dir}")

  set(mutated_rule "${mutated_dir}/utils/embed_binary.cmake")
  file(READ "${mutated_rule}" mutated_contents)
  string(REPLACE "_targets_apply_common_target_defaults(\${args_TARGET})" ""
    mutated_contents "${mutated_contents}")
  file(WRITE "${mutated_rule}" "${mutated_contents}")

  scan_for_unguarded_creation_sites("${mutated_dir}" mutated_violations mutated_sites)
  file(REMOVE_RECURSE "${mutated_dir}")

  if(NOT mutated_violations MATCHES "embed_binary")
    message(FATAL_ERROR
      "self_check: removing embed_binary's shared-defaults call was not detected. The scan "
      "reports nothing wrong with code that is wrong, so it proves nothing about the real "
      "sources either. Violations: [${mutated_violations}]")
  endif()
  message(STATUS "SELF_CHECK_OK: detected the seeded omission in embed_binary")
  return()
endif()

message(STATUS "Scanned ${sites} compiled-target creation site(s) under ${_targets_cmake_dir}")

# Reported before the count check, so a rule added without the call names itself rather than
# surfacing as a bare count mismatch.
if(violations)
  string(REPLACE ";" "\n  " violations_pretty "${violations}")
  message(FATAL_ERROR
    "These rule(s) create a compiled target without calling "
    "_targets_apply_common_target_defaults(), so every setting the helper carries silently "
    "skips the targets they create:\n  ${violations_pretty}")
endif()

if(NOT sites EQUAL expected_sites)
  message(FATAL_ERROR
    "Found ${sites} compiled-target creation site(s), expected ${expected_sites}. A rule was "
    "added or removed: check that every rule creating a compiled target calls "
    "_targets_apply_common_target_defaults(), then update expected_sites in this test.")
endif()

message(STATUS "Shared target defaults reach every compiled-target creation site")
