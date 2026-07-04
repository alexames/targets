# Targets

**Modern CMake build abstraction with Bazel-like ergonomics.**

[![CI](https://github.com/alexames/targets/actions/workflows/ci.yml/badge.svg)](https://github.com/alexames/targets/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/alexames/targets?label=release&sort=semver)](https://github.com/alexames/targets/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Targets is a small, dependency-free set of CMake modules that give you declarative,
readable build rules — `cpp_library`, `cpp_binary`, `cpp_test`, and code-generation
helpers — layered on top of idiomatic modern CMake. You get the ergonomics of a rule
system like Bazel while staying fully inside the CMake ecosystem (vcpkg, `find_package`,
IDE integration, generator expressions, everything). Rules expand to ordinary CMake
targets, so any `target_*` command still works afterward, and source groups / IDE
folders are organized automatically.

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

> **Project status:** pre-1.0 and under active development. The API is covered by
> examples and a CTest suite, and CI builds and consumes the library end-to-end — the
> vcpkg port, `cmake --install`, and a downstream `find_package` consumer — on Linux,
> macOS, and Windows. Roadmap and known gaps live in the
> [issue tracker](https://github.com/alexames/targets/issues).

## Install

### Via vcpkg (recommended)

Targets is published to the [alexames/vcpkg-registry](https://github.com/alexames/vcpkg-registry)
vcpkg registry. Add the registry to your `vcpkg-configuration.json`:

```json
{
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/alexames/vcpkg-registry",
      "baseline": "c357c77a9384591907fd411c4ed5d7df32017943",
      "packages": ["targets"]
    }
  ]
}
```

The `baseline` pins the registry commit your build resolves against; update it to the
registry's latest commit (`git ls-remote https://github.com/alexames/vcpkg-registry HEAD`)
to pick up new releases. Then depend on the package in `vcpkg.json`:

```json
{
  "dependencies": ["targets"]
}
```

and load the rules in your top-level `CMakeLists.txt`:

```cmake
find_package(Targets CONFIG REQUIRED)
include(Targets)
```

The in-repo [overlay port](ports/targets/) installs the same layout by driving this
project's own install rules, so it can be used with vcpkg `overlay-ports` for local
development (see [docs/MIGRATION.md](docs/MIGRATION.md)).

### Vendored (no infrastructure)

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

## What's in the box

Every rule and argument is specified in the [API reference](docs/API.md); the highlights:

- **Core rules** — [`cpp_library`](docs/API.md#cpp_library) (STATIC/SHARED, header-only
  [INTERFACE detection](docs/API.md#header-only-interface-libraries)),
  [`cpp_binary`](docs/API.md#cpp_binary) (debugger conveniences), and
  [`cpp_test`](docs/API.md#cpp_test) (Google Test acquired lazily, Bazel-style
  `SIZE`/`LABELS`/`ARGS`, an empty-suite guard).
- **One visibility grammar** — `INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`, `COPTS`, and
  `LINKOPTS` all take the required
  [`PUBLIC` / `PRIVATE` keywords](docs/API.md#access-specifiers) you know from
  `target_link_libraries`; entries without a keyword are a configure-time error, never
  silently dropped.
- **Platform-conditional entries** — inline
  [`WINDOWS` / `LINUX` / `MACOS` / `ANDROID` / `EMSCRIPTEN` / `DEFAULT` buckets](docs/API.md#platform-conditional-entries)
  in any list argument, with a `LITERAL` escape for values that collide with the
  sentinels.
- **Namespaces & auto-import** — every target gets a
  [`MyProject::Core::Engine`-style alias](docs/API.md#automatic-namespace-aliasing)
  derived from your directory layout, and
  [`import_dependencies`](docs/API.md#import_dependencies) /
  [`import_subdirectory`](docs/API.md#import_subdirectory) /
  [`import_all`](docs/API.md#import_all) /
  [`find_targets`](docs/API.md#find_targets) wire up subdirectories (with
  circular-import detection).
- **Packaging** — [`INSTALL` / `EXPORT` flags](docs/API.md#installing--exporting-libraries)
  generate relocatable install + export rules, so downstream projects consume your
  library with a plain `find_package` and no knowledge of Targets.
- **SHARED libraries on Windows** —
  [`EXPORT_HEADER` / `WINDOWS_EXPORT_ALL_SYMBOLS`](docs/API.md#shared-libraries-on-windows)
  handle symbol export portably, and dependency DLLs are staged next to each executable
  automatically after every build.
- **Toolchain hygiene (opt-in)** —
  [`WARNINGS` / `WERROR` / `SANITIZERS` / `LTO`](docs/API.md#toolchain-hygiene-opt-in)
  translate to the right flags per compiler; all off by default.
- **Runtime data** — a Bazel-style [`DATA` attribute](docs/API.md#cpp_library) stages the
  files a program or test reads at run time next to the built artifact.
- **Code generation** —
  [`flatbuffer_cpp_library`](docs/API.md#flatbuffer_cpp_library) and
  [`protobuf_cpp_library` / `grpc_cpp_library`](docs/API.md#protobuf_cpp_library--grpc_cpp_library)
  wrap schema compilers in linkable library targets.
- **Utilities** — [`set_folder_for_targets`](docs/API.md#set_folder_for_targets) for bulk
  IDE-folder assignment and [`embed_binary`](docs/API.md#embed_binary) for embedding
  files as byte arrays.

## Requirements

- **CMake 3.20 or later.** (Windows DLL staging uses `$<TARGET_RUNTIME_DLLS>`, which
  needs CMake ≥ 3.21; on older CMake it is skipped.)
- A C++ compiler. Targets default to **C++23**; pass `CXX_STANDARD <n>` to any rule to
  select another standard per target.
- Optional, per feature: **Google Test** (for `cpp_test`; found or fetched automatically
  on the first call), **FlatBuffers** (for `flatbuffer_cpp_library`),
  **Protocol Buffers** and **gRPC** (for `protobuf_cpp_library` / `grpc_cpp_library`).

## Documentation

- [**API reference**](docs/API.md) — every rule, argument, and behavior in full detail.
- [**Migration guide**](docs/MIGRATION.md) — translating raw `add_library` /
  `target_*` CMake into Targets rules.
- [**Examples**](examples/) — small runnable projects for each feature, built (and run)
  by CI on Linux, macOS, and Windows.

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for build
and test commands, branch naming, and coding conventions, and
[CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT — see [LICENSE](LICENSE).
