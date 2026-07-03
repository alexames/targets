# Targets API Reference

## Core Functions

### `cpp_library()`

Define a C++ library target.

```cmake
cpp_library(
    TARGET <name>
    [STATIC | SHARED]
    [SOURCES <file>...]
    [HEADERS <file>...]
    [INCLUDES <PUBLIC|PRIVATE> <dir>...]
    [DEFINITIONS <PUBLIC|PRIVATE> <def>...]
    [DEPENDENCIES <PUBLIC|PRIVATE> <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [VERSION <version>]
    [SOVERSION <soversion>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD <ON|OFF>]
    [UNITY_BUILD_BATCH_SIZE <number>]
    [INSTALL]
    [EXPORT <export-set>]
)
```

**Parameters:**

- **TARGET** (required): The name of the library target
- **STATIC** / **SHARED**: Flags selecting the library's linkage. A library is STATIC by
  default (or with an explicit `STATIC`) and SHARED with `SHARED`. The two are mutually
  exclusive — passing both is a configure-time error. Ignored when the target resolves to
  a header-only INTERFACE library (HEADERS but no SOURCES).
- **SOURCES**: List of source files (.cpp, .cc, .cxx, etc.)
- **HEADERS**: List of header files (.h, .hpp, .hxx, etc.)
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
- **CXX_STANDARD**: C++ standard version (11, 14, 17, 20, 23, etc.). Default: 23
- **FOLDER**: IDE folder path for organization (e.g., "MyProject/Core")
- **PROPERTIES**: Additional CMake target properties as key-value pairs
- **VERSION**: Semantic version for the library (e.g., "1.2.3")
- **SOVERSION**: ABI version number
- **PRECOMPILE_HEADERS**: Headers to precompile for faster builds
- **UNITY_BUILD**: Enable unity/jumbo builds (ON/OFF)
- **UNITY_BUILD_BATCH_SIZE**: Number of files per unity chunk (default: 16)
- **INSTALL**: Flag — opt the target into install/export rules so it is
  `find_package`-able downstream. See the **Installing & exporting libraries** subsection
  below.
- **EXPORT**: Name of the export set to add the target to (implies `INSTALL`). Defaults to
  `<Project>Targets` when `INSTALL` is given without `EXPORT`.

**Example:**

```cmake
cpp_library(
    TARGET MyMathLib
    SOURCES
        src/calculator.cpp
        src/geometry.cpp
    HEADERS
        include/mymath/calculator.h
        include/mymath/geometry.h
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
    UNITY_BUILD ON
)
```

**Header-only (INTERFACE) libraries:**

Passing `HEADERS` but no `SOURCES` produces an **INTERFACE** (header-only) library. Such a
target has no private compile step and produces no built artifact, so only a subset of the
arguments applies:

- **Applied:** the **PUBLIC** `INCLUDES`, `DEFINITIONS`, and `DEPENDENCIES` (as interface
  usage-requirements), `CXX_STANDARD` (as an interface feature requirement), `FOLDER`, and
  `PROPERTIES`.
- **Ignored with a warning:** the **PRIVATE** `INCLUDES`/`DEFINITIONS`/`DEPENDENCIES`,
  `VERSION`, `SOVERSION`, `PRECOMPILE_HEADERS`, and `UNITY_BUILD`. These only apply to a
  compiled target; supplying them emits a configure-time warning naming each ignored
  argument rather than dropping them silently.

**Installing & exporting libraries:**

