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
    SOURCES
        PUBLIC  mathlib/calculator.h
        PRIVATE src/calculator.cpp
    HEADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES PUBLIC include/
    DEPENDENCIES PUBLIC fmt::fmt
)

cpp_binary(
    TARGET CalculatorApp
    SOURCES src/main.cpp
    DEPENDENCIES MathLib
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
development.

### Vendored (no infrastructure)

Copy or submodule this repository into your project and put its `cmake/` directory on
the module path:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyProject)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/third_party/targets/cmake")
include(Targets)

cpp_library(TARGET MyLib SOURCES PRIVATE src/mylib.cpp INCLUDES PUBLIC include/)
```

This is exactly how the [`examples/`](examples/) build.

## What it buys you

Four things, each awkward to get right by hand in every `CMakeLists.txt` that needs it. The
[API reference](docs/API.md) specifies every rule and argument; this section is the argument
for reading it.

### A target declared in one place

Sources, headers, dependencies, and usage requirements go in one call, with visibility
spelled rather than inferred from where a file sits or which `target_*` command came next:

```cmake
cpp_library(
    TARGET Widgets
    SOURCES
        PUBLIC
            widgets/Widget.hpp          # the interface, resolved against HEADER_DIR
        PRIVATE
            src/Widget.cpp              # the implementation, resolved against SOURCE_DIR
            src/detail/LayoutCache.hpp  # a private header, beside the .cpp it serves
    HEADER_DIR include
    INCLUDES PUBLIC include/
    DEPENDENCIES
        PUBLIC  fmt::fmt
        PRIVATE spdlog::spdlog
)

cpp_test(
    TARGET WidgetTest
    SOURCES test/WidgetTest.cpp
    DEPENDENCIES Widgets
    SIZE small
    LABELS unit
)
```

That is the whole declaration. `Widgets` also gets the alias `MyProject::Widgets`, an IDE
folder, and source groups; `WidgetTest` is linked against Google Test — acquired on the first
`cpp_test()` call, never at include time — and registered with CTest, with a 60-second
timeout from its size and a `ctest -L unit` label. Registration needs testing enabled at your
top level: `cpp_test()` never calls `enable_testing()` itself, because that command is
directory-scoped and calling it from a module would drop tests declared in sibling scopes.

The grammar is uniform and checked. On a library, every entry of `INCLUDES`, `DEFINITIONS`,
`DEPENDENCIES`, `COPTS`, and `LINKOPTS` must sit under `PUBLIC` or `PRIVATE`; an entry before
the first keyword is a configure error rather than a value silently dropped. `SOURCES` takes
the same groups, and also still accepts a deprecated bare list that is entirely private —
what it will not accept is a list that opens bare and names a keyword partway through, where
the entries ahead of the keyword have no reading that keeps them. On `cpp_binary` and
`cpp_test`, `PRIVATE` is implied and `PUBLIC` is rejected, because nothing links a leaf
target and a public entry there would reach no one. A library that
offers its consumers nothing at all — no public file, no dependency, no public usage
requirement, and nothing of its own to compile — is a configure error too. Header-only
libraries are compiled STATIC targets built from a shipped placeholder translation unit, not
`INTERFACE` ones, so what a consumer inherits does not depend on the kind of target it
happened to reach.

### Compile caching that works across checkouts

```cmake
targets_enable_compiler_cache()   # before the targets it should apply to
```

This finds ccache (or sccache) and wraps it as
`cmake -E env CCACHE_BASEDIR=<source dir> CCACHE_NOHASHDIR=1 ccache`, so the settings that
make a cache entry portable travel in the generated build rules instead of a developer's
exported environment. That is what lets two checkouts of the same sources share objects: an
exported `CCACHE_BASEDIR` is one global value, so a second worktree inherits the first one's
and stops hitting.

On the project these rules were built for, a second checkout of the same sources builds **486
of 486 translation units from cache**, taking a full build from **4m13s to 1m30s**.

It also refuses to pretend. Only the Makefile generators and Ninja run a compiler launcher;
Visual Studio and Xcode accept the variable and drop it, finishing the build with every cache
statistic at zero. Under those generators the rule wires nothing and says so — a cache that
reports success while caching nothing is worse than no cache at all. A cache binary that is
not on `PATH` is reported the same way, and wires nothing either. A `BASE_DIR` the sources do
not sit under is warned about but still wired: caching works, only sharing across checkouts
is lost.

### Code generation as an ordinary target

Schema compilers produce libraries, not build steps to wire up by hand:

```cmake
flatbuffer_cpp_library(
    TARGET GameSchemas
    SCHEMAS schemas/player.fbs schemas/world.fbs
    SCHEMA_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
)

