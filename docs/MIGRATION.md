# Migration Guide

## Migrating from Raw CMake to Targets

This guide helps you migrate an existing CMake project to use the Targets library.

### Before and After Comparison

#### Before (Raw CMake)

```cmake
# Library
add_library(MyLib
    src/mylib.cpp
    src/utils.cpp
    include/mylib.h
)

target_include_directories(MyLib
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_definitions(MyLib
    PUBLIC
        MYLIB_VERSION=1
    PRIVATE
        MYLIB_INTERNAL
)

target_link_libraries(MyLib
    PUBLIC
        fmt::fmt
    PRIVATE
        spdlog::spdlog
)

target_compile_features(MyLib PUBLIC cxx_std_20)

# Executable
add_executable(MyApp
    src/main.cpp
)

target_link_libraries(MyApp
    PRIVATE
        MyLib
)

set_target_properties(MyApp PROPERTIES
    VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
    FOLDER "MyProject/Apps"
)

# Test
add_executable(TestMyLib
    test/test_mylib.cpp
)

target_link_libraries(TestMyLib
    PRIVATE
        MyLib
        GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(TestMyLib)
```

#### After (Using Targets)

```cmake
cpp_library(
    TARGET MyLib
    SOURCES
        src/mylib.cpp
        src/utils.cpp
    HEADERS
        include/mylib.h
    INCLUDES
        PUBLIC
            include/
    DEFINITIONS
        PUBLIC
            MYLIB_VERSION=1
        PRIVATE
            MYLIB_INTERNAL
    DEPENDENCIES
        PUBLIC
            fmt::fmt
        PRIVATE
            spdlog::spdlog
    CXX_STANDARD 20
)

cpp_binary(
    TARGET MyApp
    SOURCES
        src/main.cpp
    DEPENDENCIES
        PRIVATE
            MyLib
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
    FOLDER "MyProject/Apps"
)

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

### Migration Steps

#### 1. Update Root CMakeLists.txt

Add Targets dependency:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyProject)

# Add Targets
find_package(Targets CONFIG REQUIRED)
include(Targets)

# Rest of your configuration...
```

#### 2. Update vcpkg.json (if using vcpkg)

```json
{
  "dependencies": [
    "targets",
    "fmt",
    "spdlog"
  ],
  "vcpkg-configuration": {
    "overlay-ports": ["../targets/ports"]
  }
}
```

Note: During development, use overlay-ports to reference your local Targets repository.

#### 3. Convert Library Targets

For each `add_library()`:

```cmake
# Before
add_library(MyLib src/a.cpp src/b.cpp)
target_include_directories(MyLib PUBLIC include/)
target_link_libraries(MyLib PUBLIC fmt::fmt)

# After
cpp_library(
    TARGET MyLib
    SOURCES src/a.cpp src/b.cpp
    INCLUDES PUBLIC include/
    DEPENDENCIES PUBLIC fmt::fmt
)
```

#### 4. Convert Executable Targets

For each `add_executable()`:

```cmake
# Before
add_executable(MyApp src/main.cpp)
target_link_libraries(MyApp PRIVATE MyLib)

# After
cpp_binary(
    TARGET MyApp
    SOURCES src/main.cpp
    DEPENDENCIES PRIVATE MyLib
)
```

#### 5. Convert Test Targets

For each test executable:

```cmake
# Before
add_executable(TestMyLib test/test.cpp)
target_link_libraries(TestMyLib PRIVATE MyLib GTest::gtest_main)
gtest_discover_tests(TestMyLib)

# After
cpp_test(
    TARGET TestMyLib
    SOURCES test/test.cpp
    DEPENDENCIES PRIVATE MyLib GTest::gtest_main
)
```

#### 6. Leverage Namespace Aliasing

If your project uses subdirectories:

```cmake
# Before
add_subdirectory(Core)
add_subdirectory(Rendering)

add_executable(MyApp src/main.cpp)
target_link_libraries(MyApp PRIVATE Core Rendering)

# After
import_all("${CMAKE_CURRENT_SOURCE_DIR}/Source")

cpp_binary(
    TARGET MyApp
    SOURCES src/main.cpp
    DEPENDENCIES
        PRIVATE
            MyProject::Core::Engine
            MyProject::Rendering::Graphics
)
```

