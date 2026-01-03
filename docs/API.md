# Targets API Reference

## Core Functions

### `cpp_library()`

Define a C++ library target.

```cmake
cpp_library(
    TARGET <name>
    [SOURCES <file>...]
    [HEADERS <file>...]
    [INCLUDES [PUBLIC|PRIVATE] <dir>...]
    [DEFINITIONS [PUBLIC|PRIVATE] <def>...]
    [DEPENDENCIES [PUBLIC|PRIVATE] <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [VERSION <version>]
    [SOVERSION <soversion>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD <ON|OFF>]
    [UNITY_BUILD_BATCH_SIZE <number>]
)
```

**Parameters:**

- **TARGET** (required): The name of the library target
- **SOURCES**: List of source files (.cpp, .cc, .cxx, etc.)
- **HEADERS**: List of header files (.h, .hpp, .hxx, etc.)
- **INCLUDES**: Include directories. Prefix with PUBLIC or PRIVATE
  - PUBLIC: Directories exported to consumers
  - PRIVATE: Directories only for building this target
- **DEFINITIONS**: Preprocessor definitions. Prefix with PUBLIC or PRIVATE
- **DEPENDENCIES**: Link dependencies. Prefix with PUBLIC or PRIVATE
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

---

### `cpp_binary()`

Define a C++ executable target.

```cmake
cpp_binary(
    TARGET <name>
    [SOURCES <file>...]
    [HEADERS <file>...]
    [INCLUDES [PUBLIC|PRIVATE] <dir>...]
    [DEFINITIONS [PUBLIC|PRIVATE] <def>...]
    [DEPENDENCIES [PUBLIC|PRIVATE] <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
    [PRECOMPILE_HEADERS <header>...]
    [UNITY_BUILD <ON|OFF>]
    [UNITY_BUILD_BATCH_SIZE <number>]
)
```

**Additional Parameters:**

- **WORKING_DIRECTORY**: Sets the debugger working directory (Visual Studio, etc.)

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
    [INCLUDES [PUBLIC|PRIVATE] <dir>...]
    [DEFINITIONS [PUBLIC|PRIVATE] <def>...]
    [DEPENDENCIES [PUBLIC|PRIVATE] <target>...]
    [CXX_STANDARD <standard>]
    [FOLDER <path>]
    [PROPERTIES <prop> <value>...]
    [WORKING_DIRECTORY <dir>]
)
```

Same parameters as `cpp_binary()`. Automatically links Google Test and registers tests with CTest.

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

### Access Specifiers

All functions support PUBLIC/PRIVATE access specifiers for:
- **INCLUDES**: Include directories
- **DEFINITIONS**: Preprocessor definitions
- **DEPENDENCIES**: Link dependencies

**PUBLIC**: Transitive - exported to targets that depend on this one
**PRIVATE**: Non-transitive - only used when building this target

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
