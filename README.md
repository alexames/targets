# Targets

**Modern CMake build abstraction library with Bazel-like ergonomics**

Targets provides a clean, declarative API for defining C++ build targets in CMake, inspired by Bazel's build rules but designed to work seamlessly with CMake's ecosystem.

## Features

- **Bazel-like API**: Simple, declarative build rules (`cpp_library`, `cpp_binary`, `cpp_test`)
- **Smart Dependency Management**: Automatic namespace-based target resolution
- **Code Generation**: First-class support for FlatBuffers (with more generators coming)
- **IDE Integration**: Automatic folder organization for Visual Studio and other IDEs
- **Modern CMake**: Built on CMake 3.20+ best practices
- **vcpkg Ready**: Distributed as a vcpkg package for easy integration

## Quick Start

### Installation via vcpkg

```bash
vcpkg install targets
```

### Usage in CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyProject)

find_package(Targets CONFIG REQUIRED)
include(Targets)

# Define a library
cpp_library(
    TARGET MyLib
    SOURCES
        src/mylib.cpp
    HEADERS
        include/mylib.h
    INCLUDES
        PUBLIC
            include/
    DEPENDENCIES
        PUBLIC
            fmt::fmt
)

# Define an executable
cpp_binary(
    TARGET MyApp
    SOURCES
        src/main.cpp
    DEPENDENCIES
        PRIVATE
            MyLib
)

# Define a test
cpp_test(
    TARGET TestMyLib
    SOURCES
        test/test_mylib.cpp
    DEPENDENCIES
        PRIVATE
            MyLib
            GTest::gtest_main
)
```

## API Reference

### `cpp_library()`

Define a C++ library target.

**Parameters:**
- `TARGET` - Target name (required)
- `SOURCES` - Source files (.cpp, .cc, etc.)
- `HEADERS` - Header files (.h, .hpp, etc.)
- `INCLUDES` - Include directories (use `PUBLIC`/`PRIVATE` prefixes)
- `DEFINITIONS` - Preprocessor definitions (use `PUBLIC`/`PRIVATE` prefixes)
- `DEPENDENCIES` - Link libraries (use `PUBLIC`/`PRIVATE` prefixes)
- `CXX_STANDARD` - C++ standard version (default: 23)
- `FOLDER` - IDE folder path
- `PROPERTIES` - Additional CMake target properties

### `cpp_binary()`

Define a C++ executable target.

Same parameters as `cpp_library()`, plus:
- `WORKING_DIRECTORY` - Debugger working directory

### `cpp_test()`

Define a C++ test executable (requires Google Test).

Same parameters as `cpp_binary()`.

### `flatbuffer_cpp_library()`

Generate C++ headers from FlatBuffers schemas.

**Parameters:**
- `TARGET` - Target name (required)
- `SCHEMAS` - List of .fbs schema files (required)
- `SCHEMA_ROOT_DIR` - Base directory for schema includes
- `INCLUDE_PREFIX` - Prefix for generated headers
- `BINARY_SCHEMAS_DIR` - Output directory for .bfbs files
- `DEPENDENCIES` - Dependencies on other schema targets
- `FLAGS` - Additional flatc compiler flags

## Advanced Features

### Automatic Namespace Aliasing

Targets automatically creates namespace aliases based on directory structure:

```
MyProject/
├── Source/
│   └── Core/
│       └── CMakeLists.txt  # Defines target "Engine"
```

Creates alias: `MyProject::Core::Engine`

### Smart Dependency Imports

Use `import_dependencies()` to automatically include subdirectories based on target references:

```cmake
cpp_library(
    TARGET MyLib
    DEPENDENCIES
        PUBLIC
            MyProject::Core::Engine  # Automatically imports Core/CMakeLists.txt
)
```

## Documentation

- [API Reference](docs/API.md)
- [Migration Guide](docs/MIGRATION.md)
- [Examples](examples/)

## Requirements

- CMake 3.20 or later
- C++17 or later (for building projects using Targets)

## License

MIT License - See [LICENSE](LICENSE) for details

## Contributing

Contributions welcome! Please open an issue or pull request.