### Common Patterns

#### Pattern: Header-Only Libraries

```cmake
cpp_library(
    TARGET MyHeaderLib
    HEADERS
        include/myheaderlib.h
    INCLUDES
        PUBLIC
            include/
)
# CMake will automatically create an INTERFACE library
```

#### Pattern: Multiple Source Directories

```cmake
cpp_library(
    TARGET MyLib
    SOURCES
        src/core/a.cpp
        src/core/b.cpp
        src/utils/c.cpp
    HEADERS
        include/mylib/core/a.h
        include/mylib/core/b.h
        include/mylib/utils/c.h
    INCLUDES
        PUBLIC include/
)
```

#### Pattern: Platform-Specific Code

```cmake
set(SOURCES src/common.cpp)

if(WIN32)
    list(APPEND SOURCES src/windows.cpp)
elseif(UNIX)
    list(APPEND SOURCES src/unix.cpp)
endif()

cpp_library(
    TARGET MyLib
    SOURCES ${SOURCES}
)
```

#### Pattern: Conditional Dependencies

```cmake
set(DEPS fmt::fmt)

if(ENABLE_LOGGING)
    list(APPEND DEPS spdlog::spdlog)
endif()

cpp_library(
    TARGET MyLib
    SOURCES src/mylib.cpp
    DEPENDENCIES
        PUBLIC ${DEPS}
)
```

### Migrating Code Generation

#### FlatBuffers

```cmake
# Before
find_package(Flatbuffers REQUIRED)

flatbuffers_generate_headers(
    TARGET MySchemas
    SCHEMAS schemas/data.fbs
)

add_library(MySchemas INTERFACE)
target_include_directories(MySchemas INTERFACE ${CMAKE_CURRENT_BINARY_DIR})
add_dependencies(MySchemas MySchemas_generated)

# After
flatbuffer_cpp_library(
    TARGET MySchemas
    SCHEMAS schemas/data.fbs
    SCHEMA_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/schemas"
)
```

### Best Practices

1. **Use Namespace Aliases**: Structure your project with subdirectories and use `import_all()` to automatically discover targets.

2. **Prefer PUBLIC/PRIVATE**: Always specify PUBLIC or PRIVATE for includes, definitions, and dependencies.

3. **Let Targets Auto-Discover**: Don't manually list every source file if they're in standard locations.

4. **Use FOLDER for Organization**: Set IDE folders to keep Solution Explorer clean.

5. **Leverage Unity Builds**: For large projects, enable unity builds to speed up compilation:
   ```cmake
   cpp_library(
       TARGET MyLargeLib
       SOURCES # ... many files ...
       UNITY_BUILD ON
       UNITY_BUILD_BATCH_SIZE 20
   )
   ```

6. **Precompile Common Headers**: Use PRECOMPILE_HEADERS for frequently included headers:
   ```cmake
   cpp_library(
       TARGET MyLib
       SOURCES # ...
       PRECOMPILE_HEADERS
           include/mylib/common.h
           <vector>
           <string>
   )
   ```

### Troubleshooting

#### Issue: Circular Dependencies

**Error:**
```
CMake Error: Circular dependency detected while importing: MyProject/Core/A
```

**Solution:** Check your dependency graph. Targets automatically detects circular dependencies. Refactor your code to eliminate the cycle or use forward declarations and PRIVATE dependencies.

#### Issue: Target Not Found

**Error:**
```
CMake Error: Target "MyProject::Core::Math" not found
```

**Solution:** Ensure the CMakeLists.txt defining that target is being included. Use `import_dependencies()` or `import_all()` to automatically discover targets.

#### Issue: Namespace Alias Conflicts

**Error:**
```
CMake Error: add_library cannot create target "MyLib" because another target with the same name already exists
```

**Solution:** Targets creates aliases based on directory structure. Ensure target names are unique within each directory level.

### Getting Help

- Check the [API Reference](API.md) for detailed parameter documentation
- See [examples/](../examples/) for complete working examples
- Open an issue on GitHub for bugs or questions