cpp_binary(
    TARGET Game
    SOURCES src/main.cpp
    DEPENDENCIES GameSchemas
)
```

The generated headers land on the include path of whatever links `GameSchemas`, so `Game`
says `DEPENDENCIES` and nothing else — no include directory to add, no custom-command
ordering to get right, and no separate target to remember to build first.
[`protobuf_cpp_library` and
`grpc_cpp_library`](docs/API.md#protobuf_cpp_library--grpc_cpp_library) do the same for
`.proto` files.

### Room to add your own

Those two rules are also the worked examples for wrapping any generator that turns
declarations into sources. A new one has to do three things: produce its outputs with a
custom command that depends on both the tool and the inputs, create a library target from
them, and put the generated directory on that target's `PUBLIC` include path so consumers
inherit it. [`cmake/codegen/`](cmake/codegen/) is two rules doing exactly that, with the
namespace-alias, IDE-folder, and source-group conventions the core rules use.

Today that is copy-the-pattern, not a supported extension point: the scaffolding those rules
lean on is private (`_targets_*`) with no stable contract.
[Issue #38](https://github.com/alexames/targets/issues/38) tracks turning it into one.

---

Everything else — inline
[platform buckets](docs/API.md#platform-conditional-entries) in the file, include,
definition, dependency, option and data lists,
[namespace aliases and subdirectory auto-import](docs/API.md#automatic-namespace-aliasing),
[`INSTALL` / `EXPORT`](docs/API.md#installing--exporting-libraries) for downstream
`find_package`, [symbol export and DLL staging](docs/API.md#shared-libraries-on-windows) for
SHARED libraries on Windows, opt-in
[`WARNINGS` / `WERROR` / `SANITIZERS` / `LTO`](docs/API.md#toolchain-hygiene-opt-in) (on
MSVC, `LTO` costs that target edit-and-continue debug info in Debug, which `/GL` cannot
coexist with), runtime [`DATA`](docs/API.md#cpp_library) staging, and the
[`embed_binary`](docs/API.md#embed_binary) and
[`set_folder_for_targets`](docs/API.md#set_folder_for_targets) utilities — is in the
[API reference](docs/API.md).

C++ modules are the one thing the rules deliberately switch off: every target they create
gets [`CXX_SCAN_FOR_MODULES OFF`](docs/API.md#c-modules), because there is no way to declare
a module interface unit through them, so the per-translation-unit scan CMake would otherwise
run for C++20 and later can never find one. They leave the property alone if you set
`CMAKE_CXX_SCAN_FOR_MODULES` yourself, and `-DTARGETS_SCAN_FOR_MODULES=ON` restores CMake's
default everywhere.

## Requirements

- **CMake 3.20 or later.** A CI job configures and builds the examples at exactly that
  version, so the floor is tested rather than asserted. Every feature the rules use above it
  is version-guarded and degrades:
  `$<TARGET_RUNTIME_DLLS>` DLL staging needs 3.21, the `GLOBAL` promotion of an imported
  Google Test needs 3.24, `MSVC_DEBUG_INFORMATION_FORMAT` under `CMP0141 NEW` needs 3.25
  (below it a `/Z7` is appended to the flags instead), and `EXCLUDE_FROM_ALL` on a fetched
  Google Test needs 3.28.
- **The `Visual Studio 17 2022` generator needs CMake 3.21**, which is CMake's limit rather
  than this project's: 3.20 offers only `Visual Studio 16 2019`. Ninja and the Makefile
  generators drive a VS 2022 toolchain from 3.20 — and are the only generators that run a
  compiler launcher, so they are what a compile cache wants anyway.
- **Linux, macOS, and Windows**, each exercised by CI on every pull request: the examples are
  built and run, the full test suite runs, the library is installed and consumed through
  `find_package`, and the vcpkg port is installed and consumed.
- A C++ compiler. Targets default to **C++23**; pass `CXX_STANDARD <n>` to any rule to
  select another standard per target.
- Optional, per feature: **Google Test** (for `cpp_test`; found or fetched automatically
  on the first call), **FlatBuffers** (for `flatbuffer_cpp_library`),
  **Protocol Buffers** and **gRPC** (for `protobuf_cpp_library` / `grpc_cpp_library`),
  and **ccache** or **sccache** (for `targets_enable_compiler_cache`).

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
