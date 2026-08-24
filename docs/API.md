# Targets API Reference

## Core Functions

### `cpp_library()`

Define a C++ library target.

```cmake
cpp_library(
    TARGET <name>
    [STATIC | SHARED]
    [EXPORT_HEADER]
    [WINDOWS_EXPORT_ALL_SYMBOLS]
    [SOURCES <PUBLIC|PRIVATE> <file>...]
    [SOURCE_DIR <dir>]
    [HEADER_DIR <dir>]
    [NAMESPACE_ROOT <dir>]
    [INCLUDES <PUBLIC|PRIVATE> <dir>...]
    [DEFINITIONS <PUBLIC|PRIVATE> <def>...]
    [DEPENDENCIES <PUBLIC|PRIVATE> <target>...]
    [COPTS <PUBLIC|PRIVATE> <option>...]
    [LINKOPTS <PUBLIC|PRIVATE> <option>...]
    [DATA <file-or-dir>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [VERSION <version>]
    [SOVERSION <soversion>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD]
    [UNITY_BUILD_BATCH_SIZE <number>]
    [WARNINGS <off|default|strict>]
    [WERROR]
    [SANITIZERS <name>...]
    [LTO]
    [INSTALL]
    [EXPORT <export-set>]
)
```

**Parameters:**

- **TARGET** (required): The name of the library target
- **STATIC** / **SHARED**: Flags selecting the library's linkage. A library is STATIC by
  default (or with an explicit `STATIC`) and SHARED with `SHARED`. The two are mutually
  exclusive — passing both is a configure-time error.
