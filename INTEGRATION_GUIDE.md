# Targets Integration Guide for Composer

This guide explains how the Targets library has been extracted from Composer and how to use it.

## What is Targets?

**Targets** is a modern CMake build abstraction library that provides Bazel-like ergonomics for C++ projects. It was extracted from the Composer project's custom CMake build system.

## Repository Structure

```
targets/
├── cmake/               # CMake modules
│   ├── core/           # cpp_target, cpp_library, cpp_binary, cpp_test
│   ├── dependencies/   # import_dependencies, find_targets  
│   ├── codegen/        # flatbuffer_cpp_library
│   ├── utils/          # set_folder_for_targets, embed_binary
│   └── Targets.cmake   # Main entry point
├── ports/targets/      # vcpkg port configuration
├── examples/           # Usage examples
├── docs/               # Documentation (API.md, MIGRATION.md)
└── README.md          # Project overview
```

## Integration with Composer

Composer now uses Targets via vcpkg overlay ports. Here's what changed:

### 1. vcpkg.json

Added Targets as a dependency and configured overlay ports:

```json
{
  "dependencies": [
    ...
    "targets",
    ...
  ],
  "vcpkg-configuration": {
    "overlay-ports": [
      "../targets/ports"
    ]
  }
}
```

### 2. CMakeLists.txt

Replaced individual module includes with Targets:

**Before:**
```cmake
include(cpp_binary)
include(cpp_library)
include(google_test)
include(flatbuffer_cpp_library)
include(find_targets)
include(import_dependencies)
```

**After:**
```cmake
find_package(Targets CONFIG REQUIRED)
include(Targets)
```

### 3. No changes to target definitions!

All existing `cpp_library()`, `cpp_binary()`, `cpp_test()`, and `flatbuffer_cpp_library()` calls work exactly as before.

## Features Added in Targets

The Targets library includes several enhancements beyond the original Composer CMake modules:

### 1. Precompiled Headers
```cmake
cpp_library(
    TARGET MyLib
    SOURCES src/mylib.cpp
    PRECOMPILE_HEADERS
        include/mylib/common.h
        <vector>
        <string>
)
```

### 2. Unity Builds
```cmake
cpp_library(
    TARGET MyLib
    SOURCES # ... many files ...
    UNITY_BUILD ON
    UNITY_BUILD_BATCH_SIZE 20
)
```

### 3. Library Versioning
```cmake
cpp_library(
    TARGET MyLib
    VERSION "1.2.3"
    SOVERSION 1
)
```

### 4. Improved Error Messages
- Better circular dependency detection
- Clearer error messages for missing targets
- Validation of file paths and arguments

### 5. Header-Only Libraries
```cmake
cpp_library(
    TARGET MyHeaderOnlyLib
    HEADERS
        include/mylib/header.h
    INCLUDES
        PUBLIC include/
)
# Automatically creates an INTERFACE library
```

## Using Targets in Other Projects

### Via vcpkg (recommended for development)

1. Add Targets as an overlay port:
```json
{
  "dependencies": ["targets"],
  "vcpkg-configuration": {
    "overlay-ports": ["path/to/targets/ports"]
  }
}
```

2. In CMakeLists.txt:
```cmake
find_package(Targets CONFIG REQUIRED)
include(Targets)
```

### Via Published vcpkg Port (future)

Once published to the vcpkg registry:
```json
{
  "dependencies": ["targets"]
}
```

## Migration Notes

- **Composer-specific modules**: The `luarocks_target.cmake` module remains in Composer as it's project-specific.
- **Namespace root**: Targets defaults to `${PROJECT_SOURCE_DIR}/Source` for namespace generation. Adjust with `NAMESPACE_ROOT` parameter if needed.
- **CMake version**: Targets requires CMake 3.20+.
- **Compatibility**: All existing Composer target definitions work without modification.

## Documentation

- [API Reference](docs/API.md) - Complete API documentation
- [Migration Guide](docs/MIGRATION.md) - Migrating from raw CMake
- [README](README.md) - Quick start and overview
- [Examples](examples/) - Working examples

## Development

### Repository Layout
- `composer/` - Main Composer project
- `targets/` - Targets library (alongside Composer)

### Making Changes to Targets

1. Edit files in `targets/cmake/`
2. Test changes in `targets/examples/`
3. Commit changes to `targets/` repository
4. Changes automatically available to Composer via overlay port

### Publishing Targets

To publish Targets for wider use:

1. Create a GitHub repository
2. Tag a release (e.g., `v0.1.0`)
3. Submit a pull request to vcpkg registry
4. Update SHA512 in port file

## Benefits of Extraction

1. **Reusability**: Other projects can use the same build abstractions
2. **Maintainability**: Targets has its own test suite and documentation
3. **Versioning**: Can version Targets independently of Composer
4. **Community**: Others can contribute improvements
5. **Modularity**: Clear separation between Composer-specific and generic functionality

## Future Enhancements

Potential features for future versions:

- Protobuf code generation support
- gRPC integration
- Qt MOC/UIC/RCC support  
- Automatic package config generation
- Install rules and export sets
- CMake presets integration
- Cross-compilation helpers

## Support

- Issues: https://github.com/yourusername/targets/issues
- Examples: See `examples/` directory
- Documentation: See `docs/` directory