By default a `cpp_library` target is build-tree-only: its public include directories are
plain source paths and no install rules are generated, so a downstream project cannot
consume it via `find_package`. Passing **`INSTALL`** (optionally with **`EXPORT <set>`**)
opts the target into a standard, relocatable install + export:

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
    [SOURCES <file>...]
    [HEADERS <file>...]
    [INCLUDES <PUBLIC|PRIVATE> <dir>...]
    [DEFINITIONS <PUBLIC|PRIVATE> <def>...]
    [DEPENDENCIES <PUBLIC|PRIVATE> <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD <ON|OFF>]
    [UNITY_BUILD_BATCH_SIZE <number>]
    [INSTALL]
    [EXPORT <export-set>]
)
```

**Additional Parameters:**

- **WORKING_DIRECTORY**: Sets the debugger working directory (Visual Studio, etc.)
- **INSTALL** / **EXPORT**: Install (and optionally export) the executable. See the
  **Installing & exporting libraries** subsection under `cpp_library()`.

**Example:**

```cmake
cpp_binary(
    TARGET MyApp
    SOURCES
        src/main.cpp
        src/app.cpp
    DEPENDENCIES
        PRIVATE
            MyMathLib
            spdlog::spdlog
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
    CXX_STANDARD 20
)
```

---

### `cpp_test()`

Define a C++ test executable (requires Google Test).

```cmake
cpp_test(
    TARGET <name>
    [SOURCES <file>...]
    [HEADERS <file>...]
    [INCLUDES <PUBLIC|PRIVATE> <dir>...]
    [DEFINITIONS <PUBLIC|PRIVATE> <def>...]
    [DEPENDENCIES <PUBLIC|PRIVATE> <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
)
```

Same parameters as `cpp_binary()`. Automatically links Google Test and registers tests with CTest.

Enable testing at your **top-level** `CMakeLists.txt` with `enable_testing()` or, idiomatically, `include(CTest)`. `cpp_test()` does not call `enable_testing()` itself, because that command is directory-scoped and calling it from within the module (in whatever directory first includes Targets) can silently drop tests from `ctest`. `cpp_test()` honors the standard `BUILD_TESTING` option: when it is `OFF`, `cpp_test()` is a no-op — no target is created and Google Test is not acquired.

**Example:**

```cmake
cpp_test(
    TARGET TestMyMath
    SOURCES
        test/test_calculator.cpp
        test/test_geometry.cpp
    DEPENDENCIES
        PRIVATE
            MyMathLib
            GTest::gtest_main
)
```

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
- **SCHEMA_ROOT_DIR**: Base directory for resolving schema includes
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

## Utility Functions

### `import_dependencies()`

Automatically import subdirectories based on target namespace references.

```cmake
import_dependencies(
    TARGET <target>
    DEPENDENCIES <dependency>...
)
```

Parses dependency names like `MyProject::Core::Math` and automatically calls `add_subdirectory()` for the corresponding paths.

**Example:**

```cmake
import_dependencies(
    TARGET MyApp
    DEPENDENCIES
        MyProject::Core::Engine
        MyProject::Rendering::Graphics
)
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
)
```

Generates a static library containing binary data accessible from C++.

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

All functions support PUBLIC/PRIVATE access specifiers for:
- **INCLUDES**: Include directories
- **DEFINITIONS**: Preprocessor definitions
- **DEPENDENCIES**: Link dependencies

**PUBLIC**: Transitive - exported to targets that depend on this one
**PRIVATE**: Non-transitive - only used when building this target

The access keyword is **required**: every value of `INCLUDES`, `DEFINITIONS`, and
`DEPENDENCIES` must appear under a `PUBLIC` or `PRIVATE` keyword. Values placed before
the first keyword are rejected with a configure-time error rather than silently
dropped.

### Source Auto-Discovery

By default, Targets looks for:
- Sources in `CMAKE_CURRENT_LIST_DIR`
- Headers in `CMAKE_CURRENT_LIST_DIR/Include`

You can override with explicit SOURCES and HEADERS lists.

### IDE Integration

Targets automatically:
- Creates source groups for Visual Studio
- Sets FOLDER properties for Solution Explorer organization
- Configures debugger working directories
- Organizes generated code into separate IDE folders

### MSVC Compiler Flags

On MSVC, `cpp_library`/`cpp_binary` inject a small, scoped set of flags into
non-INTERFACE targets:

- **`/utf-8`** — always applied. Treats source and execution character sets as UTF-8.
- **`/ZI`** (edit-and-continue debug info) — applied **only to Debug builds** (via a
  `$<$<CONFIG:Debug>:...>` generator expression) and **only on x86/x64**. It is never
  applied to Release (where it de-optimizes the build) and is skipped on ARM/ARM64
  (where it is invalid). Set `-DTARGETS_MSVC_EDIT_AND_CONTINUE=OFF` to suppress it
  entirely.
- **`/SAFESEH:NO`** — applied **only to x86 (32-bit) executables and shared libraries**,
  where it has effect. It is a no-op on x64, invalid on ARM64, and ignored on static
  libraries, so it is not injected in those cases.

Non-MSVC toolchains (GCC, Clang, clang-cl) receive none of these flags. You can add or
override any flag afterward with the standard `target_compile_options()` /
`target_link_options()` commands.