- **EXPORT_HEADER**: Flag — run CMake's `GenerateExportHeader` for this target, producing a
  `<target>_export.h` (defining the `<TARGET>_EXPORT` macro) on the target's PUBLIC include
  path, and set `CXX_VISIBILITY_PRESET hidden` / `VISIBILITY_INLINES_HIDDEN`. This is how a
  SHARED library exports symbols portably (on MSVC it populates the import library so
  consumers can link). See [SHARED libraries on Windows](#shared-libraries-on-windows). Mutually
  exclusive with `WINDOWS_EXPORT_ALL_SYMBOLS`; rejected on executables.
- **WINDOWS_EXPORT_ALL_SYMBOLS**: Flag — set the `WINDOWS_EXPORT_ALL_SYMBOLS` target property
  so a SHARED library auto-exports every symbol on Windows, as an alternative to annotating
  the API with `EXPORT_HEADER`'s macro. Mutually exclusive with `EXPORT_HEADER`.
- **SOURCES**: The target's files, grouped under PUBLIC and PRIVATE. PUBLIC entries are its
  interface — the files consumers include — and resolve relative to `HEADER_DIR`; PRIVATE
  entries are its implementation and resolve relative to `SOURCE_DIR`. A private header
  belongs under PRIVATE, beside the `.cpp` it serves. Targets does not glob — files are
  always listed explicitly. See
  [Source visibility (SOURCES)](#source-visibility-sources).
- **SOURCE_DIR**: Base directory for resolving relative PRIVATE entries (default: the
  calling `CMakeLists.txt` directory). Absolute paths are used as-is.
- **HEADER_DIR**: Base directory for resolving relative PUBLIC entries (default:
  `${CMAKE_CURRENT_LIST_DIR}/Include`, capital "I"). Absolute paths are used as-is.
- **NAMESPACE_ROOT**: Root directory for deriving the namespace alias and IDE folder
  (default: `${PROJECT_SOURCE_DIR}/Source`). See
  [Automatic Namespace Aliasing](#automatic-namespace-aliasing).
- **INCLUDES**: Include directories. Every value must be prefixed with PUBLIC or
  PRIVATE; entries before the first keyword are rejected with a configure-time error
  - PUBLIC: Directories exported to consumers
  - PRIVATE: Directories only for building this target
- **DEFINITIONS**: Preprocessor definitions. Every value must be prefixed with PUBLIC
  or PRIVATE
- **DEPENDENCIES**: Link dependencies. Every value must be prefixed with PUBLIC or
  PRIVATE
  - PUBLIC: Dependencies exported to consumers
  - PRIVATE: Dependencies only for building this target
- `SOURCES`, `INCLUDES`, `DEFINITIONS`, and `DEPENDENCIES` (like `COPTS`,
  `LINKOPTS`, and `DATA`) accept inline **platform-conditional entries** — `WINDOWS`,
  `LINUX`, `MACOS`, `ANDROID`, `EMSCRIPTEN`, and `DEFAULT` buckets. See
  [Platform-conditional entries](#platform-conditional-entries) under Advanced Features.
- **COPTS**: Raw compile options (translated to `target_compile_options`). Every value must
  be prefixed with PUBLIC or PRIVATE, and the same platform buckets as `DEFINITIONS` apply.
  PUBLIC options propagate to consumers (`INTERFACE_COMPILE_OPTIONS`); PRIVATE options apply
  only to this target's build.
- **LINKOPTS**: Raw link options (translated to `target_link_options`). Same PUBLIC/PRIVATE
  and platform-bucket rules as `COPTS`.
- **DATA**: Runtime data files/directories (Bazel's `data`). After each build they are copied
  next to the built artifact (`$<TARGET_FILE_DIR>`) via a POST_BUILD step, so the program
  finds them by a relative path when launched from the build tree. Honors the same platform
  buckets as the other lists.
- **CXX_STANDARD**: C++ standard version (11, 14, 17, 20, 23, etc.). Default: 23.
  Module scanning is off regardless of the standard - see
  [C++ modules](#c-modules).
- **FOLDER**: IDE folder path for organization (e.g., "MyProject/Core")
- **PROPERTIES**: Additional CMake target properties as key-value pairs
- **VERSION**: Semantic version for the library (e.g., "1.2.3")
- **SOVERSION**: ABI version number
- **PRECOMPILE_HEADERS**: Headers to precompile for faster builds
- **UNITY_BUILD**: Flag — enable unity/jumbo builds. Its presence turns unity builds on;
  it takes **no value** (do not write `UNITY_BUILD ON`).
- **UNITY_BUILD_BATCH_SIZE**: Number of files per unity chunk (default: 16)
- **WARNINGS**: Opt-in warning level — `off` | `default` | `strict`. `strict` maps to `/W4`
  (MSVC) or `-Wall -Wextra -Wpedantic` (GCC/Clang); `off` maps to `/W0` or `-w`; `default`
  (and omitting the keyword) injects nothing. An invalid level is a configure-time error.
  See [Toolchain hygiene (opt-in)](#toolchain-hygiene-opt-in).
- **WERROR**: Flag — treat warnings as errors (`/WX` on MSVC, `-Werror` on GCC/Clang).
- **SANITIZERS**: Opt-in sanitizer list (e.g. `address undefined`). On GCC/Clang the
  `-fsanitize=<list>` flag is added to **both** compile and link; MSVC honors only
  `address` (as `/fsanitize=address`, non-Debug configurations only — Debug's `/RTC1` is
  incompatible) and skips other sanitizers with a warning.
- **LTO**: Flag — enable link-time (interprocedural) optimization by setting
  `INTERPROCEDURAL_OPTIMIZATION`, gated on `check_ipo_supported()` so it no-ops with a
  warning where unsupported.
- **INSTALL**: Flag — opt the target into install/export rules so it is
  `find_package`-able downstream. See
  [Installing & exporting libraries](#installing--exporting-libraries).
- **EXPORT**: Name of the export set to add the target to (implies `INSTALL`). Defaults to
  `<Project>Targets` when `INSTALL` is given without `EXPORT`.

**Example:**

```cmake
cpp_library(
    TARGET MyMathLib
    SOURCES
        PUBLIC
            mymath/calculator.h
            mymath/geometry.h
        PRIVATE
            src/calculator.cpp
            src/geometry.cpp
            src/detail/lookup_tables.h
    INCLUDES
        PUBLIC
            include/
    DEFINITIONS
        PUBLIC
            MYMATH_VERSION=1
        PRIVATE
            MYMATH_DEBUG_MODE
    DEPENDENCIES
        PUBLIC
            fmt::fmt
        PRIVATE
            spdlog::spdlog
    CXX_STANDARD 20
    FOLDER "MyProject/Math"
    VERSION "1.0.0"
    SOVERSION 1
    PRECOMPILE_HEADERS
        include/mymath/common.h
    UNITY_BUILD
)
```

#### Header-only libraries

A library that exposes PUBLIC files and has no PRIVATE **translation unit** to compile is
**header-only**. Listing a private header does not make it compiled — there is nothing to
compile — so a header-only library keeps its detail headers under PRIVATE.

Targets never creates an `INTERFACE` library. A header-only library is given a shipped
placeholder translation unit (`dummy.cpp`) and built as STATIC, like the file-less codegen
targets already are. That keeps dependency propagation commutative: a consumer sees the same
usage requirements from a library whatever its file list looks like, instead of the kind of
the target changing what depending on it means.

**Every argument therefore applies**, exactly as it does to a library with sources of its
own: PRIVATE `INCLUDES`/`DEFINITIONS`/`DEPENDENCIES`, `COPTS`, `LINKOPTS`, `DATA`, `VERSION`,
`PRECOMPILE_HEADERS`, `UNITY_BUILD`, and the toolchain-hygiene knobs all reach the compile of
the placeholder and the archive it produces.

What a consumer gets changes with it. A header-only library is a real archive on the link
line, which affects link order, `--as-needed` behavior, and `$<TARGET_FILE:...>`. It also
means `CXX_STANDARD` is a setting on the target rather than a requirement propagated to
consumers: a consumer that needs a particular standard to compile these headers must ask for
it, the same way it must for any other library's headers.

`SHARED` is honored on a header-only library rather than rejected — it builds the placeholder
into a shared library. On Windows a library that exports nothing produces no import library,
so a consumer cannot link it; pass `WINDOWS_EXPORT_ALL_SYMBOLS` (or give the library a real
exported symbol) if you mean to link a header-only SHARED library there.

#### A library must offer consumers something

A library exists to give the targets that link it something: public files, public
dependencies, or public usage requirements applied to whoever depends on it. `cpp_library`
rejects a declaration with none of those and no source file of its own, because such a target
archives only the placeholder translation unit and linking it cannot affect a consumer in any
configuration:

```cmake
# Configure-time error: nothing exposed, nothing to compile.
cpp_library(TARGET Nothing)
```

Any one of these satisfies the rule: a `PUBLIC` entry under `SOURCES`, any `DEPENDENCIES`
entry whatever its visibility, or a `PUBLIC` entry under `INCLUDES`, `DEFINITIONS`, `COPTS`
or `LINKOPTS`. A private dependency counts because a static library's private dependency
still reaches the consumer's link line. A library that only
bundles other libraries, or only pushes a define into whatever links it, is legitimate and
needs no files:

```cmake
cpp_library(
    TARGET TracingEnabled
    DEFINITIONS
        PUBLIC
            APP_TRACING=1
)
```

A library with private translation units and no exposed interface is **not** rejected. Its
object code is a contribution in itself — symbols may be declared by another target's header,
or registered by a static initializer — so having no interface is a legitimate shape.

A `PUBLIC` entry is recognized by the keyword rather than by what survives platform
filtering, so a declaration whose only public entry applies to one platform is accepted
everywhere. An interface exposed only by setting an `INTERFACE_*` property through
`PROPERTIES` is not detected; give such a target a source file.

#### SHARED libraries on Windows

A SHARED library needs its symbols exported and its DLL staged next to any executable that
loads it; Targets handles both.

- **`EXPORT_HEADER`** runs CMake's `GenerateExportHeader` for the target, producing a
  `<target>_export.h` that defines a `<TARGET>_EXPORT` macro (expanding to
  `__declspec(dllexport)` while the library builds, `__declspec(dllimport)` for consumers, and
  default visibility on GCC/Clang). The header's directory is added to the target's **PUBLIC**
  include path, so both the library and its consumers can `#include "<target>_export.h"` and
  annotate the public API. `EXPORT_HEADER` also sets `CXX_VISIBILITY_PRESET hidden` and
  `VISIBILITY_INLINES_HIDDEN` for parity: non-Windows toolchains then hide unannotated symbols
  just as MSVC does. When the library is also installed (`INSTALL`/`EXPORT`), the generated
  header is installed alongside the public headers, so exported SHARED libraries still compile
  downstream.

  ```cmake
  cpp_library(TARGET Greeter SHARED SOURCES src/greeter.cpp INCLUDES PUBLIC include/ EXPORT_HEADER)
  ```
  ```cpp
  #include "greeter_export.h"
  GREETER_EXPORT std::string greeting();   // GREETER_EXPORT == <TARGET>_EXPORT
  ```

- **`WINDOWS_EXPORT_ALL_SYMBOLS`** is the annotation-free alternative: it sets the CMake target
  property of the same name so a SHARED library auto-exports every symbol on Windows. It and
  `EXPORT_HEADER` are mutually exclusive (passing both is a configure-time error).

- **DLL staging** is automatic for every `cpp_binary`: after each build, the runtime DLLs of
  the executable's shared-library dependencies are copied next to it (via
  `$<TARGET_RUNTIME_DLLS>`), so it launches from the build tree without manual copying or
  `PATH` changes. It is a no-op on Linux/macOS (shared objects are found via the build-tree
  RPATH) and for executables with no shared dependencies. `$<TARGET_RUNTIME_DLLS>` requires
  **CMake ≥ 3.21**; on older CMake staging is skipped. Set `-DTARGETS_STAGE_RUNTIME_DLLS=OFF`
  to disable it globally.

#### Installing & exporting libraries

By default a `cpp_library` target is build-tree-only: its public include directories are
plain source paths and no install rules are generated, so a downstream project cannot
consume it via `find_package`. Passing **`INSTALL`** (optionally with **`EXPORT <set>`**)
opts the target into a standard, relocatable install + export:

```cmake
project(MyProject VERSION 1.2.0)

cpp_library(
    TARGET MyLib
    SOURCES
        PUBLIC mylib/mylib.h
        PRIVATE src/mylib.cpp
    HEADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include
    INCLUDES PUBLIC include/
    VERSION ${PROJECT_VERSION}
    INSTALL
    EXPORT MyProjectTargets
)
```

This generates ordinary CMake install/export rules:

- Each **PUBLIC** include directory is wrapped in `$<BUILD_INTERFACE:...>` and given a
  matching `$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>`, so the target is export-safe.
- `install(TARGETS MyLib EXPORT MyProjectTargets ...)` installs the artifact into the
  standard `GNUInstallDirs` locations.
- The public headers (the contents of the PUBLIC include directories and `HEADER_DIR`) are
  installed under `${CMAKE_INSTALL_INCLUDEDIR}`.
- A relocatable `<Project>Config.cmake`, a `<Project>ConfigVersion.cmake` (when the project
  declares a `VERSION`), and the exported targets file are generated **once per export
  set** and installed under `${CMAKE_INSTALL_LIBDIR}/cmake/<Project>`.

Downstream, after `cmake --install`, a consumer needs no knowledge of Targets:

```cmake
find_package(MyProject 1.2.0 CONFIG REQUIRED)
target_link_libraries(app PRIVATE MyProject::MyLib)
```

The exported target name (`MyProject::MyLib`) is the **same** namespaced alias the target
has in the build tree, so references work identically whether the library is vendored or
consumed via `find_package`. Multiple libraries can share one `EXPORT` set; the package
config is generated the first time the set is seen and picks up every member. `cpp_binary`
also accepts `INSTALL` (installing the executable to the runtime dir); pass `EXPORT` to add
it to an export set as well.

---

### `cpp_binary()`

Define a C++ executable target.

```cmake
cpp_binary(
    TARGET <name>
    [SOURCES [PRIVATE] <file>...]
    [INCLUDES [PRIVATE] <dir>...]
    [DEFINITIONS [PRIVATE] <def>...]
    [DEPENDENCIES [PRIVATE] <target>...]
    [COPTS [PRIVATE] <option>...]
    [LINKOPTS [PRIVATE] <option>...]
    [DATA <file-or-dir>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
    [COMMAND_ARGUMENTS <args>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD]
    [UNITY_BUILD_BATCH_SIZE <number>]
    [INSTALL]
    [EXPORT <export-set>]
)
```

**Additional Parameters:**

- **Visibility**: `PRIVATE` is implied and `PUBLIC` is rejected on every list above. Nothing
  links an executable, so it has no consumer for a public entry to reach. Write the list
  bare, or spell `PRIVATE` if you prefer it. Every file resolves against `SOURCE_DIR`;
  `HEADER_DIR` stays on the target's own include path. See
  [Access Specifiers](#access-specifiers).
- **WORKING_DIRECTORY**: Sets the debugger working directory (Visual Studio, etc.)
- **COMMAND_ARGUMENTS**: Sets the Visual Studio debugger's command-line (F5) arguments. This
  affects only the debugger, not `ctest`; for arguments passed to a test at run time use
  `cpp_test`'s `ARGS`.
- **COPTS** / **LINKOPTS** / **DATA**: See `cpp_library()` above — raw compile/link options and
  runtime data files. `DATA` is staged next to the executable after each build.
- **INSTALL** / **EXPORT**: Install (and optionally export) the executable. See
  [Installing & exporting libraries](#installing--exporting-libraries) under
  `cpp_library()`.

**Example:**

```cmake
cpp_binary(
    TARGET MyApp
    SOURCES
        src/main.cpp
        src/app.cpp
    DEPENDENCIES
        MyMathLib
        spdlog::spdlog
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
    CXX_STANDARD 20
)
```

---

### `cpp_test()`

Define a C++ test executable. Google Test is acquired automatically on the first `cpp_test()`
call — located with `find_package(GTest)`, or fetched with `FetchContent` if it isn't
installed — so you do not need to provide it yourself. Acquisition happens once and the
imported targets are promoted to global scope, so `cpp_test()` calls in sibling subdirectories
all link against the same `GTest::gtest_main`.

```cmake
cpp_test(
    TARGET <name>
    [SOURCES [PRIVATE] <file>...]
    [INCLUDES [PRIVATE] <dir>...]
    [DEFINITIONS [PRIVATE] <def>...]
    [DEPENDENCIES [PRIVATE] <target>...]
    [COPTS [PRIVATE] <option>...]
    [LINKOPTS [PRIVATE] <option>...]
    [DATA <file-or-dir>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
    [SIZE <small|medium|large|enormous>]
    [TIMEOUT <seconds>]
    [LABELS <label>...]
    [ARGS <arg>...]
    [ALLOW_NO_TESTS]
)
```

Accepts the full `cpp_binary()` grammar (including `DATA`, `COPTS`, `LINKOPTS`) and its
implied `PRIVATE`, plus the test-specific attributes below. Automatically links Google Test and registers tests with CTest
via `gtest_discover_tests`.

Enable testing at your **top-level** `CMakeLists.txt` with `enable_testing()` or, idiomatically, `include(CTest)`. `cpp_test()` does not call `enable_testing()` itself, because that command is directory-scoped and calling it from within the module (in whatever directory first includes Targets) can silently drop tests from `ctest`. `cpp_test()` honors the standard `BUILD_TESTING` option: when it is `OFF`, `cpp_test()` is a no-op — no target is created and Google Test is not acquired.

**Test attributes** (applied to every discovered test):

- **SIZE**: Bazel-style test size — `small` (60 s), `medium` (300 s), `large` (900 s), or
  `enormous` (3600 s) — mapped to a default CTest `TIMEOUT`. An unknown size is a
  configure-time error.
- **TIMEOUT**: CTest per-test timeout in seconds. Overrides the `SIZE`-derived default. Must be
  a non-negative integer.
- **LABELS**: One or more CTest labels set on every discovered test (run a subset with
  `ctest -L <label>`). All labels are preserved, not just the first.
- **ARGS**: Arguments passed to the test executable when CTest **runs** it (via
  `gtest_discover_tests`' `EXTRA_ARGS`). Distinct from `COMMAND_ARGUMENTS` (the VS debugger's
  F5 arguments), which does not affect `ctest`.
- **DATA**: The files a test opens at run time; staged next to the test binary. Unless
  `WORKING_DIRECTORY` is given explicitly, the discovered tests run from the binary's directory
  so `DATA` is found via a relative path.
- **ALLOW_NO_TESTS**: Opt out of the empty-suite guard. By default, a test binary that registers
  **zero** GoogleTest cases makes `ctest` fail (via an always-failing
  `<target>_no_tests_registered` test) rather than silently passing — this catches sources with
  no `TEST()`/`TEST_F()`, a `--gtest_filter` that matched nothing, or a mislink that dropped the
  test-registration translation unit. Pass `ALLOW_NO_TESTS` for a target that is intentionally
  test-free.

**Example:**

```cmake
cpp_test(
    TARGET TestMyMath
    SOURCES
        test/test_calculator.cpp
        test/test_geometry.cpp
    DEPENDENCIES
        MyMathLib
    DATA test/fixtures/
    SIZE medium
    LABELS unit math
    ARGS --gtest_shuffle
)
```

The GTest entry point (`GTest::gtest_main`) is linked automatically; you do not add it to
`DEPENDENCIES`.

---

### `flatbuffer_cpp_library()`

Generate C++ headers from FlatBuffers schema files.

```cmake
flatbuffer_cpp_library(
    TARGET <name>
    SCHEMAS <schema>...
    [SCHEMA_ROOT_DIR <dir>]
    [INCLUDE_PREFIX <prefix>]
    [BINARY_SCHEMAS_DIR <dir>]
    [DEPENDENCIES <target>...]
    [FLAGS <flag>...]
)
```

**Parameters:**

- **TARGET** (required): Name of the generated library target
- **SCHEMAS** (required): List of .fbs schema files
- **SCHEMA_ROOT_DIR**: Base directory for resolving schema includes (default:
  `${PROJECT_SOURCE_DIR}/Source`)
- **INCLUDE_PREFIX**: Prefix for generated header paths
- **BINARY_SCHEMAS_DIR**: Output directory for binary schema files (.bfbs)
- **DEPENDENCIES**: Dependencies on other FlatBuffer schema targets
- **FLAGS**: Additional flags to pass to flatc compiler

**Default Flags:**
- `--scoped-enums`: Generate C++ enum classes
- `--gen-object-api`: Generate mutable object API
- `--keep-prefix`: Preserve relative directory structure

**Example:**

```cmake
flatbuffer_cpp_library(
    TARGET GameSchemas
    SCHEMAS
        schemas/player.fbs
        schemas/world.fbs
    SCHEMA_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/schemas"
    INCLUDE_PREFIX "game/generated"
    BINARY_SCHEMAS_DIR "${CMAKE_BINARY_DIR}/schemas"
    DEPENDENCIES
        CommonSchemas
    FLAGS
        --gen-mutable
)
```

---

### `protobuf_cpp_library()` / `grpc_cpp_library()`

Generate a C++ library from Protocol Buffers schemas. `protobuf_cpp_library()` runs
`protoc` to produce message sources (`*.pb.cc` / `*.pb.h`) and links the protobuf runtime;
`grpc_cpp_library()` takes the same arguments and additionally runs the gRPC C++ plugin to
produce service stubs (`*.grpc.pb.cc` / `*.grpc.pb.h`) and links `gRPC::grpc++`.

```cmake
protobuf_cpp_library(
    TARGET <name>
    PROTOS <proto>...
    [PROTO_ROOT_DIR <dir>]
    [IMPORT_DIRS <dir>...]
    [NAMESPACE_ROOT <dir>]
    [DEPENDENCIES <target>...]
    [FLAGS <flag>...]
)

grpc_cpp_library(
    TARGET <name>
    PROTOS <proto>...
    # ...same arguments as protobuf_cpp_library...
)
```

**Parameters:**

- **TARGET** (required): Name of the generated library target
- **PROTOS** (required): List of `.proto` files
- **PROTO_ROOT_DIR**: Root for resolving proto imports and the generated output layout;
  protoc's primary `-I`. Default: the calling `CMakeLists.txt` directory. Proto files must
  reside under this directory.
- **IMPORT_DIRS**: Additional directories added to protoc's `-I` search path
- **NAMESPACE_ROOT**: Root for the namespace alias / IDE folder. Default:
  `${PROJECT_SOURCE_DIR}/Source` (matches `cpp_target()`)
- **DEPENDENCIES**: Other proto library targets. They are linked `PUBLIC`, and their proto
  import roots are added to protoc's `-I` path so cross-file `import` statements resolve.
- **FLAGS**: Additional flags passed through to `protoc`

**Requirements:**

- `protoc` from `find_package(Protobuf)` (the `protobuf::protoc` target or the
  `Protobuf_PROTOC_EXECUTABLE` variable). `grpc_cpp_library()` also needs the
  `gRPC::grpc_cpp_plugin` target from `find_package(gRPC)`. Both are resolved at the point of
  use, so `include(Targets)` remains side-effect free when these rules are unused. A missing
  tool raises a clear `FATAL_ERROR`.

**Example:**

```cmake
find_package(Protobuf REQUIRED)

protobuf_cpp_library(
    TARGET AddressBookProtos
    PROTOS proto/addressbook.proto
    PROTO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/proto"
)

find_package(gRPC REQUIRED)

grpc_cpp_library(
    TARGET GreeterServices
    PROTOS proto/greeter.proto
    DEPENDENCIES AddressBookProtos
)
```

---

## Utility Functions

### `import_dependencies()`

Automatically import subdirectories based on target namespace references.

```cmake
import_dependencies(<target> <dependencies>)
```

This is a **positional** command — the target name followed by a (semicolon-separated)
list of namespaced dependency labels, *not* a keyword-style call. It parses labels like
`MyProject::Core::Math` and automatically calls `add_subdirectory()` for the corresponding
paths (with circular-dependency detection). The core rules call it for you; it is also
available directly.

**Example:**

```cmake
import_dependencies(MyApp "MyProject::Core::Engine;MyProject::Rendering::Graphics")
# Automatically imports:
#   - Core/CMakeLists.txt
#   - Rendering/CMakeLists.txt
```

---

### `import_subdirectory()`

Import a single subdirectory.

```cmake
import_subdirectory(<directory>)
```

Wrapper around `add_subdirectory()` with circular dependency detection.

---

### `import_all()`

Recursively import all CMakeLists.txt files in a directory tree.

```cmake
import_all(<directory>)
```

**Example:**

```cmake
# In root CMakeLists.txt
import_all("${CMAKE_CURRENT_SOURCE_DIR}/Source")
```

---

### `find_targets()`

Discover and add every subdirectory in a tree that contains a given file.

```cmake
find_targets(
    [DIRECTORY <dir>]
    [NAME <file>]
)
```

**Parameters:**

- **DIRECTORY**: Root of the tree to search recursively (default: the calling
  `CMakeLists.txt` directory).
- **NAME**: Filename to search for (default: `CMakeLists.txt`).

Each directory **below** `DIRECTORY` containing a file named `NAME` is added with
`add_subdirectory()` (a `STATUS` message logs every directory added). Compared to
[`import_all()`](#import_all), the marker filename is configurable, so a build can key
off a file other than `CMakeLists.txt`.

**Example:**

```cmake
find_targets(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/Source"
    NAME CMakeLists.txt
)
```

---

### `set_folder_for_targets()`

Set IDE folder for a list of targets.

```cmake
set_folder_for_targets(
    FOLDER <path>
    TARGETS <target>...
)
```

**Example:**

```cmake
set_folder_for_targets(
    FOLDER "ThirdParty/Libraries"
    TARGETS fmt spdlog EnTT
)
```

---

### `embed_binary()`

Embed binary files as C++ code.

```cmake
embed_binary(
    TARGET <name>
    FILES <file>...
    [NAMESPACE <namespace>]
    [OUTPUT_DIR <dir>]
)
```

Generates a **STATIC** library that exposes each embedded file as a `<file>_data[]` byte
array and a `<file>_size`. **NAMESPACE** (default `embedded`) wraps the declarations;
**OUTPUT_DIR** overrides where the generated `.h`/`.cpp` are written (default: a per-target
subdirectory of `CMAKE_CURRENT_BINARY_DIR`). This is a deliberately basic implementation —
for heavier production embedding consider
[CMakeRC](https://github.com/vector-of-bool/cmrc).

**Example:**

```cmake
embed_binary(
    TARGET EmbeddedAssets
    FILES
        assets/logo.png
        assets/config.json
    NAMESPACE MyApp::Assets
)
```

---

### `targets_enable_compiler_cache()`

Route C and C++ compiles through a compiler cache.

```cmake
targets_enable_compiler_cache(
    [PROGRAM <name-or-path>]
    [BASE_DIR <dir>]
    [REQUIRED]
)
```

Finds a cache binary and points `CMAKE_C_COMPILER_LAUNCHER` and
`CMAKE_CXX_COMPILER_LAUNCHER` at it. CMake initializes a target's launcher property when the
target is created, so call this **before** the `cpp_library()`/`cpp_binary()`/`cpp_test()`
calls it should apply to -- normally from the top-level `CMakeLists.txt`.

**PROGRAM** (default: `ccache`, then `sccache`) names the binary. **BASE_DIR** (default:
`CMAKE_SOURCE_DIR`) is the directory ccache rewrites absolute paths relative to, and is what
lets two checkouts of the same sources share cache entries. **REQUIRED** turns a missing
binary into a `FATAL_ERROR`; without it a missing binary is a `WARNING` and the build proceeds
uncached.

The launcher is wrapped in `cmake -E env`:

```
cmake -E env CCACHE_BASEDIR=<base-dir> CCACHE_NOHASHDIR=1 <program>
```

Both settings are load-bearing, and putting them in the build rules rather than the
environment is the point: an exported `CCACHE_BASEDIR` is a single global value, so a second
worktree silently inherits the first one's and stops hitting. `CCACHE_NOHASHDIR` keeps the
compilation's working directory out of the hash -- ccache folds it in whenever debug info is
generated, because it is recorded there, and two checkouts never share one. The trade this
makes is ccache's own: a debug build served from the cache can carry the directory of the
compilation that filled it.

On success `TARGETS_COMPILER_CACHE` holds the resolved binary. It is left undefined -- and
the launchers a previous configure of the same build tree may have left behind are cleared --
whenever the rule declines to enable caching, so a consumer can test it to find out whether
caching is really in effect.

Three cases produce a warning rather than silence, because each otherwise looks exactly like a
working cache:

- **No cache binary on `PATH`.** The build proceeds uncached and still reports success, and a
  configure is a one-time act whose result persists for the life of the build tree, so a
  status line scrolling past is not enough. The warning names what was searched for and says
  to install it or put it on `PATH`. Pass `REQUIRED` to make it fatal instead.
- **A generator that ignores compiler launchers.** Only the Makefile generators and Ninja run
  one; Visual Studio and Xcode accept the variable and drop it, finishing the build with
  every cache statistic at zero. The rule names the generator and wires nothing.
- **sccache.** It does not implement `CCACHE_BASEDIR`, so cross-checkout sharing is not
  something this rule can deliver with it. The launcher is still wired.

A `BASE_DIR` the sources do not sit under is warned about too: ccache rewrites nothing in
that case and the cache never hits across checkouts. Letter case matters to ccache's
comparison and does not to Windows, so a `BASE_DIR` given in the wrong case is re-spelled the
way the filesystem holds it before it is used.

**Example:**

```cmake
# Top-level CMakeLists.txt, before any targets are declared.
targets_enable_compiler_cache()
```

---

## Advanced Features

### Automatic Namespace Aliasing

Targets automatically creates namespace aliases based on your directory structure:

```
MyProject/
├── CMakeLists.txt
└── Source/
    └── Core/
        ├── CMakeLists.txt  (defines TARGET Engine)
        └── Math/
            └── CMakeLists.txt  (defines TARGET MathLib)
```

This creates:
- `MyProject::Core::Engine`
- `MyProject::Core::Math::MathLib`

You can reference these targets from anywhere in your project.

The leading namespace is the **enclosing** project name (`PROJECT_NAME`), not the
top-level project. A library therefore keeps the same aliases and IDE folders whether it
is built standalone or embedded in a larger build via `add_subdirectory`/`FetchContent`.

### Access Specifiers

Six list arguments carry a visibility: `SOURCES`, `INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`,
`COPTS`, and `LINKOPTS`.

**PUBLIC**: Transitive - exported to targets that depend on this one
**PRIVATE**: Non-transitive - only used when building this target

**On `cpp_library` the keyword is required.** Every value must appear under a `PUBLIC` or a
`PRIVATE` keyword; a value placed before the first keyword is a configure-time error rather
than a silent drop. `SOURCES` also accepts a deprecated bare list; see
[Source visibility (SOURCES)](#source-visibility-sources).

**On `cpp_binary` and `cpp_test` `PRIVATE` is implied, and `PUBLIC` is a configure-time
error.** Nothing links an executable, so a public entry has no consumer to reach: a public
dependency, definition, include directory, or option would land on an interface nothing
reads, and a public file would resolve against `HEADER_DIR` for no one's benefit. The whole
list is private, so write it bare:

```cmake
cpp_test(
    TARGET WidgetTest
    SOURCES
        WidgetTest.cpp
    DEPENDENCIES
        MyProject::UI::Widgets
)
```

An explicit `PRIVATE` ahead of the whole list stays legal — redundant, but it means one
spelling reads on both rules, so a declaration can move between them unchanged. What is
rejected is a list that opens bare and names `PRIVATE` partway through: the entries ahead of
that keyword have no reading that keeps them.

A leaf target's files all resolve against `SOURCE_DIR`; `HEADER_DIR` is still on its own
include path, so a header under `<dir>/Include` is reachable from its sources either way.
`HEADERS`, the deprecated spelling of `SOURCES PUBLIC`, is accepted on every rule for as long
as it lasts.

### Source visibility (SOURCES)

`SOURCES` lists every file that belongs to a target, grouped by who may include it —
following Bazel's `hdrs` / `srcs` split, and the same `PUBLIC`/`PRIVATE` grammar the other
list arguments use:

```cmake
cpp_library(
    TARGET Widgets
    SOURCES
        PUBLIC
            widgets/Widget.hpp          # resolved against HEADER_DIR
        PRIVATE
            Widget.cpp                  # resolved against SOURCE_DIR
            detail/LayoutCache.hpp      # a private header, beside the .cpp it serves
)
```

- **PUBLIC** entries are the target's interface. They resolve against `HEADER_DIR`
  (default `<dir>/Include`) and appear in the IDE's "Header Files" group.
- **PRIVATE** entries are its implementation. They resolve against `SOURCE_DIR` (default
  the calling `CMakeLists.txt` directory) and appear in "Source Files".
- A `.cpp` under **PUBLIC** is legal, and is how you declare a template implementation or
  `.inl` that consumers include: what PUBLIC means is "resolved against `HEADER_DIR`, part
  of the interface", not "not compiled".
- A library is **header-only** when it has PUBLIC files and no PRIVATE
  translation unit. Private headers do not change that — there is nothing to compile.
- This grouping is the `cpp_library` grammar. On `cpp_binary` and `cpp_test` there is one
  group: `PRIVATE` is implied, `PUBLIC` is rejected, and every file resolves against
  `SOURCE_DIR`. See [Access Specifiers](#access-specifiers).
- Platform sentinels nest *inside* a visibility group, exactly as they do for
  `DEPENDENCIES`. See [Platform-conditional entries](#platform-conditional-entries).

#### Migrating from SOURCES / HEADERS

On a library, the older spelling — a bare `SOURCES` list plus a separate `HEADERS` list —
still works and is deprecated. It was already this same split under different names:
`HEADERS` resolved against `HEADER_DIR` and `SOURCES` against `SOURCE_DIR`. So the migration
is mechanical, and for a project whose libraries all have at least one source file nothing
changes about any target:

```cmake
# Before                             # After
SOURCES                              SOURCES
    Widget.cpp                           PUBLIC
    detail/LayoutCache.hpp                   widgets/Widget.hpp
HEADERS                                  PRIVATE
    widgets/Widget.hpp                       Widget.cpp
                                             detail/LayoutCache.hpp
```

Existing `SOURCES` entries become `PRIVATE`, existing `HEADERS` entries become `PUBLIC`.

Two rules keep a half-finished migration from configuring into something you did not mean:

- **A library's `SOURCES` list is one spelling or the other, decided by its first entry.**
  Opening with `PUBLIC` or `PRIVATE` selects the grouped form; anything else is the bare
  list. Opening bare and naming an access keyword later is a configure-time error, because
  the entries ahead of the keyword have no reading — under the bare one the keyword becomes
  a file name, and under the grouped one they are exactly what the access-specifier check
  rejects.
- **Grouped `SOURCES` and `HEADERS` in one library call is a configure-time error.** They
  are two spellings of the same public file list; move the `HEADERS` entries under
  `SOURCES PUBLIC`. A leaf target's `SOURCES` has no public group, so the two do not
  collide there.

A bare `SOURCES` list on `cpp_binary` or `cpp_test` is not this deprecated spelling: it is
the ordinary one, and reports nothing. Only `HEADERS` is deprecated on a leaf target.

The deprecated spelling reports itself with CMake's own deprecation machinery, so
`-Wno-deprecated` silences it and `-Werror=deprecated` turns it into a configure error. Only
the **first** such call of a configure is reported, because a project with hundreds of
targets would otherwise bury every other message; pass
`-DTARGETS_WARN_ALL_LEGACY_SOURCES=ON` to have every remaining call name its
`CMakeLists.txt` line, which is what you want while doing the migration.

### Platform-conditional entries

The list arguments `SOURCES`, `INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`,
`COPTS`, `LINKOPTS`, and `DATA` support inline platform filtering, so a single call can
describe a target across platforms without a surrounding `if(WIN32)/elseif(UNIX)` block.
The current build platform is auto-detected at configure time and only the matching
entries are kept.

Within any of those lists, entries are grouped by **platform sentinel** tokens:

| Sentinel | Selected when |
|---|---|
| `WINDOWS` | `WIN32` |
| `LINUX` | not Windows/Android/Emscripten/Apple (the default Unix case) |
| `MACOS` | `APPLE` |
| `ANDROID` | `ANDROID` |
| `EMSCRIPTEN` | `EMSCRIPTEN` |
| `DEFAULT` | no sentinel above matches the current platform |

Token rules:

- Entries listed **before any sentinel** are *unconditional* — always kept.
- After a sentinel, entries belong to that platform's bucket until the next sentinel, so
  unconditional entries must come first.
- The output is the unconditional entries plus the current platform's bucket if that
  platform was listed, otherwise the `DEFAULT` bucket if one was given, otherwise nothing
  for that argument.
- A specific platform bucket always wins over `DEFAULT` when both match.

For the visibility-carrying lists (`SOURCES`, `INCLUDES`, `DEFINITIONS`, `DEPENDENCIES`,
`COPTS`, `LINKOPTS`), the `PUBLIC`/`PRIVATE` keyword is parsed first, so the sentinels appear
*inside* a visibility group and only affect that group. `DATA` carries no visibility, so its
sentinels appear at the top level.

```cmake
cpp_library(
    TARGET Platform
    SOURCES
        PRIVATE
            common.cpp          # always compiled
            WINDOWS   win32.cpp
            LINUX     posix.cpp
            MACOS     posix.cpp cocoa.mm
            DEFAULT   stub.cpp  # any platform not listed above
    DEPENDENCIES
        PUBLIC   fmt::fmt        # PUBLIC, every platform
        WINDOWS  ws2_32          # PUBLIC (still inside the PUBLIC group), Windows only
        PRIVATE
            LINUX pthread        # PRIVATE, Linux only
)
```

**Escaping a literal sentinel value.** The sentinel words are reserved, so a value that is
literally equal to one of them (most commonly a preprocessor definition such as `WINDOWS`)
must be preceded by the `LITERAL` escape marker. `LITERAL` is dropped and the entry that
follows it is added to the active bucket as an ordinary value instead of switching
platform sections:

```cmake
cpp_library(
    TARGET X
    DEFINITIONS
        PUBLIC LITERAL WINDOWS      # defines the macro WINDOWS on every platform
        WINDOWS LITERAL LINUX       # defines the macro LINUX only on Windows
)
```

`LITERAL` escapes exactly the one entry that follows it, so a later bare sentinel still
opens a section as usual; it escapes itself too (`LITERAL LITERAL` yields a literal
`LITERAL`); and a trailing `LITERAL` with nothing after it is a configure-time error.

### Source and header base directories

Targets does **not** glob or auto-discover source files — you always list `SOURCES`
explicitly. Relative entries are resolved against a base directory chosen by their
visibility:

- **PRIVATE** entries resolve relative to **`SOURCE_DIR`** (default: the calling
  `CMakeLists.txt` directory, `CMAKE_CURRENT_LIST_DIR`).
- **PUBLIC** entries resolve relative to **`HEADER_DIR`** (default:
  `${CMAKE_CURRENT_LIST_DIR}/Include`, capital "I").

Pass `SOURCE_DIR` / `HEADER_DIR` to change those bases; an absolute path is used as-is.

### IDE Integration

Targets automatically:
- Creates source groups for Visual Studio
- Sets FOLDER properties for Solution Explorer organization
- Configures debugger working directories
- Organizes generated code into separate IDE folders

### MSVC Compiler Flags

On MSVC, every rule that creates a compiled target - `cpp_library`, `cpp_binary`,
`cpp_test`, `flatbuffer_cpp_library`, `protobuf_cpp_library`, `grpc_cpp_library`, and
`embed_binary` - injects a small, scoped set of flags into it:

- **`/utf-8`** — always applied. Treats source and execution character sets as UTF-8.
- **`/ZI`** (edit-and-continue debug info) — applied **only to Debug builds** (via a
  `$<$<CONFIG:Debug>:...>` generator expression), **only on x86/x64**, and **only when no
  compiler launcher is configured** (see below). It is never applied to Release (where it
  de-optimizes the build) and is skipped on ARM/ARM64 (where it is invalid). Set
  `-DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF` to suppress it entirely.
- **`/SAFESEH:NO`** — applied **only to x86 (32-bit) executables and shared libraries**,
  where it has effect. It is a no-op on x64, invalid on ARM64, and ignored on static
  libraries, so it is not injected in those cases.

#### Debug builds under a compiler cache

When `CMAKE_CXX_COMPILER_LAUNCHER` is set — as
[`targets_enable_compiler_cache()`](#targets_enable_compiler_cache) sets it — Debug targets
get **embedded debug info (`/Z7`)** instead of `/ZI`, via the
`MSVC_DEBUG_INFORMATION_FORMAT` target property. `/Zi` and `/ZI` route debug info into a
`.pdb` shared by the whole target, which a cache hit cannot reproduce: ccache answers
`unsupported_compiler_option` and compiles the translation unit uncached, so Debug hits
nothing however the cache is configured. `/Z7` carries the same information in the object
file.

The launcher wins over `TARGETS_MSVC_EDIT_AND_CONTINUE` in both positions: a value you set to
`ON` yourself is indistinguishable from the option's default, and `OFF` only ever meant
"do not inject `/ZI`", not "leave Debug uncacheable". To keep edit-and-continue, configure
without a compiler launcher.

Details worth knowing:

- **Other configurations are untouched.** RelWithDebInfo keeps `/Zi` and therefore keeps
  missing the cache; Release is unaffected. Only Debug changes.
- **Your own choice wins.** A project that sets `CMAKE_MSVC_DEBUG_INFORMATION_FORMAT`, or
  passes `MSVC_DEBUG_INFORMATION_FORMAT` through `PROPERTIES`, keeps that format — on the
  CMake versions and policy setting where that property decides the format at all (see the
  next point).
- **On CMake older than 3.25, or under `CMP0141 OLD`,** the debug format comes from
  `CMAKE_CXX_FLAGS_DEBUG` rather than the property, which CMake then ignores. `/Z7` is
  appended to the target instead: it overrides the `/Zi` in those flags for both the compiler
  and the cache, and `cl.exe` reports `D9025` once per translation unit. Requiring CMake 3.25
  or newer (or setting `CMP0141` to `NEW`) keeps the format out of the flags and silences
  that.
- **Any launcher counts**, including one CMake picked up from the
  `CMAKE_CXX_COMPILER_LAUNCHER` *environment* variable, and including generators that ignore
  compiler launchers altogether (Visual Studio, Xcode). Under those generators no cache runs,
  so the swap costs edit-and-continue and buys nothing; unset the launcher for those build
  trees.

Non-MSVC toolchains (GCC, Clang, clang-cl) receive none of these flags. You can add or
override any flag afterward with the standard `target_compile_options()` /
`target_link_options()` commands.

### Toolchain hygiene (opt-in)

`cpp_library`, `cpp_binary`, and `cpp_test` accept four **opt-in** knobs for warnings and
instrumentation. All are **off by default** (no target changes behavior unless it opts in)
and each is translated to the compiler-appropriate flag via `CXX_COMPILER_ID` generator
expressions, so MSVC-only and GCC/Clang-only forms never reach the wrong toolchain.

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
| `SANITIZERS <list>` | `/fsanitize=address` (address only, non-Debug configs) | `-fsanitize=<list>` on compile **and** link |
| `LTO` | `INTERPROCEDURAL_OPTIMIZATION` (`/GL` + `/LTCG`) | `INTERPROCEDURAL_OPTIMIZATION` (`-flto`) |

- **`WARNINGS`** accepts exactly one level; an unrecognized value is a configure-time error.
  `default` and an omitted keyword inject nothing.
- **`SANITIZERS`** takes a list. On GCC/Clang the same `-fsanitize=` flag is applied to both
  the compile and the link step (a sanitizer both instruments code and links a runtime).
  MSVC provides only AddressSanitizer, so only `address` is honored there (as a compile
  option — the linker links the runtime automatically); other requested sanitizers are
  skipped with a warning. On MSVC, AddressSanitizer is applied to **non-Debug**
  configurations only: Debug's runtime checks (`/RTC1`) are incompatible with
  `/fsanitize=address`, so Debug is a no-op instead of a hard error.
- **`LTO`** sets the `INTERPROCEDURAL_OPTIMIZATION` target property, gated on
  `check_ipo_supported()`, so it degrades to a warning instead of a hard error where the
  toolchain cannot do it.
- These are compile/link settings. A header-only library compiles the placeholder
  translation unit, so they reach it like they reach any other library.

### C++ modules

Every rule that creates a compiled target - `cpp_library`, `cpp_binary`, `cpp_test`,
`flatbuffer_cpp_library`, `protobuf_cpp_library`, `grpc_cpp_library`, and `embed_binary` -
sets **`CXX_SCAN_FOR_MODULES OFF`** on it. Under CMP0155 - which is `NEW` for any project
declaring `cmake_minimum_required(VERSION 3.28)` or newer - CMake would otherwise run a
dependency-scanning pass over **every** translation unit of a target compiled as C++20 or
later, to discover `import`/`export module` declarations and order module compilation.
Targets has no section for declaring a module interface unit, so that scan can never find
one: it costs a preprocessing pass per source file, writes an empty modmap next to each
object, and no compile cache can serve it.

`cpp_library`, `cpp_binary`, and `cpp_test` default `CXX_STANDARD` to 23, so their targets are
in scanning range unless the caller asks for an older standard. The code-generation and embed
rules pin or inherit the standard instead, which does not keep them out of it: a project-wide
`CMAKE_CXX_STANDARD` of 20 or later puts them in range, and so does any dependency carrying an
`INTERFACE` compile feature such as `cxx_std_23`. CMake compiles a consumer at the highest
standard any of its compile features requires - above the consumer's own `CXX_STANDARD`, which
keeps reading whatever the rule set.

Three overrides win over the default, in increasing breadth:

```cmake
# One target that genuinely uses modules. Declare the interface units with the standard
# target_sources() file set -- Targets has no keyword for them -- and turn scanning back on.
cpp_library(TARGET Widgets SOURCES "Widgets.cpp")
target_sources(Widgets PUBLIC FILE_SET CXX_MODULES FILES "Widgets.ixx")
set_target_properties(Widgets PROPERTIES CXX_SCAN_FOR_MODULES ON)
```

- **`CMAKE_CXX_SCAN_FOR_MODULES`** - CMake's own variable, which initializes the property on
  every target created after it is set. Targets leaves the property alone when this variable is
  defined, so setting it keeps working as CMake documents it.
- **`-DTARGETS_SCAN_FOR_MODULES=ON`** - the project-wide escape hatch. Targets then leaves the
  property alone on every target it creates, so CMake's own CMP0155-governed default decides
  whether to scan.
