# Targets

**Modern CMake build abstraction with Bazel-like ergonomics.**

Targets is a small, dependency-free set of CMake modules that give you declarative,
readable build rules — `cpp_library`, `cpp_binary`, `cpp_test`, and code-generation
helpers — layered on top of idiomatic modern CMake. You get the ergonomics of a rule
system like Bazel while staying fully inside the CMake ecosystem (vcpkg, `find_package`,
IDE integration, generator expressions, everything).

```cmake
cpp_library(
    TARGET MathLib
    SOURCES  src/calculator.cpp
    HEADERS  mathlib/calculator.h
    INCLUDES PUBLIC include/
    DEPENDENCIES PUBLIC fmt::fmt
)

cpp_binary(
    TARGET CalculatorApp
    SOURCES src/main.cpp
    DEPENDENCIES PRIVATE MathLib
)
```

> **Project status:** pre-1.0 and under active development. The API is usable and
> covered by examples and tests, but some rules and the vcpkg packaging are still being
> hardened — see [open issues](https://github.com/alexames/targets/issues) for known
> gaps before depending on a specific feature in production.

---

## Table of contents

- [Goals & design principles](#goals--design-principles)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Core rules](#core-rules)
  - [`cpp_library`](#cpp_library)
  - [`cpp_binary`](#cpp_binary)
  - [`cpp_test`](#cpp_test)
  - [Common arguments](#common-arguments)
- [Platform-conditional entries](#platform-conditional-entries)
- [Dependency management & namespaces](#dependency-management--namespaces)
- [Code generation](#code-generation)
- [Utilities](#utilities)
- [Project structure](#project-structure)
- [Building & testing this repository](#building--testing-this-repository)
- [Roadmap & known issues](#roadmap--known-issues)
- [Contributing](#contributing)
- [License](#license)

---

## Goals & design principles

1. **Declarative over imperative.** One call describes a target completely — sources,
   headers, include dirs, definitions, dependencies, and their `PUBLIC`/`PRIVATE`
   visibility — instead of a scatter of `add_library` + `target_*` commands.
2. **Work *with* CMake, not around it.** Rules expand to ordinary CMake targets and
   properties. Anything CMake can do to a target (generator expressions, extra
   `target_*` calls, install/export) still works afterward.
3. **Consistent visibility model.** Every list argument that can be transitive
   (`INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`) uses the same `PUBLIC` / `PRIVATE`
   grammar you already know from `target_link_libraries`.
4. **IDE-first.** Targets sets up source groups and `FOLDER` organization automatically
   so Visual Studio / Xcode / CLion solution trees stay tidy.
5. **Distributable.** Shipped as CMake modules that install into a package config and
   are consumable via vcpkg.

## Requirements

- **CMake 3.20 or later.**
- A C++ compiler. By default, targets are configured for **C++23**
  (`CXX_STANDARD 23`, `CXX_STANDARD_REQUIRED ON`, `CXX_EXTENSIONS OFF`). Pass
  `CXX_STANDARD <n>` to any rule to select an older standard per target.
- Optional, per feature: **Google Test** (for `cpp_test`; auto-fetched if absent),
  **FlatBuffers** (for `flatbuffer_cpp_library`).

## Getting started

### Option A — vendor the modules (works today)

Copy or submodule this repository into your project and put its `cmake/` directory on
the module path:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyProject)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/third_party/targets/cmake")
include(Targets)

cpp_library(TARGET MyLib SOURCES src/mylib.cpp INCLUDES PUBLIC include/)
```

This is exactly how the [`examples/`](examples/) build.

### Option B — vcpkg

Targets is published to a custom vcpkg registry
([alexames/vcpkg-registry](https://github.com/alexames/vcpkg-registry)). Add it to your
`vcpkg-configuration.json`, depend on `targets`, and consume it like any other package:

```cmake
find_package(Targets CONFIG REQUIRED)
include(Targets)
```

> The registry package works via `find_package`. The in-repo
> [overlay port](ports/targets/) installs the same layout by driving this project's own
> install rules, so it can be used directly with vcpkg `overlay-ports` for local
> development (see [docs/MIGRATION.md](docs/MIGRATION.md)).

## Core rules

All three core rules are thin wrappers over `cpp_target`, so they share the same
argument grammar (see [Common arguments](#common-arguments)).

### `cpp_library`

Defines a C++ library. Produces a **STATIC** library by default, **SHARED** if you pass
`SHARED`. If you provide `HEADERS` but no `SOURCES`, an **INTERFACE** (header-only)
library is created automatically.

```cmake
cpp_library(
    TARGET MyLib
    SOURCES src/a.cpp src/b.cpp
    HEADERS include/mylib/a.h
    INCLUDES
        PUBLIC  include/
        PRIVATE src/
    DEFINITIONS PUBLIC MYLIB_API
    DEPENDENCIES
        PUBLIC  fmt::fmt
        PRIVATE spdlog::spdlog
    CXX_STANDARD 20
    VERSION 1.2.3
    SOVERSION 1
)
```

### `cpp_binary`

Defines an executable. Same grammar as `cpp_library`, plus debugger conveniences:

```cmake
cpp_binary(
    TARGET MyApp
    SOURCES src/main.cpp
    DEPENDENCIES PRIVATE MyLib
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"   # VS debugger working dir
    COMMAND_ARGUMENTS "--verbose --config=dev"        # VS debugger arguments
)
```

### `cpp_test`

Defines a Google Test executable and registers it with CTest via
`gtest_discover_tests`. **The GTest entry point is linked automatically** — you do *not*
need to add `GTest::gtest_main` to `DEPENDENCIES`. If Google Test isn't found, it is
fetched with `FetchContent`. Tests default to the `Tests` IDE folder.

```cmake
cpp_test(
    TARGET TestMyLib
    SOURCES test/test_mylib.cpp
    DEPENDENCIES PRIVATE MyLib
)
```

### Common arguments

| Argument | Rules | Meaning |
|---|---|---|
| `TARGET` | all | Target name (**required**). |
| `SOURCES` | all | Source files, resolved relative to `SOURCE_DIR`. |
| `HEADERS` | all | Header files, resolved relative to `HEADER_DIR`. |
| `INCLUDES` | all | Include dirs, grouped under `PUBLIC` / `PRIVATE`. |
| `DEFINITIONS` | all | Preprocessor definitions, grouped under `PUBLIC` / `PRIVATE`. |
| `DEPENDENCIES` | all | Link libraries, grouped under `PUBLIC` / `PRIVATE`. |
| `CXX_STANDARD` | all | C++ standard for this target (default **23**). |
| `FOLDER` | all | IDE folder path (defaults derive from the namespace). |
| `PROPERTIES` | all | Extra `set_target_properties` key/value pairs. |
| `PRECOMPILE_HEADERS` | all | Headers to precompile. |
| `UNITY_BUILD` | all | **Flag** — enable unity/jumbo build (presence = on). |
| `UNITY_BUILD_BATCH_SIZE` | all | Files per unity chunk (default 16). |
| `STATIC` / `SHARED` | `cpp_library` | Library linkage (default STATIC). |
| `VERSION` / `SOVERSION` | `cpp_library` | Library version / ABI version. |
| `WORKING_DIRECTORY` | `cpp_binary`, `cpp_test` | Debugger / test working directory. |
| `COMMAND_ARGUMENTS` | `cpp_binary` | VS debugger command-line arguments. |
| `SOURCE_DIR` | all | Base dir for relative sources (default: current list dir). |
| `HEADER_DIR` | all | Base dir for relative headers (default: `<current list dir>/Include`). |
| `NAMESPACE_ROOT` | all | Root for namespace-alias derivation (default: `${PROJECT_SOURCE_DIR}/Source`). |

> **Always prefix `INCLUDES` / `DEFINITIONS` / `DEPENDENCIES` values with `PUBLIC` or
> `PRIVATE`.** The keyword is required: any entry placed before the first visibility
> keyword is rejected with a configure-time error (it was previously dropped silently —
> [#4](https://github.com/alexames/targets/issues/4)). Unknown or misspelled arguments are
> likewise rejected instead of being ignored.

## Platform-conditional entries

`SOURCES`, `HEADERS`, `INCLUDES`, `DEFINITIONS`, and `DEPENDENCIES` support inline
platform filtering. List unconditional entries first, then group platform-specific
entries under a sentinel: `WINDOWS`, `LINUX`, `MACOS`, `ANDROID`, `EMSCRIPTEN`, or
`DEFAULT` (used when no specific platform matches).

```cmake
cpp_library(
    TARGET Platform
    SOURCES
        common.cpp            # always compiled
        WINDOWS   win32.cpp
        LINUX     posix.cpp
        MACOS     posix.cpp cocoa.mm
        DEFAULT   stub.cpp    # any platform not listed above
    DEPENDENCIES
        PUBLIC   fmt::fmt
        WINDOWS  ws2_32
)
```

The current build platform is auto-detected. Entries for the active platform (plus all
unconditional entries) are kept; the rest are filtered out.

> The sentinel words are reserved: a value literally equal to `WINDOWS`/`LINUX`/… can't
> currently be passed through these arguments
> ([#12](https://github.com/alexames/targets/issues/12)).

## Dependency management & namespaces

### Automatic namespace aliases

Every target gets an alias derived from its location under `NAMESPACE_ROOT`
(default `${PROJECT_SOURCE_DIR}/Source`) and the top-level project name:

```
MyProject/
└── Source/
    └── Core/
        └── CMakeLists.txt   # defines target "Engine"
```

produces the alias **`MyProject::Core::Engine`**, which you can link from anywhere.

> Aliases and auto-import currently key off the *top-level* project name, so a library
> embedded via `add_subdirectory`/`FetchContent` sees different aliases than when built
> standalone ([#8](https://github.com/alexames/targets/issues/8)).

### `import_dependencies(<target> <dependencies>)`

Given a list of namespaced dependency labels, automatically `add_subdirectory`s the
directories that define them (with circular-dependency detection). Called for you by the
core rules, and available directly:

```cmake
import_dependencies(MyApp "MyProject::Core::Engine;MyProject::Render::Graphics")
```

*Note: this is a positional command (`target` then a dependency list), not a
keyword-style call.*

### `import_subdirectory(<dir>)` / `import_all(<dir>)` / `find_targets()`

- `import_subdirectory` — `add_subdirectory` with duplicate/circular-import protection.
- `import_all` — recursively import every `CMakeLists.txt` under a directory tree.
- `find_targets(DIRECTORY <dir> NAME <file>)` — discover and add subdirectories that
  contain a given file.

## Code generation

### `flatbuffer_cpp_library`

Generates C++ headers from FlatBuffers schemas and wraps them in a linkable library.

```cmake
flatbuffer_cpp_library(
    TARGET GameSchemas
    SCHEMAS schemas/player.fbs schemas/world.fbs
    SCHEMA_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/schemas"
    INCLUDE_PREFIX "game/generated"
    BINARY_SCHEMAS_DIR "${CMAKE_BINARY_DIR}/schemas"   # optional .bfbs output
    DEPENDENCIES CommonSchemas                          # other schema targets
    FLAGS --gen-mutable                                 # extra flatc flags
)
```

Requires a `flatc` compiler (from vcpkg's `flatbuffers` or FetchContent). Default flatc
flags are `--scoped-enums --gen-object-api --keep-prefix`.

## Utilities

### `set_folder_for_targets(FOLDER <path> TARGETS <t>...)`

Bulk-assign an IDE `FOLDER` to several targets — handy for third-party libraries:

```cmake
set_folder_for_targets(FOLDER "ThirdParty" TARGETS fmt spdlog)
```

### `embed_binary(TARGET <name> FILES <f>... [NAMESPACE <ns>] [OUTPUT_DIR <dir>])`

Intended to embed binary files as a C++ static library.

> ⚠️ **Currently non-functional** — every call aborts configuration
> ([#1](https://github.com/alexames/targets/issues/1)). For production embedding today,
> prefer [CMakeRC](https://github.com/vector-of-bool/cmrc).

## Project structure

```
targets/
├── cmake/
│   ├── Targets.cmake              # entry point — includes every module
│   ├── TargetsConfig.cmake.in     # package config template (find_package)
│   ├── dummy.cpp                  # placeholder TU for source-less targets
│   ├── core/
│   │   ├── cpp_target.cmake        # the engine behind all core rules
│   │   ├── cpp_library.cmake       # cpp_library wrapper
│   │   ├── cpp_binary.cmake        # cpp_binary wrapper
│   │   ├── cpp_test.cmake          # cpp_test wrapper (+ GTest integration)
│   │   └── platform_parser.cmake   # platform-conditional argument filtering
│   ├── dependencies/
│   │   ├── import_dependencies.cmake  # namespace-based subdirectory import
│   │   └── find_targets.cmake         # recursive target discovery
│   ├── codegen/
│   │   └── flatbuffer_cpp_library.cmake
│   └── utils/
│       ├── set_folder_for_targets.cmake
│       └── embed_binary.cmake
├── examples/                      # buildable usage examples
├── tests/                         # CTest suite (script-mode unit tests)
├── ports/targets/                 # vcpkg port
├── docs/                          # API reference & migration guide
└── CMakeLists.txt                 # builds examples + tests, install rules
```

## Building & testing this repository

```bash
cmake -B build -S . -DTARGETS_BUILD_EXAMPLES=ON -DTARGETS_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

Options: `TARGETS_BUILD_EXAMPLES` (default ON), `TARGETS_BUILD_TESTS` (default ON).

The test suite currently includes script-mode unit tests for the platform parser
(`tests/unit/`). Broader integration coverage is planned
([#24](https://github.com/alexames/targets/issues/24)).

## Roadmap & known issues

Development is tracked in the
[issue tracker](https://github.com/alexames/targets/issues). Highlights on the roadmap:

- Installable/exportable libraries so Targets-built libraries are `find_package`-able
  downstream ([#20](https://github.com/alexames/targets/issues/20)).
- SHARED-library ergonomics on Windows (export headers, DLL staging)
  ([#21](https://github.com/alexames/targets/issues/21)).
- Pluggable test frameworks and lazy GTest acquisition
  ([#22](https://github.com/alexames/targets/issues/22),
  [#3](https://github.com/alexames/targets/issues/3)).
- Additional code generators (Protobuf, gRPC)
  ([#26](https://github.com/alexames/targets/issues/26)).

## Contributing

Issues and pull requests are welcome. Please open an issue to discuss substantial
changes first, and include a test (a configure-mode CMake test or an example) with
behavioral changes.

## License

MIT — see [LICENSE](LICENSE).
