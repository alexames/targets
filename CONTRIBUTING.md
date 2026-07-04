# Contributing to Targets

Thanks for your interest in improving **Targets**! Issues and pull requests are welcome.
Please open an issue to discuss substantial changes before starting, so we can agree on
the approach.

Targets is a pure-CMake library: it ships as CMake modules under [`cmake/`](cmake/) and
has no compiled runtime code. Keep that in mind when contributing — most changes are to
`.cmake` modules, their examples, and their tests.

## Repository layout

```
targets/
├── cmake/
│   ├── Targets.cmake              # entry point — includes every module
│   ├── TargetsVersion.cmake       # single source of truth for the version
│   ├── TargetsConfig.cmake.in     # package config template (find_package)
│   ├── dummy.cpp                  # placeholder TU for source-less targets
│   ├── core/
│   │   ├── cpp_target.cmake        # the engine behind all core rules
│   │   ├── cpp_library.cmake       # cpp_library wrapper
│   │   ├── cpp_binary.cmake        # cpp_binary wrapper
│   │   ├── cpp_test.cmake          # cpp_test wrapper (+ GTest integration)
│   │   ├── install_export.cmake    # install/export rules (INSTALL/EXPORT)
│   │   ├── toolchain_hygiene.cmake # WARNINGS/WERROR/SANITIZERS/LTO translation
│   │   └── platform_parser.cmake   # platform-conditional argument filtering
│   ├── dependencies/
│   │   ├── import_dependencies.cmake  # namespace-based subdirectory import
│   │   └── find_targets.cmake         # recursive target discovery
│   ├── codegen/
│   │   ├── flatbuffer_cpp_library.cmake
│   │   └── protobuf_cpp_library.cmake  # protobuf_cpp_library + grpc_cpp_library
│   └── utils/
│       ├── set_folder_for_targets.cmake
│       └── embed_binary.cmake
├── examples/                      # buildable usage examples
├── tests/                         # CTest suite (script-mode + configure-mode)
├── ports/targets/                 # vcpkg overlay port
├── docs/                          # API reference & migration guide
└── CMakeLists.txt                 # builds examples + tests, install rules
```

## Design goals

Keep changes aligned with the project's design goals:

1. **Declarative** — one rule call fully describes a target.
2. **Work with CMake, not around it** — rules expand to ordinary targets and properties so
   a user can still apply any `target_*` command afterward. Don't reinvent what CMake does
   natively.
3. **Consistent `PUBLIC`/`PRIVATE` visibility** across `INCLUDES`, `DEFINITIONS`, and
   `DEPENDENCIES`.
4. **IDE-first** — source groups and folder organization are set up automatically.
5. **Distributable** via vcpkg and `find_package`.

Prefer options that read declaratively and translate to standard CMake. Reject anything
that fights CMake idioms or merely duplicates a one-line native call.

## Building and testing

Configure and build the examples and tests out of source (never build inside the repo):

```bash
cmake -B build -S . -DTARGETS_BUILD_EXAMPLES=ON -DTARGETS_BUILD_TESTS=ON
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

For logic that does not need a compiler (for example the platform parser), prefer a
script-mode test you can run directly:

```bash
cmake -P tests/unit/test_parse_platforms.cmake
```

- `TARGETS_BUILD_EXAMPLES` (ON) and `TARGETS_BUILD_TESTS` (ON) toggle the example and test
  builds.
- Script-mode (`cmake -P`) tests are fast and need no toolchain — prefer them for pure
  logic.
- For behavior that needs a real target (library type, link libraries, folders, aliases),
  a configure-mode test — a tiny `project(x LANGUAGES NONE)` that calls a rule and asserts
  `get_target_property` results, or checks for an expected `FATAL_ERROR` via
  `PASS_REGULAR_EXPRESSION` — is the cheapest reliable harness.

Continuous integration ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs four
jobs, each on ubuntu-latest, windows-latest, and macos-latest:

- **build-examples** — builds every example and runs the executable, shared-library, and
  data-file ones.
- **test-suite** — configures with `TARGETS_BUILD_TESTS=ON` and runs the full `ctest`
  suite.
- **install-export** — installs the `install_export` example and consumes it from a
  separate project via `find_package(WidgetKit CONFIG REQUIRED)`.
- **consume-port** — installs the in-repo vcpkg port and consumes it via
  `find_package(Targets CONFIG REQUIRED)`.

Local testing usually covers only one OS, so rely on CI for cross-platform coverage and
report your local results honestly in the PR.

## Branching and pull requests

- Never commit to `main` directly. Branch from an up-to-date `main` and open a pull
  request.
- Name branches with a prefix matching the change type:
  - `bug/` — bug fixes
  - `feature/` — new rules or features
  - `doc/` — documentation-only changes
  - `refactor/` — internal restructuring
  - `test/` — test-only changes

  Include the issue number and a short slug, e.g. `bug/issue-14-static-shared-exclusive`.
- Keep commits small and focused; each commit should leave the tree in a working state.
- Write PR descriptions with **Summary / Changes / Testing** sections and reference the
  issue being resolved (`Closes #<N>`).

## Coding conventions

- **Indentation:** 2 spaces. Use lowercase command names and explicit `endfunction()` /
  `endif()` closers.
- **Private helpers:** prefix internal functions and macros with `_targets_`. The public
  API is unprefixed (`cpp_library`, `cpp_binary`, `cpp_test`, ...).
- **Argument parsing:** use `cmake_parse_arguments(PARSE_ARGV 0 ...)`. Validate required
  arguments and reject unknown ones (`<prefix>_UNPARSED_ARGUMENTS`) with clear
  `FATAL_ERROR` messages that name the rule and the offending argument.
- **Always quote paths**, and iterate with `foreach(... IN LISTS ...)` so empty elements
  are tolerated.
- New modules should use `include_guard(GLOBAL)` and be `include()`d from
  `cmake/Targets.cmake`.

## Adding a new rule

When you add a rule:

1. Put it in the appropriate `cmake/<category>/` directory and `include()` it from
   `cmake/Targets.cmake`.
2. Validate required arguments and reject unknown ones.
3. Add an example under [`examples/`](examples/) and a test under [`tests/`](tests/)
   (script-mode if possible, otherwise a configure-mode assertion — and a negative test
   for expected `FATAL_ERROR`s).
4. Document it in [`README.md`](README.md) and [`docs/API.md`](docs/API.md) in the same
   change.
5. Make sure it is exercised by CI on all three operating systems.

Any change to the public API must update `README.md` and `docs/API.md` alongside the code.

## License

By contributing, you agree that your contributions are licensed under the project's
[MIT License](LICENSE).
