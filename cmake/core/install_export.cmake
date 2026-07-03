# install_export.cmake
# Install/export support for cpp_target-created targets (issue #20).
#
# By default a cpp_library target is a build-tree-only artifact: its public include
# directories are plain source paths (implicitly BUILD_INTERFACE) and no install/export
# rules are generated, so a downstream project cannot consume it via find_package. Passing
# INSTALL (and optionally EXPORT <set>) to cpp_library/cpp_binary opts the target into a
# standard, relocatable install:
#
#   * public include directories are wrapped in $<BUILD_INTERFACE:...> and given a matching
#     $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> so the target is export-safe,
#   * install(TARGETS ... EXPORT <set>) installs the built artifact into the export set,
#   * the public headers are installed under ${CMAKE_INSTALL_INCLUDEDIR}, and
#   * a relocatable <Project>Config.cmake + <Project>ConfigVersion.cmake + the exported
#     targets file are generated once per export set, so that downstream
#     find_package(<Project> CONFIG REQUIRED) yields the namespaced target (e.g.
#     MyProject::MyLib) with the same name it has in the build tree.
#
# Everything here expands to ordinary CMake install()/export() commands; a consumer can
# still apply any install() of their own afterward.

include_guard(GLOBAL)

# Wrap a rule's public include directories so the target can be exported.
#
# A plain source/build path in a target's INTERFACE_INCLUDE_DIRECTORIES makes
# install(EXPORT ...) a hard error, because such a path is meaningless once the package is
# relocated. Each plain public include directory is therefore rewrapped as
# $<BUILD_INTERFACE:<abs>> (for in-tree consumers) and a single
# $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> entry is appended (for installed
# consumers). Entries that already contain a generator expression are passed through
# untouched, so a caller can hand-craft BUILD/INSTALL_INTERFACE entries when needed.
#
# OUT_ENTRIES receives the wrapped include list to hand to target_include_directories.
# OUT_DIRS receives the absolute directories whose contents are public headers (the
# install(DIRECTORY ...) sources). HEADER_DIR is the rule's default header directory and is
# always treated as public. The raw public include directories are passed as ARGN.
function(_targets_wrap_public_includes OUT_ENTRIES OUT_DIRS HEADER_DIR)
  include(GNUInstallDirs)
  set(entries "")
  set(dirs "")
  foreach(inc IN LISTS ARGN)
    if(inc MATCHES "\\$<")
      list(APPEND entries "${inc}")
    else()
      if(IS_ABSOLUTE "${inc}")
        set(abs "${inc}")
      else()
        set(abs "${CMAKE_CURRENT_SOURCE_DIR}/${inc}")
      endif()
      list(APPEND entries "$<BUILD_INTERFACE:${abs}>")
      list(APPEND dirs "${abs}")
    endif()
  endforeach()
  list(APPEND entries "$<BUILD_INTERFACE:${HEADER_DIR}>")
  list(APPEND dirs "${HEADER_DIR}")
  list(APPEND entries "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
  set(${OUT_ENTRIES} "${entries}" PARENT_SCOPE)
  set(${OUT_DIRS} "${dirs}" PARENT_SCOPE)
endfunction()

# Generate the install(EXPORT ...) rule and the relocatable package config for an export
# set, exactly once per set. Subsequent targets added to the same set reuse it. The set is
# recorded in a GLOBAL property so the once-only guard survives across directory scopes.
#
# The package name is the enclosing project (PROJECT_NAME), so find_package(<Project>)
# resolves the config. NAMESPACE is the target's computed namespace (without the trailing
# ::), so the exported target name matches the in-build alias exactly (e.g. MyProject::Lib).
function(_targets_finalize_export_set EXPORT_SET NAMESPACE)
  get_property(registered GLOBAL PROPERTY _TARGETS_EXPORT_SETS_REGISTERED)
  if(EXPORT_SET IN_LIST registered)
    return()
  endif()
  set_property(GLOBAL APPEND PROPERTY _TARGETS_EXPORT_SETS_REGISTERED "${EXPORT_SET}")

  include(GNUInstallDirs)
  include(CMakePackageConfigHelpers)

  set(pkg "${PROJECT_NAME}")
  set(config_dest "${CMAKE_INSTALL_LIBDIR}/cmake/${pkg}")
  set(targets_file "${EXPORT_SET}.cmake")

  # Install the generated targets file for the export set under the package's namespace, so
  # the imported target is <NAMESPACE>::<TARGET> -- identical to the build-tree alias.
  install(EXPORT ${EXPORT_SET}
    FILE "${targets_file}"
    NAMESPACE ${NAMESPACE}::
    DESTINATION "${config_dest}")

  # Generate a relocatable package config that pulls in the exported targets file. It is
  # written from an inline template so no template file needs to ship with the package.
  # @targets_file@ and @pkg@ are substituted by configure_package_config_file.
  set(config_in "${CMAKE_CURRENT_BINARY_DIR}/${pkg}Config.cmake.in")
  file(WRITE "${config_in}"
"@PACKAGE_INIT@

include(\"\${CMAKE_CURRENT_LIST_DIR}/@targets_file@\")

check_required_components(@pkg@)
")
  configure_package_config_file(
    "${config_in}"
    "${CMAKE_CURRENT_BINARY_DIR}/${pkg}Config.cmake"
    INSTALL_DESTINATION "${config_dest}")

  # A version file lets find_package(<Project> <ver> ...) do version checking. It requires a
  # version, so it is only generated when the enclosing project declared one.
  if(PROJECT_VERSION)
    write_basic_package_version_file(
      "${CMAKE_CURRENT_BINARY_DIR}/${pkg}ConfigVersion.cmake"
      VERSION "${PROJECT_VERSION}"
      COMPATIBILITY SameMajorVersion)
    install(FILES
      "${CMAKE_CURRENT_BINARY_DIR}/${pkg}Config.cmake"
      "${CMAKE_CURRENT_BINARY_DIR}/${pkg}ConfigVersion.cmake"
      DESTINATION "${config_dest}")
  else()
    install(FILES
      "${CMAKE_CURRENT_BINARY_DIR}/${pkg}Config.cmake"
      DESTINATION "${config_dest}")
  endif()
endfunction()

# Install a cpp_target-created target and, when an export set is named, add it to that set
# and generate the package config for downstream find_package. Called by cpp_target when
# INSTALL/EXPORT is requested.
#
# TARGET      the target to install (required).
# EXPORT      export-set name; when empty the target is installed but not exported.
# NAMESPACE   the target's namespace (without ::), used as the export namespace.
# HEADER_DIRS absolute directories whose contents are installed as public headers.
function(_targets_install_target)
  set(options)
  set(one_value_args TARGET EXPORT NAMESPACE)
  set(multi_value_args HEADER_DIRS)
  cmake_parse_arguments(PARSE_ARGV 0 install
    "${options}" "${one_value_args}" "${multi_value_args}")

  include(GNUInstallDirs)

  set(export_args "")
  if(install_EXPORT)
    set(export_args EXPORT ${install_EXPORT})
  endif()

  # Install the target's artifacts. An INTERFACE (header-only) library has no artifact, so
  # it only needs the export record; every other target type installs its archive/library/
  # runtime into the standard GNUInstallDirs locations.
  get_target_property(target_type ${install_TARGET} TYPE)
  if(target_type STREQUAL "INTERFACE_LIBRARY")
    if(install_EXPORT)
      install(TARGETS ${install_TARGET} EXPORT ${install_EXPORT})
    endif()
  else()
    install(TARGETS ${install_TARGET} ${export_args}
      ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
      LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
      RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
  endif()

  # Install the public headers: the contents of each public include directory that exists.
  # A trailing slash on the source installs the directory contents (preserving any nested
  # layout) rather than the directory itself. Directories are de-duplicated so an include
  # dir that coincides with HEADER_DIR is not installed twice.
  set(seen "")
  foreach(dir IN LISTS install_HEADER_DIRS)
    get_filename_component(dir_abs "${dir}" ABSOLUTE)
    if(NOT IS_DIRECTORY "${dir_abs}")
      continue()
    endif()
    if(dir_abs IN_LIST seen)
      continue()
    endif()
    list(APPEND seen "${dir_abs}")
    install(DIRECTORY "${dir_abs}/" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
  endforeach()

  # Generate the export set's package config once, so downstream find_package works.
  if(install_EXPORT)
    _targets_finalize_export_set("${install_EXPORT}" "${install_NAMESPACE}")
  endif()
endfunction()
