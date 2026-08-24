# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `SOURCES` now accepts `PUBLIC` and `PRIVATE` groups, the grammar every other list argument
  already uses. `PUBLIC` entries are the target's interface and resolve against `HEADER_DIR`;
  `PRIVATE` entries are its implementation and resolve against `SOURCE_DIR`; platform
  sentinels nest inside a visibility group, as they do for `DEPENDENCIES`. This is the split
  `SOURCES` and `HEADERS` already were -- the two lists differed by base directory, and those
  base directories are the private and public roots -- now spelled so that it says so, which
  is what stops a private header being filed under `HEADERS` and resolved against the wrong
  root ([#66]).
- `TARGETS_WARN_ALL_LEGACY_SOURCES` reports every call still on the deprecated spelling
  instead of only the first of a configure, naming the `CMakeLists.txt` lines left to
  migrate ([#66]).

### Changed

- Targets no longer creates `INTERFACE` libraries. A library with public files and no private
  translation unit is given the shipped `dummy.cpp` placeholder and built as `STATIC` (or
  `SHARED` when asked), exactly as a library with no files at all already was. This keeps
  dependency propagation commutative: a consumer sees the same usage requirements from a
  library however it reached it, instead of the target's kind deciding what depending on it
  means ([#79]).

  Downstream, such a target changes kind. Consumers now link an archive containing one empty
  translation unit, which changes link order, `--as-needed` behavior, and what
  `$<TARGET_FILE:...>` and `install(TARGETS)` resolve to for those targets. An installed
  header-only library now ships a `.lib`/`.a` and exports an import location rather than usage
  requirements alone.

  Every argument now applies to a header-only library, because it now has the compile step and
  the built artifact they describe: the `PRIVATE` `INCLUDES`/`DEFINITIONS`/`DEPENDENCIES`,
  `COPTS`, `LINKOPTS`, `DATA`, `VERSION`/`SOVERSION`, `PRECOMPILE_HEADERS`, `UNITY_BUILD`,
  `EXPORT_HEADER`, `WINDOWS_EXPORT_ALL_SYMBOLS`, and the `WARNINGS`/`WERROR`/`SANITIZERS`/`LTO`
  hygiene knobs. The configure-time warning that used to name each of these as ignored is
  gone: nothing is ignored any more, so the warning could only fire on a case that no longer
  exists ([#13], [#79]).

  `CXX_STANDARD` is correspondingly a setting on the target rather than a requirement
  propagated to consumers. A header-only library no longer carries `cxx_std_<N>` as an
  `INTERFACE` compile feature, so a consumer that needs a particular standard to compile those
  headers must ask for it, as it already must for every other library's headers ([#79]).

  A translation unit listed under `SOURCES PUBLIC` is now compiled. Before, a library whose
  only source sat there resolved to INTERFACE and that source was never built; it is now
  handed to `add_library`, which is what `PUBLIC` has always meant -- "resolved against
  `HEADER_DIR`, part of the interface", not "not compiled" ([#79]).

  `SHARED` on a header-only library is honored rather than contradictory: it builds the
  placeholder into a shared library. On Windows a library that exports nothing produces no
  import library, so linking one there needs `WINDOWS_EXPORT_ALL_SYMBOLS` or a real exported
  symbol ([#79]).

- Whether a library is header-only is now decided by whether any `PRIVATE` entry is a
  translation unit, rather than by whether `SOURCES` was given at all. A library with public
  files that lists private headers and no source file is header-only; before, the private
  header made it a compiled library with nothing to compile, which CMake then failed to give
  a link language.
  Every other shape is unchanged. The decision now selects whether the target is given the
  `dummy.cpp` placeholder rather than what kind of target it is ([#66], [#79]).
- `targets_enable_compiler_cache()` now reports a missing cache binary with a `WARNING`
  instead of a `STATUS` message, and the text says how to fix it. The caller asked for a
  cache and did not get one, the resulting build compiles everything uncached while still
  reporting success, and a configure is a one-time act whose result persists for the life of
  the build tree -- so a status line among a hundred others is not enough notice. The most
  common cause is a shell whose `PATH` predates the ccache install, which no amount of
  correct configuration on the machine fixes. `REQUIRED` still turns the same case into a
  `FATAL_ERROR` ([Composer#1367]).
- A library must offer consumers something. One that declares no public files, no
  dependencies, no `PUBLIC` entry under `INCLUDES`, `DEFINITIONS`, `COPTS` or `LINKOPTS`, and
  no source file of its own is now a configure error: it archives only the placeholder
  translation unit, so a target that links it is unaffected. Two shapes stay legal because
  they do reach a consumer -- private translation units, whose object code is a contribution
  in itself, and dependencies of any visibility, since a static library's private dependency
  still arrives on the consumer's link line. Every test reads the declared arguments rather
  than the platform-filtered result, so a cross-platform declaration is accepted on every
  platform. This can reject a declaration that configured before, so it warrants a minor
  version bump ([#82]).

### Deprecated

- A bare `SOURCES` list and the `HEADERS` argument. Both keep working and keep resolving
  exactly what they resolve today; a call using either reports itself through CMake's own
  deprecation machinery, so `-Wno-deprecated` silences it and `-Werror=deprecated` makes it a
  configure error. Only the first such call of a configure is reported -- a project with
  hundreds of targets would otherwise bury every other message -- and
  `-DTARGETS_WARN_ALL_LEGACY_SOURCES=ON` names the rest. A `SOURCES` list is one spelling or
  the other, decided by its first entry: opening bare and naming an access keyword later is a
  configure error, as is passing grouped `SOURCES` and `HEADERS` in one call ([#66]).

### Fixed

- The shipped `dummy.cpp` placeholder now resolves from any directory scope. `cpp_target.cmake`
  guards its body with `include_guard(GLOBAL)`, so the body runs in the first directory scope
  that includes Targets and nowhere else; the placeholder path was read at call time from a
  variable that body set, which a sibling directory including Targets for itself never sees.
  Every rule that needs the placeholder failed there with a path that had lost its root. The
  path is now derived inside the function from its own module directory ([#79]).
- `flatbuffer_cpp_library`, `protobuf_cpp_library`, `grpc_cpp_library`, and `embed_binary`
  now carry the same target-wide settings as `cpp_library`/`cpp_binary`/`cpp_test`:
  `CXX_SCAN_FOR_MODULES OFF`, and on MSVC `/utf-8` plus the Debug debug-information format
  that a compiler launcher can cache. Each of these rules built its target with its own
  `add_library()`, so nothing applied in `cpp_target` ever reached it. The gap is not
  theoretical for module scanning: these rules do not default the standard to 23, but a
  project-wide `CMAKE_CXX_STANDARD` of 20 or later puts their targets in scanning range, and
  so does any dependency carrying an `INTERFACE` compile feature such as `cxx_std_23`, which
  raises the standard its consumers are compiled at regardless of their own `CXX_STANDARD`
  ([#70]).
- The settings every compiled target carries moved into one shared helper that all four
  creation sites call, and a new `common_target_defaults_coverage` test reads the shipped
  CMake sources and fails on any rule that creates a compiled target without calling it. A
  rule added later cannot silently miss them again ([#70]).

## [0.11.0] - 2026-08-23

### Added

- `targets_enable_compiler_cache()`: points `CMAKE_C_COMPILER_LAUNCHER` and
  `CMAKE_CXX_COMPILER_LAUNCHER` at ccache (or sccache), wrapped in `cmake -E env` so
  `CCACHE_BASEDIR` and `CCACHE_NOHASHDIR` travel in the build rules instead of the
  developer's exported environment -- which is what lets two checkouts of the same sources
  share cache entries with no per-machine setup. It refuses to wire anything under a
  generator that would ignore the launcher (Visual Studio and Xcode among them; only the
  Makefile generators and Ninja run one), because a build that caches nothing while
  reporting success is worse than an uncached build. `PROGRAM` picks the binary, `BASE_DIR`
  overrides the rewrite root (default `CMAKE_SOURCE_DIR`), and `REQUIRED` turns a missing
  binary into a configure error ([Composer#1353]).

- CI installs ccache on all three test-suite runners, and the CTest suite gains
  `compiler_cache_cross_checkout`: a build-mode test that compiles one source from two
  separate checkouts against a single cache and asserts the second build was served from
  the entry the first build stored. The rest of the compiler-cache coverage asserts on
  launcher properties, which every generator accepts whether or not it runs one, so only
  a real compile distinguishes a working cache from a silently ignored launcher. A
  missing ccache, Ninja, or MSVC developer environment is reported as a skip
  ([Composer#1357]).

### Changed

- `cpp_library`, `cpp_binary`, and `cpp_test` now set `CXX_SCAN_FOR_MODULES OFF` on the
  compiled targets they create. Because they default to C++23, CMP0155 otherwise made CMake
  dependency-scan every translation unit for module imports; Targets offers no way to declare a
  module interface unit, so the scan never found one, and its cost cannot be served from a
  compile cache. A target that genuinely uses modules re-enables scanning with
  `set_target_properties(<t> PROPERTIES CXX_SCAN_FOR_MODULES ON)`, a consumer who sets
  `CMAKE_CXX_SCAN_FOR_MODULES` keeps their choice, and the new `TARGETS_SCAN_FOR_MODULES`
  option restores CMake's own default project-wide ([Composer#1355]).
- On MSVC, Debug targets now get embedded debug info (`/Z7`, through
  `MSVC_DEBUG_INFORMATION_FORMAT Embedded`) instead of edit-and-continue (`/ZI`) whenever a
  compiler launcher is configured. ccache refuses any translation unit compiled with `/Zi` or
  `/ZI` -- the debug info lands in a shared `.pdb` that a cache hit cannot reproduce -- so a
  Debug build cached nothing at all. The launcher outranks `TARGETS_MSVC_EDIT_AND_CONTINUE`,
  whose `ON` cannot be told apart from its default; with no launcher configured, `/ZI` is
  injected exactly as before. Other configurations keep CMake's default debug format, and a
  project that sets `CMAKE_MSVC_DEBUG_INFORMATION_FORMAT` keeps its own. Where the format
  comes from `CMAKE_CXX_FLAGS_DEBUG` instead of the property (CMake older than 3.25, or
  `CMP0141 OLD`), `/Z7` is appended to override it ([Composer#1354]).

## [0.10.1] - 2026-07-03

### Fixed

- `cpp_test`: Google Test acquisition now makes the `GTest::*` targets globally visible, so
  test targets defined across multiple sibling directories all link `GTest::gtest_main`. The
  lazy acquisition added in 0.10.0 created the imported targets in only the first directory
  that called `cpp_test()` (behind a run-once guard), so multi-directory projects failed to
  generate with "GTest::gtest_main ... not found" ([#62]).

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

[Unreleased]: https://github.com/alexames/targets/compare/v0.11.0...HEAD
[0.11.0]: https://github.com/alexames/targets/compare/v0.10.1...v0.11.0
[0.10.1]: https://github.com/alexames/targets/compare/v0.10.0...v0.10.1
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
[#62]: https://github.com/alexames/targets/issues/62
[#66]: https://github.com/alexames/targets/issues/66
[#70]: https://github.com/alexames/targets/issues/70
[#79]: https://github.com/alexames/targets/issues/79
[#82]: https://github.com/alexames/targets/issues/82
[Composer#1353]: https://github.com/alexames/Composer/issues/1353
[Composer#1354]: https://github.com/alexames/Composer/issues/1354
[Composer#1355]: https://github.com/alexames/Composer/issues/1355
[Composer#1357]: https://github.com/alexames/Composer/issues/1357
[Composer#1367]: https://github.com/alexames/Composer/issues/1367
