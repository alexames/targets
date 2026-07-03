# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0] - 2026-07-03

This release hardens the core rules, adds installation/export support, expands the
code-generation and toolchain-hygiene surface, and brings the continuous-integration
suite up to full coverage across Linux, macOS, and Windows.

### Added

- Installation and export support: `cpp_library` can now install and export its targets
  so downstream projects consume them via `find_package(Targets CONFIG)` with an
  `install_export` example demonstrating the producer/consumer flow ([#20]).
- SHARED-library ergonomics on Windows: automatic export-header generation and DLL
  staging next to dependent binaries ([#21]).
- Toolchain-hygiene options — `WARNINGS`, `WERROR`, `SANITIZERS`, and `LTO` — that
  translate to the appropriate per-compiler flags ([#23]).
- Protobuf and gRPC code-generation rules alongside the existing FlatBuffers rule ([#26]).
- Bazel-parity target attributes: `DATA`, `COPTS`, `LINKOPTS`, `SIZE`, `TIMEOUT`,
  `LABELS`, and `ARGS` ([#27]).
- A full CI test suite that configures, builds, and runs the CTest suite on all three
  operating systems ([#24]).
- A `cpp_test` guard that fails the test run when a test binary registers zero GoogleTest
  cases at runtime (rather than silently passing); opt out with `ALLOW_NO_TESTS` ([#28]).
- Project documentation: this `CHANGELOG.md`, a `CONTRIBUTING.md` guide, and the `LICENSE`
  is now installed alongside the package config in the CMake install tree ([#19]).

### Fixed

- `embed_binary` aborted on every call due to an invalid `list()` expression ([#1]).
- The in-repo vcpkg port produced a layout that broke `find_package(Targets)`; it now
  matches the working `configure_package_config_file` layout ([#2]).
- Google Test is acquired lazily (at first `cpp_test` use) instead of at include time, so
  offline configures with no tests no longer fail ([#3]).
- Rules now validate arguments and reject unknown/unparsed arguments with clear errors
  instead of silently dropping entries ([#4]).
- MSVC `/ZI` and `/SAFESEH:NO` are no longer applied unconditionally — they no longer
  de-optimize Release builds or break ARM64 ([#5]).
- `source_group(TREE ...)` no longer hard-errors for generated or out-of-root sources in
  out-of-source builds ([#6]).
- The `dummy.cpp` fallback path is corrected and no longer flips header-only libraries to
  STATIC ([#7]).
- Namespace aliases, IDE folders, and auto-import key off the enclosing project rather
  than `CMAKE_PROJECT_NAME`, so embedded subprojects work ([#8]).
- Test wiring honors `BUILD_TESTING` and no longer relies on directory-scoped
  `enable_testing()` ([#9]).
- FetchContent-acquired Google Test no longer leaks into the consumer's install tree ([#10]).
- The version is now defined in a single source of truth shared across the CMake modules
  and package manifests ([#11]).
- Platform sentinel words can be escaped with a `LITERAL` marker so they can be used as
  ordinary tokens ([#12]).
- The INTERFACE (header-only) branch no longer drops `PRIVATE` items, `FOLDER`, `VERSION`,
  `PROPERTIES`, PCH, and unity settings ([#13]).
- Declaring a target as both `STATIC` and `SHARED` now raises a clear error ([#14]).
- `cpp_test` argument parsing handles its full argument set correctly ([#15]).

### Changed

- CI: replaced deprecated Node 20 actions and disabled the broken GitHub Actions binary
  cache to stabilize builds.
- Documentation reconciled with the implementation, including `cpp_test` and
  platform-conditional entry docs ([#16], [#17], [#18]).

### Removed

- Stale, private-project-specific artifacts `SUMMARY.md` and `INTEGRATION_GUIDE.md` ([#19]).

[Unreleased]: https://github.com/alexames/targets/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/alexames/targets/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/alexames/targets/releases/tag/v0.9.0

[#1]: https://github.com/alexames/targets/issues/1
[#2]: https://github.com/alexames/targets/issues/2
[#3]: https://github.com/alexames/targets/issues/3
[#4]: https://github.com/alexames/targets/issues/4
[#5]: https://github.com/alexames/targets/issues/5
[#6]: https://github.com/alexames/targets/issues/6
[#7]: https://github.com/alexames/targets/issues/7
[#8]: https://github.com/alexames/targets/issues/8
[#9]: https://github.com/alexames/targets/issues/9
[#10]: https://github.com/alexames/targets/issues/10
[#11]: https://github.com/alexames/targets/issues/11
[#12]: https://github.com/alexames/targets/issues/12
[#13]: https://github.com/alexames/targets/issues/13
[#14]: https://github.com/alexames/targets/issues/14
[#15]: https://github.com/alexames/targets/issues/15
[#16]: https://github.com/alexames/targets/issues/16
[#17]: https://github.com/alexames/targets/issues/17
[#18]: https://github.com/alexames/targets/issues/18
[#19]: https://github.com/alexames/targets/issues/19
[#20]: https://github.com/alexames/targets/issues/20
[#21]: https://github.com/alexames/targets/issues/21
[#23]: https://github.com/alexames/targets/issues/23
[#24]: https://github.com/alexames/targets/issues/24
[#26]: https://github.com/alexames/targets/issues/26
[#27]: https://github.com/alexames/targets/issues/27
[#28]: https://github.com/alexames/targets/issues/28
