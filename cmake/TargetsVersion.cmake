# Single source of truth for the Targets library version.
#
# This value drives:
#   - project(Targets VERSION ...) in the root CMakeLists.txt (this file is included
#     before project()), which generates TargetsConfigVersion.cmake and lets
#     find_package(Targets <ver> CONFIG REQUIRED) succeed against the advertised version.
#   - the load STATUS message emitted by Targets.cmake.
#
# It is installed alongside the other CMake modules (share/targets/cmake), so the same
# value is available whether Targets is vendored or consumed via find_package.
#
# Keep this in sync with the "version" field in the root vcpkg.json and
# ports/targets/vcpkg.json (JSON manifests cannot include CMake) and with the release
# git tag (vX.Y.Z). See https://github.com/alexames/targets/issues/11.
set(TARGETS_VERSION "0.10.1")
