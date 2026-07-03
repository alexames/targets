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
- [Installing & exporting libraries](#installing--exporting-libraries)
- [SHARED libraries on Windows](#shared-libraries-on-windows)
- [Toolchain hygiene](#toolchain-hygiene)
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
  **FlatBuffers** (for `flatbuffer_cpp_library`), **Protocol Buffers** (for
  `protobuf_cpp_library`) and **gRPC** (for `grpc_cpp_library`).

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

Defines a C++ library. Produces a **STATIC** library by default (or if you pass
`STATIC` explicitly), **SHARED** if you pass `SHARED`. `STATIC` and `SHARED` are mutually
exclusive — passing both is a configure-time error. If you provide `HEADERS` but no
`SOURCES`, an **INTERFACE** (header-only) library is created automatically.

A header-only INTERFACE library carries the arguments that make sense for it: the
**PUBLIC** `INCLUDES`/`DEFINITIONS`/`DEPENDENCIES` (applied as interface
usage-requirements), plus `FOLDER` and `PROPERTIES`. Arguments that only apply to a
compiled target — **PRIVATE** `INCLUDES`/`DEFINITIONS`/`DEPENDENCIES`, `VERSION`,
`SOVERSION`, `PRECOMPILE_HEADERS`, `UNITY_BUILD`, and the [toolchain-hygiene](#toolchain-hygiene)
knobs (`WARNINGS`/`WERROR`/`SANITIZERS`/`LTO`) — have no meaning on an INTERFACE library (it
has no private compile step and produces no built artifact). Rather than being dropped
silently, they are ignored with a configure-time **warning** naming exactly which arguments
were skipped.

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

**Enable testing at your top level.** `cpp_test` does not call `enable_testing()` for
you — that command is directory-scoped, so enabling it from inside the module (wherever
Targets first happens to be `include`d) can silently drop tests from `ctest`. Call
`enable_testing()`, or the idiomatic `include(CTest)`, once in your **top-level**
`CMakeLists.txt`. `cpp_test` also honors the standard `BUILD_TESTING` option (defined and
default-on by `include(CTest)`): when `BUILD_TESTING` is `OFF`, `cpp_test()` becomes a
no-op — it creates no target and never acquires Google Test.

`cpp_test` additionally accepts Bazel-style **test attributes** that map to CTest properties
on every discovered test, plus `DATA` (below) for the files a test reads at run time:

```cmake
cpp_test(
    TARGET TestMyLib
    SOURCES test/test_mylib.cpp
    DEPENDENCIES PRIVATE MyLib
    DATA test/fixtures/sample.json   # staged next to the test binary; the test's default
                                     # working dir becomes that directory so it opens it
                                     # via a relative path
    SIZE medium                      # default TIMEOUT from the Bazel size (see table below)
    TIMEOUT 30                        # explicit CTest TIMEOUT in seconds (overrides SIZE)
    LABELS unit fast                  # CTest labels (run a subset with `ctest -L fast`)
    ARGS --gtest_shuffle              # passed to the test executable when CTest runs it
)
```

| `SIZE` | Default `TIMEOUT` |
|---|---|
| `small` | 60 s |
| `medium` | 300 s |
| `large` | 900 s |
| `enormous` | 3600 s |

`ARGS` are the arguments CTest passes to the test **when it runs** (via
`gtest_discover_tests`' `EXTRA_ARGS`). They are distinct from `COMMAND_ARGUMENTS`, which only
sets the Visual Studio debugger's F5 arguments and has no effect on `ctest`.

**Empty-suite guard.** By default, a `cpp_test` target whose binary registers **zero**
GoogleTest cases makes `ctest` **fail** instead of silently passing. Zero cases means the
sources define no `TEST()`/`TEST_F()`, a `--gtest_filter` matched nothing, or a mislink
dropped the test-registration translation unit — situations where CTest would otherwise report
success while testing nothing. `cpp_test` registers a `<target>_no_tests_registered` CTest test
that fails with a clear diagnostic when discovery finds no cases. Pass `ALLOW_NO_TESTS` to opt a
deliberately test-free binary out of the guard.

### Common arguments

| Argument | Rules | Meaning |
|---|---|---|
| `TARGET` | all | Target name (**required**). |
| `SOURCES` | all | Source files, resolved relative to `SOURCE_DIR`. |
| `HEADERS` | all | Header files, resolved relative to `HEADER_DIR`. |
| `INCLUDES` | all | Include dirs, grouped under `PUBLIC` / `PRIVATE`. |
| `DEFINITIONS` | all | Preprocessor definitions, grouped under `PUBLIC` / `PRIVATE`. |
| `DEPENDENCIES` | all | Link libraries, grouped under `PUBLIC` / `PRIVATE`. |
| `COPTS` | all (compiled) | Extra compile options (`target_compile_options`), grouped under `PUBLIC` / `PRIVATE`, platform-filtered. |
| `LINKOPTS` | all (compiled) | Extra link options (`target_link_options`), grouped under `PUBLIC` / `PRIVATE`, platform-filtered. |
| `DATA` | all (compiled) | Runtime data files/directories staged next to the built artifact after each build. |
| `CXX_STANDARD` | all | C++ standard for this target (default **23**). |
| `FOLDER` | all | IDE folder path (defaults derive from the namespace). |
| `PROPERTIES` | all | Extra `set_target_properties` key/value pairs. |
| `PRECOMPILE_HEADERS` | all | Headers to precompile. |
| `UNITY_BUILD` | all | **Flag** — enable unity/jumbo build (presence = on). |
| `UNITY_BUILD_BATCH_SIZE` | all | Files per unity chunk (default 16). |
| `WARNINGS` | all (compiled) | Opt-in warning level: `off` \| `default` \| `strict`. See [Toolchain hygiene](#toolchain-hygiene). |
| `WERROR` | all (compiled) | **Flag** — treat warnings as errors (`/WX` or `-Werror`). |
| `SANITIZERS` | all (compiled) | Opt-in sanitizers, e.g. `address undefined` — instruments compile **and** link. |
| `LTO` | all (compiled) | **Flag** — link-time (interprocedural) optimization when the toolchain supports it. |
| `STATIC` / `SHARED` | `cpp_library` | **Flags** — library linkage (default STATIC); mutually exclusive, passing both errors. |
| `EXPORT_HEADER` | `cpp_library` | **Flag** — generate a `<target>_export.h` (via `GenerateExportHeader`) exposing a `<TARGET>_EXPORT` macro, and set hidden-visibility defaults. See [SHARED libraries on Windows](#shared-libraries-on-windows). |
| `WINDOWS_EXPORT_ALL_SYMBOLS` | `cpp_library` | **Flag** — auto-export every symbol of a SHARED library (alternative to `EXPORT_HEADER`; the two are mutually exclusive). |
| `VERSION` / `SOVERSION` | `cpp_library` | Library version / ABI version. |
| `INSTALL` | `cpp_library`, `cpp_binary` | **Flag** — generate install/export rules (see [Installing & exporting](#installing--exporting-libraries)). |
| `EXPORT` | `cpp_library`, `cpp_binary` | Export-set name for the installed target (implies `INSTALL`; default `<Project>Targets`). |
| `WORKING_DIRECTORY` | `cpp_binary`, `cpp_test` | Debugger / test working directory. |
| `COMMAND_ARGUMENTS` | `cpp_binary` | VS debugger command-line arguments (F5). Not passed by `ctest`; use `cpp_test`'s `ARGS` for that. |
| `SIZE` | `cpp_test` | Bazel test size (`small` \| `medium` \| `large` \| `enormous`) → default CTest `TIMEOUT`. |
| `TIMEOUT` | `cpp_test` | CTest per-test timeout in seconds (overrides the `SIZE` default). |
| `LABELS` | `cpp_test` | CTest labels applied to every discovered test (`ctest -L <label>`). |
| `ARGS` | `cpp_test` | Arguments passed to the test executable when CTest runs it. |
| `ALLOW_NO_TESTS` | `cpp_test` | Opt out of the empty-suite guard for a deliberately test-free binary. |
| `SOURCE_DIR` | all | Base dir for relative sources (default: current list dir). |
| `HEADER_DIR` | all | Base dir for relative headers (default: `<current list dir>/Include`). |
| `NAMESPACE_ROOT` | all | Root for namespace-alias derivation (default: `${PROJECT_SOURCE_DIR}/Source`). |

> **Always prefix `INCLUDES` / `DEFINITIONS` / `DEPENDENCIES` values with `PUBLIC` or
> `PRIVATE`.** The keyword is required: any entry placed before the first visibility
> keyword is rejected with a configure-time error (it was previously dropped silently —
> [#4](https://github.com/alexames/targets/issues/4)). Unknown or misspelled arguments are
> likewise rejected instead of being ignored.

## Installing & exporting libraries

By default a `cpp_library` target lives only in your build tree: its public include
directories are plain source paths and no install rules are emitted, so a downstream
project can't consume it with `find_package`. Add **`INSTALL`** (optionally with
**`EXPORT <set>`**) to opt the target into standard, relocatable install + export rules:

```cmake
project(MyProject VERSION 1.2.0)

cpp_library(
    TARGET MyLib
    SOURCES src/mylib.cpp
    HEADERS mylib/mylib.h
    HEADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES PUBLIC include/
    VERSION ${PROJECT_VERSION}
    INSTALL
    EXPORT MyProjectTargets
)
```

This expands to ordinary CMake: the public includes are wrapped in
`$<BUILD_INTERFACE:...>` / `$<INSTALL_INTERFACE:...>` (making the target export-safe),
`install(TARGETS … EXPORT MyProjectTargets …)` installs the artifact into the standard
`GNUInstallDirs` locations, the public headers are installed under the include dir, and a
relocatable `MyProjectConfig.cmake` + version file + exported targets file are generated
**once per export set** under `lib/cmake/MyProject`. After `cmake --install`, a downstream
consumer needs no knowledge of Targets:

```cmake
find_package(MyProject 1.2.0 CONFIG REQUIRED)
target_link_libraries(app PRIVATE MyProject::MyLib)
```

The exported name `MyProject::MyLib` is the **same** namespaced alias the target has in the
build tree, so code links against it identically whether the library is vendored or
consumed via `find_package`. Several libraries can share one `EXPORT` set. `cpp_binary`
accepts `INSTALL`/`EXPORT` too. A worked end-to-end example lives in
[`examples/install_export`](examples/install_export); a downstream consumer is in
[`tests/consume_install`](tests/consume_install).

## SHARED libraries on Windows

A `SHARED` library needs two things a static one doesn't, and Targets wires both up for you:

**1. Exported symbols.** On Windows/MSVC a symbol is only visible to consumers if it is
marked `__declspec(dllexport)`; without that the import library is empty and downstream code
fails to link. Add **`EXPORT_HEADER`** and Targets runs CMake's
[`GenerateExportHeader`](https://cmake.org/cmake/help/latest/module/GenerateExportHeader.html)
for the target, producing a `<target>_export.h` (in the build tree, on the target's **PUBLIC**
include path) that defines a `<TARGET>_EXPORT` macro. It expands to `dllexport` while the
library builds, `dllimport` when a consumer links it, and default visibility on GCC/Clang —
so annotating your public API works identically everywhere. `EXPORT_HEADER` also sets
`CXX_VISIBILITY_PRESET hidden` / `VISIBILITY_INLINES_HIDDEN` so non-Windows toolchains hide
unannotated symbols too, matching MSVC.

```cmake
cpp_library(TARGET Greeter SHARED SOURCES src/greeter.cpp INCLUDES PUBLIC include/ EXPORT_HEADER)
```

```cpp
// greeter.h
#include "greeter_export.h"          // generated; on the PUBLIC include path
GREETER_EXPORT std::string greeting();   // GREETER_EXPORT = <TARGET>_EXPORT
```

As an alternative, **`WINDOWS_EXPORT_ALL_SYMBOLS`** auto-exports every symbol (setting the
CMake target property of the same name) so no annotations are needed. It and `EXPORT_HEADER`
are mutually exclusive — passing both is a configure-time error. When a SHARED library also
uses `INSTALL`/`EXPORT`, the generated export header is installed alongside the public headers,
so downstream consumers still compile.

**2. DLL staging.** A produced `.dll` must sit next to the executable that loads it (or be on
`PATH`) or the process won't start. Targets copies the runtime DLLs of each `cpp_binary`'s
shared-library dependencies next to the executable after every build (via
`$<TARGET_RUNTIME_DLLS>`), so running or debugging straight from the build tree just works —
no manual copying, no `PATH` juggling. It is a no-op on Linux/macOS (which resolve shared
objects through the build-tree RPATH) and for executables with no shared dependencies. This
uses `$<TARGET_RUNTIME_DLLS>`, which requires **CMake ≥ 3.21**; on older CMake it is skipped.
Disable it globally with `-DTARGETS_STAGE_RUNTIME_DLLS=OFF`.

A worked example (SHARED library + executable that links and runs it) lives in
[`examples/shared_library`](examples/shared_library); CI builds **and runs** it on
windows-latest, proving both the export and the staging.

## Toolchain hygiene

`cpp_library` / `cpp_binary` / `cpp_test` accept four **opt-in**, compiler-aware knobs for
warnings and instrumentation. Every one is **off by default** — a target gets nothing
unless it asks — and each translates to the right flag per compiler via `CXX_COMPILER_ID`
generator expressions, so MSVC-only and GCC/Clang-only forms never leak to the wrong
toolchain.

```cmake
cpp_library(
    TARGET MyLib
    SOURCES src/mylib.cpp
    WARNINGS strict          # off | default | strict
    WERROR                   # warnings as errors
    SANITIZERS address undefined
    LTO                      # link-time / interprocedural optimization
)
```

| Knob | MSVC | GCC / Clang |
|---|---|---|
| `WARNINGS strict` | `/W4` | `-Wall -Wextra -Wpedantic` |
| `WARNINGS off` | `/W0` | `-w` |
| `WARNINGS default` (or omitted) | *nothing* | *nothing* |
| `WERROR` | `/WX` | `-Werror` |
| `SANITIZERS <list>` | `/fsanitize=address` (address only, non-Debug configs) | `-fsanitize=<list>` on **compile and link** |
| `LTO` | `INTERPROCEDURAL_OPTIMIZATION` (`/GL` + `/LTCG`) | `INTERPROCEDURAL_OPTIMIZATION` (`-flto`) |

Notes:

- **`WARNINGS`** takes one level. `strict` raises the warning level; `off` silences
  warnings; `default` (or omitting the keyword) injects nothing. Any other value is a
  configure-time error.
- **`SANITIZERS`** takes a list (`address`, `undefined`, `thread`, `leak`, …). On GCC/Clang
  the `-fsanitize=` flag is applied to **both** compile and link (a sanitizer both
  instruments code and pulls in a runtime). MSVC provides only AddressSanitizer, so only
  `address` is honored there (as a compile option — the linker links the runtime
  automatically); any other requested sanitizer is skipped with a warning. On MSVC,
  AddressSanitizer is applied to **non-Debug configurations only** (Release / RelWithDebInfo):
  the default Debug runtime checks (`/RTC1`) and edit-and-continue (`/ZI`) are incompatible
  with `/fsanitize=address`, so Debug is a no-op rather than a hard compile error.
- **`LTO`** sets the `INTERPROCEDURAL_OPTIMIZATION` target property, gated on
  `check_ipo_supported()`, so it degrades to a warning (rather than a hard error) on a
  toolchain that can't do it.
- These are compile/link settings, so they apply only to compiled targets. On a header-only
  **INTERFACE** library they are reported as ignored, consistent with the other
  compile-only arguments ([#13](https://github.com/alexames/targets/issues/13)).

A worked example (a library and executable built with `WARNINGS strict` and `LTO`) lives in
[`examples/toolchain_hygiene`](examples/toolchain_hygiene); CI builds it on all three OSes.

## Per-target compile & link options

`COPTS` and `LINKOPTS` add raw compile / link options to a target — the escape hatch for a
flag Targets doesn't model natively. They carry `PUBLIC` / `PRIVATE` visibility and the same
platform buckets as `DEFINITIONS` (see [Platform-conditional entries](#platform-conditional-entries)),
and translate to `target_compile_options` / `target_link_options`. `PUBLIC` options propagate
to consumers (as `INTERFACE_COMPILE_OPTIONS` / `INTERFACE_LINK_OPTIONS`); `PRIVATE` options
apply only to this target's own build.

```cmake
cpp_library(
    TARGET MyLib
    SOURCES src/mylib.cpp
    COPTS
        PRIVATE -fno-rtti          # this target only
        WINDOWS /bigobj            # Windows builds only
    LINKOPTS
        PRIVATE -Wl,--as-needed
)
```

Being compile/link settings, they apply only to compiled targets; on a header-only
**INTERFACE** library they are reported as ignored (like the toolchain-hygiene knobs,
[#13](https://github.com/alexames/targets/issues/13)).

## Runtime data files (`DATA`)

`DATA` lists the files (and directories) a target reads at run time — Bazel's `data`
attribute. After each build, Targets copies them next to the built artifact (into
`$<TARGET_FILE_DIR>`, via a `POST_BUILD` step, exactly like the [DLL staging](#shared-libraries-on-windows)
above), so the program finds them by a relative path when launched from the build tree.
`DATA` honors the same [platform buckets](#platform-conditional-entries) as the other lists.

```cmake
cpp_binary(TARGET MyApp SOURCES src/main.cpp DATA assets/config.json assets/shaders/)
```

For a **`cpp_test`**, the staged data is what the test opens at run time, so — unless you set
`WORKING_DIRECTORY` explicitly — the discovered tests' working directory defaults to the test
binary's directory, and a relative `open("fixture.json")` just works. `DATA` is a runtime
concern of a built artifact, so (like `COPTS`/`LINKOPTS`) it is ignored on a header-only
INTERFACE library. A worked example lives in [`examples/data_files`](examples/data_files); CI
builds it and **runs** it on all three OSes, proving the data lands next to the binary.

## Platform-conditional entries

`SOURCES`, `HEADERS`, `INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`, `COPTS`, `LINKOPTS`, and
`DATA` support inline platform filtering. List unconditional entries first, then group platform-specific
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

### Escaping a literal sentinel value

The sentinel words (`WINDOWS`, `LINUX`, `MACOS`, `ANDROID`, `EMSCRIPTEN`, `DEFAULT`) are
reserved. To pass a value that is literally equal to one of them — most commonly a
preprocessor definition such as `WINDOWS` or `LINUX` — precede it with the `LITERAL`
escape marker. The marker is dropped and the next entry is added to the active bucket as
an ordinary value instead of switching platform sections:

```cmake
cpp_library(
    TARGET X
    DEFINITIONS
        PUBLIC LITERAL WINDOWS        # defines the macro WINDOWS on every platform
        WINDOWS LITERAL LINUX         # defines the macro LINUX only on Windows
)
```

`LITERAL` escapes exactly the one entry that follows it, so a later bare sentinel still
opens a section as usual. The marker escapes itself too: `LITERAL LITERAL` emits a literal
`LITERAL`. A trailing `LITERAL` with nothing after it is a hard error.

## Dependency management & namespaces

### Automatic namespace aliases

Every target gets an alias derived from its location under `NAMESPACE_ROOT`
(default `${PROJECT_SOURCE_DIR}/Source`) and the enclosing project name:

```
MyProject/
└── Source/
    └── Core/
        └── CMakeLists.txt   # defines target "Engine"
```

produces the alias **`MyProject::Core::Engine`**, which you can link from anywhere.

The name comes from the *enclosing* `project()` (`PROJECT_NAME`), not the top-level
project, so a library keeps the same aliases and IDE folders whether it is built
standalone or embedded via `add_subdirectory`/`FetchContent`. Auto-import matching and the
source/binary roots are likewise resolved per project rather than frozen to the first one
configured ([#8](https://github.com/alexames/targets/issues/8)).

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

### `protobuf_cpp_library` / `grpc_cpp_library`

Generates C++ from Protocol Buffers schemas and wraps the result in a linkable library.
`protobuf_cpp_library` emits the message sources (`*.pb.cc` / `*.pb.h`) and links
`protobuf::libprotobuf`; `grpc_cpp_library` additionally runs the gRPC C++ plugin to emit
service stubs (`*.grpc.pb.cc` / `*.grpc.pb.h`) and links `gRPC::grpc++`.

```cmake
find_package(Protobuf REQUIRED)

protobuf_cpp_library(
    TARGET AddressBookProtos
    PROTOS proto/addressbook.proto
    PROTO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/proto"  # -I root; output layout base
    IMPORT_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/vendor"    # extra protoc -I dirs
    DEPENDENCIES CommonProtos                           # other proto library targets
    FLAGS --experimental_allow_proto3_optional          # extra protoc flags
)

find_package(gRPC REQUIRED)

grpc_cpp_library(
    TARGET GreeterServices
    PROTOS proto/greeter.proto
    DEPENDENCIES AddressBookProtos
)
```

Requires `protoc` (from vcpkg's `protobuf` or any `find_package(Protobuf)`) and, for
`grpc_cpp_library`, the gRPC C++ plugin (from `find_package(gRPC)`). Both tools are resolved
at the point of use, so `include(Targets)` stays side-effect free for projects that never
call these rules. Proto files must live under `PROTO_ROOT_DIR`; a dependent proto library
picks up its dependencies' proto roots automatically so cross-file `import` statements
resolve.

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
│   │   ├── install_export.cmake    # install/export rules (INSTALL/EXPORT)
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

Consumer-facing options:

- `TARGETS_MSVC_EDIT_AND_CONTINUE` (default ON) controls whether MSVC targets get `/ZI`
  (edit-and-continue debug info) in Debug builds on x86/x64. It is never applied to Release
  or ARM64; set it to `OFF` to suppress `/ZI` entirely.
- `TARGETS_STAGE_RUNTIME_DLLS` (default ON) controls whether each `cpp_binary` copies its
  shared-library dependency DLLs next to the executable after building (Windows). Set it to
  `OFF` to suppress DLL staging. See [SHARED libraries on Windows](#shared-libraries-on-windows).

The test suite has two layers: script-mode unit tests for the platform parser
(`tests/unit/`, run with pure `cmake -P`) and configure-mode integration tests
(`tests/integration/`) that configure small projects and assert target properties or match
expected diagnostics. Run the whole suite with `ctest` as shown above.

CI (`.github/workflows/ci.yml`) runs on ubuntu-latest, windows-latest, and macos-latest:

- **build-examples** — builds every example and runs the executable/shared-library ones.
- **test-suite** — configures with `TARGETS_BUILD_TESTS=ON` and runs the full `ctest` suite.
- **install-export** — installs the `install_export` example and consumes it through
  `find_package(WidgetKit CONFIG REQUIRED)` from a separate project.
- **consume-port** — installs the in-repo vcpkg port and consumes it through
  `find_package(Targets CONFIG REQUIRED)`.

## Roadmap & known issues

Development is tracked in the
[issue tracker](https://github.com/alexames/targets/issues). Highlights on the roadmap:

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
